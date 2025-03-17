defmodule ErrorTrackerNotifier.UrlHelper do
  @moduledoc """
  Helper functions for generating URLs to errors in the error tracker.
  """

  require Logger

  @doc """
  Gets the base URL from configuration.

  The client application must set this in their config:

  ```elixir
  config :your_app, :error_tracker_notifier,
    # ... other error tracker config
    base_url: "https://your-app-domain.com"
  ```

  or for environment-specific URLs:

  ```elixir
  config :your_app, :error_tracker_notifier,
    # ... other error tracker config
    base_url: System.get_env("APP_BASE_URL", "https://localhost:4000")
  ```

  If no base_url is configured, it will attempt to use the application's web endpoint
  module (e.g., MyAppWeb.Endpoint.url()) if available.
  """
  def get_base_url do
    app = app_atom()
    error_tracker_config = Application.get_env(app, :error_tracker_notifier, [])

    case Keyword.get(error_tracker_config, :base_url) do
      url when is_binary(url) and url != "" ->
        # Remove any trailing slash for consistency
        String.trim_trailing(url, "/")

      nil ->
        # Try to get URL from the application's endpoint
        case find_and_use_endpoint(app) do
          {:ok, url} ->
            String.trim_trailing(url, "/")

          {:error, reason} ->
            # Log error if endpoint not found or available
            Logger.error(
              "Base URL not configured and could not use application endpoint: #{reason}. " <>
                "Please add to your config: config #{inspect(app)}, :error_tracker_notifier, base_url: \"https://your-app-domain.com\""
            )

            "http://localhost:4000"
        end

      invalid ->
        # Log error for misconfigured value
        Logger.error(
          "Invalid base_url configuration: #{inspect(invalid)}. Please set a valid URL string."
        )

        "http://localhost:4000"
    end
  end

  @doc """
  Generates a full URL to view an error in the error tracker.
  """
  def get_error_url(error_id) do
    app = app_atom()
    error_tracker_config = Application.get_env(app, :error_tracker_notifier, [])

    # Get the error path from config or use default
    error_path = Keyword.get(error_tracker_config, :error_tracker_path, "/dev/errors/")

    # Ensure path has leading slash and no trailing slash
    error_path =
      error_path
      |> String.trim_trailing("/")
      |> then(fn path -> if String.starts_with?(path, "/"), do: path, else: "/#{path}" end)

    "#{get_base_url()}#{error_path}/#{error_id}"
  end

  # Determine the application atom to use for config lookup
  defp app_atom do
    # Try to detect the application name dynamically
    case :application.get_application() do
      {:ok, app} ->
        app

      # Fallback to default app name
      _ ->
        :error_tracker_notifier
    end
  end

  # Attempts to find and use the application's web endpoint module
  defp find_and_use_endpoint(app) do
    # Convert app atom to string
    app_name = Atom.to_string(app)

    # Try to construct the Web module name (typical Phoenix convention)
    web_module_name = "Elixir.#{Macro.camelize(app_name)}Web.Endpoint"

    # Attempt to use the endpoint module if it exists
    try do
      web_module = String.to_existing_atom(web_module_name)

      # Check if the module is loaded and has url/0 function
      if Code.ensure_loaded?(web_module) and function_exported?(web_module, :url, 0) do
        {:ok, apply(web_module, :url, [])}
      else
        {:error, "#{web_module_name} is not available or doesn't have url/0 function"}
      end
    rescue
      ArgumentError ->
        # Module doesn't exist, try alternate naming convention
        alt_web_module_name = "Elixir.#{Macro.camelize(app_name)}.Web.Endpoint"

        try do
          alt_web_module = String.to_existing_atom(alt_web_module_name)

          if Code.ensure_loaded?(alt_web_module) and function_exported?(alt_web_module, :url, 0) do
            {:ok, apply(alt_web_module, :url, [])}
          else
            {:error, "Could not find a suitable web endpoint module"}
          end
        rescue
          ArgumentError ->
            {:error, "Could not find a suitable web endpoint module"}
        end
    end
  end
end
