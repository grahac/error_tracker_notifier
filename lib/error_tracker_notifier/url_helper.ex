defmodule ErrorTrackerNotifier.UrlHelper do
  @moduledoc """
  Helper functions for generating URLs to errors in the error tracker.
  """

  require Logger

  @doc """
  Gets the base URL from configuration.

  The client application must set this in their config:

  ```elixir
  config :error_tracker_notifier,
    # ... other error tracker config
    base_url: "https://your-app-domain.com"
  ```

  or for environment-specific URLs:

  ```elixir
  config :error_tracker_notifier,
    # ... other error tracker config
    base_url: System.get_env("APP_BASE_URL", "https://localhost:4000")
  ```

  If no base_url is configured, it will attempt to use the application's web endpoint
  module (e.g., MyAppWeb.Endpoint.url()) if available.
  """
  def get_base_url do
    case Application.get_env(:error_tracker_notifier, :base_url) do
      url when is_binary(url) and url != "" ->
        # Remove any trailing slash for consistency
        String.trim_trailing(url, "/")
        
      nil ->
        # Try to get URL from the application's endpoint
        app = app_atom()
        
        # Check for legacy config and show warning
        legacy_config = Application.get_env(app, :error_tracker_notifier)
        if legacy_config && Keyword.has_key?(legacy_config, :base_url) do
          Logger.error("""
          [ERROR] Found base_url configuration under #{inspect(app)}:error_tracker_notifier instead of :error_tracker_notifier
          
          The configuration format has changed. Please update your config files:
          
          Old format (no longer supported):
            config :#{app}, :error_tracker_notifier, base_url: "your-url"
          
          New format (required):
            config :error_tracker_notifier, base_url: "your-url"
          """)
        end
        
        # Try to use endpoint as fallback
        case find_and_use_endpoint(app) do
          {:ok, url} ->
            String.trim_trailing(url, "/")

          {:error, reason} ->
            # Log error if endpoint not found or available
            Logger.error(
              "Base URL not configured and could not use application endpoint: #{reason}. " <>
                "Please add to your config: config :error_tracker_notifier, base_url: \"https://your-app-domain.com\""
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
    error_path = Application.get_env(:error_tracker_notifier, :error_tracker_path, "/dev/errors/")

    # Check for legacy config and show warning
    app = app_atom()
    if app != :error_tracker_notifier do
      legacy_config = Application.get_env(app, :error_tracker_notifier)
      if legacy_config && Keyword.has_key?(legacy_config, :error_tracker_path) do
        Logger.error("""
        [ERROR] Found error_tracker_path configuration under #{inspect(app)}:error_tracker_notifier instead of :error_tracker_notifier
        
        The configuration format has changed. Please update your config files:
        
        Old format (no longer supported):
          config :#{app}, :error_tracker_notifier, error_tracker_path: "/errors"
        
        New format (required):
          config :error_tracker_notifier, error_tracker_path: "/errors"
        """)
      end
    end

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
