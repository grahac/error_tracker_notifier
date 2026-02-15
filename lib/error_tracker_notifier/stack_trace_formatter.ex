defmodule ErrorTrackerNotifier.StackTraceFormatter do
  @moduledoc """
  Formats stack traces for different notification channels.
  """

  @doc """
  Formats a stack trace for email notifications with HTML escaping.
  Returns an HTML string with the formatted stack trace, or an empty string if no trace exists.
  """
  def format_for_email(occurrence) do
    case format_lines(occurrence) do
      nil ->
        ""

      formatted_lines ->
        escaped = Phoenix.HTML.html_escape(formatted_lines) |> Phoenix.HTML.safe_to_string()

        """
        <p style="margin: 8px 0 4px 0;"><strong>Stack Trace:</strong></p>
        <pre style="font-family: 'Courier New', monospace; font-size: 12px; margin: 0; white-space: pre-wrap;">#{escaped}</pre>
        """
    end
  end

  @doc """
  Formats a stack trace for Discord notifications with code block syntax.
  Returns a code block string with the formatted stack trace, or nil if no trace exists.
  """
  def format_for_discord(occurrence) do
    case format_lines(occurrence) do
      nil ->
        nil

      formatted_lines ->
        code_block = "```\n#{formatted_lines}\n```"
        truncate_for_discord(code_block)
    end
  end

  defp format_lines(occurrence) do
    case occurrence.stacktrace do
      %{lines: lines} when is_list(lines) and length(lines) > 0 ->
        lines
        |> Enum.take(10)
        |> Enum.map_join("\n", fn line ->
          "#{line.module}.#{line.function} (#{line.file}:#{line.line})"
        end)

      _ ->
        nil
    end
  end

  defp truncate_for_discord(message) when is_binary(message) do
    if String.length(message) > 1000 do
      "#{String.slice(message, 0, 997)}..."
    else
      message
    end
  end
end
