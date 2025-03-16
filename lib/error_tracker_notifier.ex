defmodule ErrorTrackerNotifier do
  @moduledoc """
  Attaches to ErrorTracker telemetry events and sends notifications for new errors.

  ## Configuration

  Configure in your config.exs:

  ```elixir
  # For email notifications
  config :my_app, :error_tracker,
    notification_type: :email,
    from_email: "support@example.com",
    to_email: "support@example.com",
    mailer: MyApp.Mailer

  # For Discord webhook notifications
  config :my_app, :error_tracker,
    notification_type: :discord,
    webhook_url: "https://discord.com/api/webhooks/your-webhook-url"

  # For both email and Discord notifications
  config :my_app, :error_tracker,
    notification_type: [:email, :discord],  # Can be a single atom or a list
    from_email: "support@example.com",
    to_email: "support@example.com",
    mailer: MyApp.Mailer,
    webhook_url: "https://discord.com/api/webhooks/your-webhook-url"
  ```

  ## Setup

  Add to your application.ex:

  ```elixir
  def start(_type, _args) do
    children = [
      # ...other children
    ]

    # Start the application supervisor
    result = Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)

    # Set up error notifications after the supervisor starts
    ErrorTrackerNotifier.setup()

    result
  end
  ```
  """

  require Logger

  alias ErrorTrackerNotifier.Email
  alias ErrorTrackerNotifier.Discord

  @doc """
  Attach to ErrorTracker telemetry events.
  Call this after your application starts - typically in your Application.start/2 callback.
  """
  def setup do
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
          &__MODULE__.handle_event/4,
          nil
        )

      notification_types = get_notification_types()
      types_str = notification_types |> Enum.map(&to_string/1) |> Enum.join(" and ")

      Logger.info("ErrorTracker #{types_str} notifications set up for new errors and occurrences")

      :ok
    end
  rescue
    e ->
      Logger.error("Failed to setup ErrorTracker notifications: #{inspect(e)}")
      :error
  end

  @doc """
  Telemetry event handler for ErrorTracker events.
  """
  def handle_event(
        [:error_tracker, :error, :new],
        %{system_time: _system_time},
        %{error: error},
        %{occurrence: occurrence},
        _config
      ) do
    Logger.info("ErrorTracker event: new error #{inspect(error.id)}")
    send_occurrence_notification(occurrence, "New Error!")
  end

  def handle_event(
        [:error_tracker, :occurrence, :new],
        %{system_time: _system_time},
        %{occurrence: occurrence} = _metadata,
        _config
      ) do
    Logger.info(
      "ErrorTracker event: new occurrence #{inspect(occurrence.id)} for error #{inspect(occurrence.error_id)}"
    )

    send_occurrence_notification(occurrence, "New Error Occurrence")
  end

  # Catch-all handler to log unexpected events
  def handle_event(event, measurements, metadata, _config) do
    Logger.info(
      "Unhandled ErrorTracker event: #{inspect(event)}, measurements: #{inspect(measurements)}, metadata: #{inspect(metadata)}"
    )
  end

  @doc """
  Send a notification for a new error occurrence.
  """
  def send_occurrence_notification(occurrence, header_txt) do
    notification_types = get_notification_types()

    Enum.map(notification_types, fn type ->
      case type do
        :email ->
          Email.send_occurrence_notification(occurrence, header_txt, config_app_name())

        :discord ->
          Discord.send_occurrence_notification(occurrence, header_txt, config_app_name())

        _ ->
          Logger.error("Unknown notification type: #{type}")
          {:error, :unknown_notification_type}
      end
    end)
  end

  def get_app_name do
    app_atom = app_atom()
    Application.get_env(app_atom, :app_name, Atom.to_string(app_atom))
  rescue
    _ -> "Application"
  end

  def get_config(key, default) do
    app = config_app_name()
    config = Application.get_env(app, :error_tracker, [])
    Keyword.get(config, key, default)
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
end
