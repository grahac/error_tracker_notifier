defmodule ErrorTrackerNotifier.TestHelpers do
  @moduledoc """
  Helper functions for testing.
  
  This module provides mock implementations and utilities for testing the library.
  """
  
  @doc """
  Mock implementation of UrlHelper.app_atom/0 that returns :error_tracker_notifier
  """
  def mock_app_atom do
    :error_tracker_notifier
  end
  
  @doc """
  Mock of ErrorTrackerNotifier module for testing.
  """
  defmodule MockMailer do
    def deliver(email) do
      # Send the email to the test process for assertions
      send(self(), {:email, email})
      {:ok, %{id: "test-email-id"}}
    end
  end
  
  @doc """
  Configure the application for testing with a test mailer.
  """
  def configure_test_mailer do
    Application.put_env(
      :error_tracker_notifier,
      :test_app,
      error_tracker_notifier: [
        notification_type: [:test, :email],
        from_email: "test@example.com",
        to_email: "alerts@example.com", 
        mailer: MockMailer
      ]
    )
  end
  
  @doc """
  Configure the application with only test notifications, no external services.
  """
  def configure_test_only do
    Application.put_env(
      :error_tracker_notifier,
      :test_app,
      error_tracker_notifier: [
        notification_type: :test,
        throttle_seconds: 1
      ]
    )
  end

  @doc """
  Builds a test occurrence map with customizable options.

  ## Options

  - `:num_lines` - Number of stack trace lines (default: 1, set to 0 for nil stacktrace)
  - `:error_id` - Error ID (default: "err_test")
  - `:reason` - Error reason (default: "Test error")
  - `:view` - LiveView view name (default: "TestView")
  - `:path` - Request path (default: "/test")

  ## Examples

      build_occurrence()
      build_occurrence(num_lines: 15)
      build_occurrence(error_id: "err_123", reason: "Custom error")
  """
  def build_occurrence(opts \\ []) do
    num_lines = Keyword.get(opts, :num_lines, 1)
    error_id = Keyword.get(opts, :error_id, "err_test")
    reason = Keyword.get(opts, :reason, "Test error")
    view = Keyword.get(opts, :view, "TestView")
    path = Keyword.get(opts, :path, "/test")

    stacktrace =
      if num_lines > 0 do
        %{
          lines:
            Enum.map(1..num_lines, fn i ->
              %{
                module: :"TestModule#{i}",
                function: "test_function_#{i}/1",
                file: "test_file_#{i}.ex",
                line: i * 10
              }
            end)
        }
      else
        nil
      end

    %{
      error_id: error_id,
      reason: reason,
      context: %{
        "live_view.view" => view,
        "request.path" => path
      },
      stacktrace: stacktrace
    }
  end
end