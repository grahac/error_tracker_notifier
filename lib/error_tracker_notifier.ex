defmodule ErrorTrackerNotifier do
  @moduledoc """
  Attaches to ErrorTracker telemetry events and sends notifications for new errors.

  Includes throttling to limit notification frequency for repeated errors.

  ## Configuration

  Configure in your config.exs:

  ```elixir
  # For email notifications
  config :my_app, :error_tracker_notifier,
    notification_type: :email,
    from_email: "support@example.com",
    to_email: "support@example.com",
    mailer: MyApp.Mailer,
    throttle_seconds: 10  # Optional: Throttle time between notifications (default: 10 seconds)

  # For Discord webhook notifications
  config :my_app, :error_tracker_notifier,
    notification_type: :discord,
    webhook_url: "https://discord.com/api/webhooks/your-webhook-url",
    throttle_seconds: 30  # Optional: Throttle time between notifications

  # For both email and Discord notifications
  config :my_app, :error_tracker_notifier,
    notification_type: [:email, :discord],  # Can be a single atom or a list
    from_email: "support@example.com",
    to_email: "support@example.com",
    mailer: MyApp.Mailer,
    webhook_url: "https://discord.com/api/webhooks/your-webhook-url",
    throttle_seconds: 60  # Optional: Throttle time between notifications
  ```

  ## Setup

  Add to your application.ex:

  ```elixir
  def start(_type, _args) do
    children = [
      # ...other children
      {ErrorTrackerNotifier, []}
    ]

    # Start the application supervisor
    Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
  end
  ```
  """

  use GenServer
  require Logger

  alias ErrorTrackerNotifier.Email
  alias ErrorTrackerNotifier.Discord

  # Cleanup old entries every 5 minutes
  @cleanup_interval :timer.minutes(5)

  # Client API

  @doc """
  Starts the ErrorTrackerNotifier process.

  If the process is already started, returns {:error, {:already_started, pid}}.
  This is the expected behavior when started by a supervisor.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Attach to ErrorTracker telemetry events.
  Automatically called when the GenServer starts.

  You can also call this function manually if you need to reattach telemetry events
  or if you're starting the process in a different way.
  """
  def setup do
    case Process.whereis(__MODULE__) do
      nil ->
        Logger.warning("Cannot setup telemetry - ErrorTrackerNotifier process not found")
        {:error, :process_not_found}

      _pid ->
        GenServer.call(__MODULE__, :setup)
    end
  end

  @doc """
  Setup telemetry handlers directly without requiring the GenServer to be running.
  This can be used in applications where you want to handle telemetry events but
  don't want to start the GenServer process.

  Returns :ok on success, or :error on failure.
  """
  def setup_telemetry do
    do_setup()
  end

  @doc """
  Send a notification for a new error occurrence.
  """
  def send_occurrence_notification(occurrence, header_txt) do
    GenServer.call(__MODULE__, {:notify, occurrence, header_txt})
  end

  def get_app_name do
    app_atom = app_atom()
    Application.get_env(app_atom, :app_name, Atom.to_string(app_atom))
  rescue
    _ -> "Application"
  end

  def get_config(key, default) do
    app = config_app_name()
    config = Application.get_env(app, :error_tracker_notifier, [])

    # If config is empty and we're not in the init phase (checking for valid config),
    # log a warning about missing configuration
    if config == [] and runtime_mode() != :test and Process.whereis(__MODULE__) != nil do
      Logger.warning(
        "ErrorTrackerNotifier: No configuration found for #{inspect(app)}:error_tracker_notifier"
      )
    end

    Keyword.get(config, key, default)
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    # Check if we have valid configuration to determine whether to start
    if has_valid_config?() do
      # Initialize state with an empty map for tracking error occurrences
      state = %{
        errors: %{},
        setup_complete: false
      }

      # Schedule periodic cleanup
      schedule_cleanup()

      # Setup telemetry handlers
      {:ok, state, {:continue, :setup}}
    else
      # No valid configuration found, shut down gracefully
      Logger.info("ErrorTrackerNotifier shutting down: No configuration found")
      :ignore
    end
  end

  @impl true
  def handle_continue(:setup, state) do
    case do_setup() do
      :ok -> {:noreply, %{state | setup_complete: true}}
      _ -> {:noreply, state}
    end
  end

  @impl true
  def handle_call(:setup, _from, state) do
    case do_setup() do
      :ok -> {:reply, :ok, %{state | setup_complete: true}}
      error -> {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:notify, occurrence, header_txt}, _from, state) do
    {result, new_state} = handle_notification(occurrence, header_txt, state)
    {:reply, result, new_state}
  end

  # Handle all info messages
  @impl true
  def handle_info(message, state) do
    case message do
      # Handle cleanup timer
      :cleanup ->
        # Schedule next cleanup first to ensure it always runs
        schedule_cleanup()

        # Remove error records older than 1 hour
        cleaned_state = cleanup_old_records(state)

        {:noreply, cleaned_state}

      # Handle telemetry events
      {:telemetry_event, event_name, measurements, metadata, _config} ->
        try do
          process_telemetry_event(event_name, measurements, metadata, state)
        rescue
          error ->
            Logger.error("Error processing telemetry event: #{inspect(error)}")
            {:noreply, state}
        end

      # Handle unexpected messages
      unexpected ->
        Logger.debug("Unexpected message received: #{inspect(unexpected)}")
        {:noreply, state}
    end
  end

  # Public telemetry event handler for Telemetry to call
  @doc false
  def handle_telemetry_event(event_name, measurements, metadata, config) do
    # Forward telemetry events to the GenServer process
    case Process.whereis(__MODULE__) do
      nil ->
        Logger.warning("Cannot forward telemetry event - ErrorTrackerNotifier process not found")

      pid ->
        send(pid, {:telemetry_event, event_name, measurements, metadata, config})
    end
  end

  # Process telemetry events within the GenServer
  defp process_telemetry_event(event_name, measurements, metadata, state) do
    case event_name do
      [:error_tracker, :error, :new] ->
        error_id = metadata.error.id
        reason = truncate_reason(metadata.occurrence.reason)
        Logger.debug("ErrorTrackerNotifier event: new error #{inspect(error_id)}")
        {_, new_state} = handle_notification(metadata.occurrence, "New Error! (#{reason})", state)
        {:noreply, new_state}

      [:error_tracker, :occurrence, :new] ->
        occurrence_id = metadata.occurrence.id
        error_id = metadata.occurrence.error_id
        reason = truncate_reason(metadata.occurrence.reason)

        Logger.debug(
          "ErrorTrackerNotifier event: new occurrence #{inspect(occurrence_id)} " <>
            "for error #{inspect(error_id)}"
        )

        {_, new_state} =
          handle_notification(metadata.occurrence, "Error: #{reason}", state)

        {:noreply, new_state}

      _ ->
        Logger.debug(
          "Unhandled ErrorTracker event: #{inspect(event_name)}, " <>
            "measurements: #{inspect(measurements)}, metadata: #{inspect(metadata)}"
        )

        {:noreply, state}
    end
  end

  # Clean up error records older than 1 hour
  defp cleanup_old_records(state) do
    now = System.system_time(:second)
    one_day_ago = (now - :timer.hours(1)) |> div(1000)

    cleaned_errors =
      Enum.filter(state.errors, fn {_error_id, %{last_time: last_time}} ->
        last_time >= one_day_ago
      end)
      |> Map.new()

    # Return updated state with cleaned errors
    %{state | errors: cleaned_errors}
  end

  # Private implementation

  defp do_setup do
    # Check if ErrorTracker is loaded
    unless Code.ensure_loaded?(ErrorTracker) do
      Logger.warning(
        "ErrorTracker module not found. Make sure error_tracker dependency is installed."
      )

      :error
    else
      # Listen for both new errors and new occurrences
      events = [
        [:error_tracker, :error, :new],
        [:error_tracker, :occurrence, :new]
      ]

      # Detach existing handlers to avoid duplicates on reloads
      :telemetry.detach("error-tracker-notifications")

      # Attach our handler to the events
      :ok =
        :telemetry.attach_many(
          "error-tracker-notifications",
          events,
          &__MODULE__.handle_telemetry_event/4,
          nil
        )

      notification_types = get_notification_types()
      types_str = notification_types |> Enum.map(&to_string/1) |> Enum.join(" and ")

      Logger.debug(
        "ErrorTracker #{types_str} notifications set up for new errors and occurrences"
      )

      :ok
    end
  rescue
    e ->
      Logger.error("Failed to setup ErrorTracker notifications: #{inspect(e)}")
      :error
  end

  defp handle_notification(occurrence, header_txt, state) do
    error_id = occurrence.error_id
    now = System.system_time(:second)
    throttle_seconds = get_config(:throttle_seconds, 10)

    # Check current error state
    error_state = Map.get(state.errors, error_id, %{count: 0, last_time: 0})
    time_since_last = now - error_state.last_time

    cond do
      # First occurrence or outside throttle window
      error_state.last_time == 0 || time_since_last >= throttle_seconds ->
        # Send notification with count from previous batch (if any)
        count_to_report = error_state.count

        # Send the notification
        result = send_notifications(occurrence, header_txt, count_to_report)

        # Reset counter and update timestamp
        updated_errors =
          Map.put(state.errors, error_id, %{
            # Start with 0 for the current occurrence (it's already been reported)
            count: 0,
            last_time: now
          })

        {result, %{state | errors: updated_errors}}

      # Within throttle window
      true ->
        # Increment count but don't send notification
        updated_error = %{
          count: error_state.count + 1,
          last_time: error_state.last_time
        }

        updated_errors = Map.put(state.errors, error_id, updated_error)

        Logger.debug(
          "Throttled notification for error #{error_id}. Count: #{updated_error.count}"
        )

        {[{:throttled, error_id, updated_error.count}], %{state | errors: updated_errors}}
    end
  end

  defp send_notifications(occurrence, header_txt, count) do
    notification_types = get_notification_types()

    # Format the header with count information when applicable
    header_with_count = format_header_with_count(header_txt, count)

    Enum.map(notification_types, fn type ->
      case type do
        :email ->
          Email.send_occurrence_notification(occurrence, header_with_count, config_app_name())

        :discord ->
          Discord.send_occurrence_notification(occurrence, header_with_count, config_app_name())

        :test ->
          # Special case for tests - don't actually send notifications
          Logger.debug("Test notification for error #{occurrence.error_id}")
          {:ok, :test_notification_sent}

        _ ->
          Logger.error("Unknown notification type: #{type}")
          {:error, :unknown_notification_type}
      end
    end)
  end

  # Get notification types from config, supporting both atom and list formats
  defp get_notification_types do
    # Get notification_type from config (can be an atom or a list)
    notification_type = get_config(:notification_type, :email)

    # Ensure we always return a list, even if a single atom was provided
    List.wrap(notification_type) |> Enum.uniq()
  end

  # Determine the application atom to use for config lookup
  defp app_atom do
    # Try to detect the application name dynamically
    case :application.get_application() do
      {:ok, app} ->
        app

      # Fallback to default app name
      _ ->
        :error_tracker_notifier
    end
  end

  # Determine which application to look for in the config
  defp config_app_name do
    # Default application name to look for in config
    config_app = Application.get_env(:error_tracker_notifier, :config_app_name)
    config_app || app_atom()
  end

  # Format header text with count information when applicable
  defp format_header_with_count(header_txt, count) do
    occurrence_text =
      case count do
        0 ->
          ""

        1 ->
          ""

        _ ->
          " (#{count} occurrences)"
      end

    "#{header_txt}#{occurrence_text}"
  end

  # Schedule the next cleanup operation
  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end

  # Truncate reason to max 80 characters
  defp truncate_reason(reason) when is_binary(reason) do
    if String.length(reason) > 80 do
      String.slice(reason, 0, 77) <> "..."
    else
      reason
    end
  end

  defp truncate_reason(reason) do
    # If reason isn't a string, convert it to string
    reason |> inspect() |> truncate_reason()
  end

  # Get app runtime mode - either :normal or :test
  defp runtime_mode do
    # Check application config for runtime mode, defaulting to :normal
    Application.get_env(:error_tracker_notifier, :runtime_mode, :normal)
  end

  # Check if we have valid configuration based on notification types
  defp has_valid_config?() do
    # Check runtime mode - :test mode always starts
    case runtime_mode() do
      :test ->
        true

      :normal ->
        # Normal config validation logic
        app = config_app_name()
        config = Application.get_env(app, :error_tracker_notifier, [])

        # Return false if config is empty
        if config == [] do
          false
        else
          # Get notification types from config
          notification_type = Keyword.get(config, :notification_type, nil)

          # If no notification type is set, return false
          if is_nil(notification_type) do
            false
          else
            # Convert to list if it's a single atom
            notification_types = List.wrap(notification_type)

            # Check each notification type for required config
            Enum.any?(notification_types, fn type ->
              case type do
                :email ->
                  has_email_config?(config)

                :discord ->
                  has_discord_config?(config)

                :test ->
                  # Test type doesn't need additional config
                  true

                _ ->
                  false
              end
            end)
          end
        end
    end
  end

  # Check if we have the minimum required email configuration
  defp has_email_config?(config) do
    from_email = Keyword.get(config, :from_email)
    to_email = Keyword.get(config, :to_email)
    mailer = Keyword.get(config, :mailer)

    # All three are required for email configuration
    not is_nil(from_email) and not is_nil(to_email) and not is_nil(mailer)
  end

  # Check if we have the minimum required Discord configuration
  defp has_discord_config?(config) do
    webhook_url = Keyword.get(config, :webhook_url)

    # Webhook URL is required for Discord configuration
    not is_nil(webhook_url)
  end
end
