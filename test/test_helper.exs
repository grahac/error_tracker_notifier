# Setup test environment
Application.put_env(:error_tracker_notifier, :error_tracker, [
  notification_type: :test,
  throttle_seconds: 10
])

ExUnit.start()
