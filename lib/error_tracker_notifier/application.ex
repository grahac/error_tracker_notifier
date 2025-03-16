defmodule ErrorTrackerNotifier.Application do
  @moduledoc """
  The application module for ErrorTrackerNotifier.
  
  Starts the ErrorTrackerNotifier GenServer which handles throttling notifications.
  """
  
  use Application
  
  @impl true
  def start(_type, _args) do
    children = [
      # Start the ErrorTrackerNotifier GenServer
      ErrorTrackerNotifier
    ]
    
    # Start the supervisor with a one-for-one strategy
    opts = [strategy: :one_for_one, name: ErrorTrackerNotifier.Supervisor]
    Supervisor.start_link(children, opts)
  end
end