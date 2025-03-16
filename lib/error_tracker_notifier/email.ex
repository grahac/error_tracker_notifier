defmodule ErrorTrackerNotifier.Email do
  @moduledoc """
  Handles the generation and sending of error notification emails.
  """

  require Logger
  import Swoosh.Email
  alias ErrorTrackerNotifier.UrlHelper

  @doc """
  Send an email notification for a new error occurrence.
  """
  def send_occurrence_notification(occurrence, header, config_app) do
    from_email = ErrorTrackerNotifier.get_config(:from_email, "support@example.com")
    to_email = ErrorTrackerNotifier.get_config(:to_email, "support@example.com")
    app_name = ErrorTrackerNotifier.get_app_name()

    # Extract file and line information for the subject line
    first_line =
      if occurrence.stacktrace && occurrence.stacktrace.lines &&
           length(occurrence.stacktrace.lines) > 0 do
        List.first(occurrence.stacktrace.lines)
      else
        nil
      end

    file = if first_line, do: first_line.file, else: "unknown_file"
    line = if first_line, do: first_line.line, else: "?"
    error_name = occurrence.reason |> String.slice(0, 80) || "Unknown error"

    subject = "[#{app_name}] Error: #{error_name} - #{file} - #{line}"

    email =
      new()
      |> to(to_email)
      |> from({app_name, from_email})
      |> subject(subject)
      |> html_body(occurrence_email_html(occurrence, header))

    case mailer(config_app).deliver(email) do
      {:ok, _} ->
        Logger.info("Occurrence notification email sent successfully")
        {:ok, "Email sent successfully"}

      {:error, reason} ->
        Logger.error("Failed to send occurrence notification: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp occurrence_email_html(occurrence, header) do
    # Extract the first line from the stacktrace for the error location
    first_line =
      if occurrence.stacktrace && occurrence.stacktrace.lines &&
           length(occurrence.stacktrace.lines) > 0 do
        List.first(occurrence.stacktrace.lines)
      else
        nil
      end

    # Extract useful information from the stacktrace line
    error_location =
      if first_line do
        "#{first_line.module}.#{first_line.function} (#{first_line.file}:#{first_line.line})"
      else
        "Unknown location"
      end

    # Extract useful context information
    view = occurrence.context["live_view.view"] || "Unknown view"
    path = occurrence.context["request.path"] || "Unknown path"

    # Get the error URL
    error_url = UrlHelper.get_error_url(occurrence.error_id)

    """
    <div style="max-width: 600px; margin: 0 auto; padding: 20px; font-family: system-ui, -apple-system, sans-serif;">
      <div style="background-color: white; border-radius: 8px; padding: 24px; box-shadow: 0 1px 3px 0 rgb(0 0 0 / 0.1);">
        <h1 style="color: #dc2626; font-size: 24px; font-weight: bold; margin-bottom: 16px;">
          #{header}
        </h1>
        <p style="color: #374151; font-size: 16px; line-height: 24px; margin-bottom: 24px;">
          ErrorTracker has detected a new error:
        </p>

        <div style="background-color: #f9fafb; border-radius: 6px; padding: 16px; margin-bottom: 24px;">
          <p><strong>Error ID:</strong> #{occurrence.error_id}</p>
          <p><strong>Reason:</strong> #{occurrence.reason |> String.slice(0..199)}</p>
          <p><strong>Location:</strong> #{error_location}</p>
          <p><strong>View:</strong> #{view}</p>
          <p><strong>Request Path:</strong> #{path}</p>
          <p><strong>Time:</strong> #{format_time()}</p>
        </div>

        <p style="margin-bottom: 24px;">
          <a href="#{error_url}"
             style="display: inline-block; background-color: #dc2626; color: white; font-weight: 500;
                    padding: 8px 16px; border-radius: 4px; text-decoration: none;">
            View Error Details
          </a>
        </p>
      </div>
    </div>
    """
  end

  defp format_time do
    DateTime.utc_now() |> DateTime.to_string()
  end

  defp mailer(_config_app) do
    # Use the mailer specified in the configuration, or fall back to a default
    ErrorTrackerNotifier.get_config(:mailer, nil) ||
      raise "No mailer module specified in error_tracker config"
  end
end
