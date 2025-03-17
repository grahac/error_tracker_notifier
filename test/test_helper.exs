# Set runtime mode for tests
Application.put_env(:error_tracker_notifier, :runtime_mode, :test)

ExUnit.start(exclude: [:skip, :integration])

# Define mock modules if needed
Application.put_env(:error_tracker_notifier, :on_load, [])

# Create a test app configuration
Application.put_env(:error_tracker_notifier, :test_app,
  error_tracker_notifier: [
    notification_type: :test,
    throttle_seconds: 1,
    base_url: "https://example.com",
    mailer: ErrorTrackerNotifier.TestHelpers.MockMailer
  ]
)

# Create test support module
defmodule ErrorTrackerNotifier.TestHelpers.MockMailer do
  def deliver(email) do
    send(self(), {:email, email})
    {:ok, %{id: "test-email-id"}}
  end
end

# Create test directories if needed
File.mkdir_p!("test/support")
