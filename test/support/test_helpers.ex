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
end