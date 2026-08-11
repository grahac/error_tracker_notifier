defmodule ErrorTrackerNotifier.Telegram do
  @moduledoc """
  Handles sending error notifications to Telegram via Bot API.
  """

  require Logger
  alias ErrorTrackerNotifier.UrlHelper

  @telegram_api_base "https://api.telegram.org"

  @doc """
  Send a Telegram notification for a new error occurrence.
  The header may include error count information if throttling has occurred.
  """
  def send_occurrence_notification(occurrence, header_txt, _config_app) do
    bot_token = ErrorTrackerNotifier.get_config(:telegram_bot_token, nil)
    chat_id = ErrorTrackerNotifier.get_config(:telegram_chat_id, nil)
    app_name = ErrorTrackerNotifier.get_app_name()

    unless bot_token && chat_id do
      Logger.error("No Telegram bot token or chat ID configured")
      {:error, :missing_telegram_config}
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

      # Build the message text
      message =
        build_message(
          app_name,
          header_txt,
          error_name,
          occurrence.error_id,
          error_location,
          view,
          path,
          error_url
        )

      case send_telegram_message(bot_token, chat_id, message) do
        {:ok, _} ->
          Logger.info("Telegram notification sent successfully")
          {:ok, "Telegram notification sent successfully"}

        {:error, reason} ->
          Logger.error("Failed to send Telegram notification: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  defp send_telegram_message(bot_token, chat_id, message) do
    url = "#{@telegram_api_base}/bot#{bot_token}/sendMessage"

    headers = [
      {"Content-Type", "application/json"}
    ]

    payload = %{
      chat_id: chat_id,
      text: message,
      parse_mode: "HTML",
      disable_web_page_preview: true
    }

    payload_json = Jason.encode!(payload)

    # Use HTTPoison to send the message
    case HTTPoison.post(url, payload_json, headers) do
      {:ok, %{status_code: status, body: body}} when status in 200..299 ->
        # Parse response to check for Telegram API errors
        case Jason.decode(body) do
          {:ok, %{"ok" => true}} ->
            {:ok, status}

          {:ok, %{"ok" => false, "description" => description}} ->
            {:error, "Telegram API error: #{description}"}

          {:ok, response} ->
            {:error, "Unexpected Telegram API response: #{inspect(response)}"}

          {:error, _} ->
            {:ok, status}
        end

      {:ok, %{status_code: status, body: body}} ->
        {:error, "Telegram API HTTP error: #{status}, #{body}"}

      {:error, %{reason: reason}} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  defp build_message(
         app_name,
         header_txt,
         error_name,
         error_id,
         error_location,
         view,
         path,
         error_url
       ) do
    """
    <b>[#{escape_html(app_name)}] #{escape_html(header_txt)}</b>

    <b>Error:</b> #{escape_html(error_name)}
    <b>Error ID:</b> <code>#{escape_html(error_id)}</code>
    <b>Location:</b> <code>#{escape_html(error_location)}</code>
    <b>View:</b> #{escape_html(view)}
    <b>Request Path:</b> <code>#{escape_html(path)}</code>
    <b>Time:</b> #{format_time()}

    <a href="#{error_url}">View Error Details</a>
    """
    |> String.trim()
  end

  defp escape_html(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  defp escape_html(text) do
    escape_html(inspect(text))
  end

  defp format_time do
    DateTime.utc_now() |> DateTime.to_string()
  end
end
