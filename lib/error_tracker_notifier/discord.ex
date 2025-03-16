defmodule ErrorTrackerNotifier.Discord do
  @moduledoc """
  Handles sending error notifications to Discord via webhooks.
  """

  require Logger
  alias ErrorTrackerNotifier.UrlHelper

  @doc """
  Send a Discord webhook notification for a new error occurrence.
  The header may include error count information if throttling has occurred.
  """
  def send_occurrence_notification(occurrence, header_txt, _config_app) do
    webhook_url = ErrorTrackerNotifier.get_config(:webhook_url, nil)
    app_name = ErrorTrackerNotifier.get_app_name()

    unless webhook_url do
      Logger.error("No Discord webhook URL configured")
      {:error, :missing_webhook_url}
    else
      # Extract file and line information
      first_line =
        if occurrence.stacktrace && occurrence.stacktrace.lines &&
             length(occurrence.stacktrace.lines) > 0 do
          List.first(occurrence.stacktrace.lines)
        else
          nil
        end

      error_location =
        if first_line do
          "#{first_line.module}.#{first_line.function} (#{first_line.file}:#{first_line.line})"
        else
          "Unknown location"
        end

      # Extract useful context information
      view = occurrence.context["live_view.view"] || "Unknown view"
      path = occurrence.context["request.path"] || "Unknown path"

      # Get error URL
      error_url = UrlHelper.get_error_url(occurrence.error_id)
      error_name = occurrence.reason || "Unknown error"

      # Build the message payload
      payload = %{
        embeds: [
          %{
            title: "[#{app_name}] #{header_txt}",
            # Indigo color
            color: 0x4F46E5,
            description: "Error: #{error_name}",
            fields: [
              %{name: "Error ID", value: occurrence.error_id, inline: true},
              %{
                name: "Reason",
                value: truncate_message(occurrence.reason || "Unknown"),
                inline: false
              },
              %{name: "Location", value: error_location, inline: false},
              %{name: "View", value: view, inline: true},
              %{name: "Request Path", value: path, inline: true},
              %{name: "Time", value: format_time(), inline: false}
            ],
            url: error_url,
            footer: %{
              text: "ErrorTracker Notification"
            }
          }
        ],
        username: "Error Tracker"
      }

      case send_discord_webhook(webhook_url, payload) do
        {:ok, _} ->
          Logger.info("Discord notification sent successfully")
          {:ok, "Discord notification sent successfully"}

        {:error, reason} ->
          Logger.error("Failed to send Discord notification: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  defp send_discord_webhook(webhook_url, payload) do
    headers = [
      {"Content-Type", "application/json"}
    ]

    payload_json = Jason.encode!(payload)

    # Use HTTPoison to send the webhook
    case HTTPoison.post(webhook_url, payload_json, headers) do
      {:ok, %{status_code: status}} when status in 200..299 ->
        {:ok, status}

      {:ok, %{status_code: status, body: body}} ->
        {:error, "Discord API error: #{status}, #{body}"}

      {:error, %{reason: reason}} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  defp format_time do
    DateTime.utc_now() |> DateTime.to_string()
  end

  defp truncate_message(message) when is_binary(message) do
    if String.length(message) > 1000 do
      "#{String.slice(message, 0, 997)}..."
    else
      message
    end
  end

  defp truncate_message(message) do
    truncate_message(inspect(message))
  end
end
