defmodule ErrorTrackerNotifierTest do
  use ExUnit.Case
  doctest ErrorTrackerNotifier
  
  test "get_config retrieves config values with defaults" do
    # Test getting a configuration value
    value = ErrorTrackerNotifier.get_config(:throttle_seconds, 30)
    assert is_integer(value)
  end
  
  test "get_app_name returns app name" do
    # Test getting the app name
    app_name = ErrorTrackerNotifier.get_app_name()
    assert is_binary(app_name)
  end
end