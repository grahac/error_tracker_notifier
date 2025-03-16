defmodule ErrorTrackerNotifier.ApplicationTest do
  use ExUnit.Case, async: false
  
  describe "application" do
    test "can be started" do
      # Test explicitly starting the application module
      # First, ensure the GenServer is not running
      if pid = Process.whereis(ErrorTrackerNotifier) do
        GenServer.stop(pid)
        Process.sleep(100)
      end
      
      # Now start it using the application module
      {:ok, pid} = ErrorTrackerNotifier.Application.start(:normal, [])
      
      # Verify the supervisor is running
      assert Process.alive?(pid)
      
      # Check that the ErrorTracker process was started
      assert Process.whereis(ErrorTrackerNotifier) != nil
      
      # Clean up
      Supervisor.stop(pid)
    end
    
    test "can be supervised" do
      # Create a test supervisor
      children = [
        ErrorTrackerNotifier
      ]
      
      # First stop any existing process
      if pid = Process.whereis(ErrorTrackerNotifier) do
        GenServer.stop(pid)
        Process.sleep(100)
      end
      
      # Start a test supervisor
      {:ok, sup_pid} = Supervisor.start_link(children, strategy: :one_for_one)
      
      # Verify ErrorTrackerNotifier is running
      assert Process.whereis(ErrorTrackerNotifier) != nil
      
      # Clean up
      Supervisor.stop(sup_pid)
    end
  end
end