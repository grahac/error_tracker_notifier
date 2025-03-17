# ErrorTrackerNotifier

ErrorTrackerNotifier is an Elixir library that adds to the amazing [ErrorTracker](https://github.com/elixir-error-tracker/error-tracker) library by sending email and/or Discord notifications for errors found by error_tracker. Note: This is a very early version and was mostly vibe-coded with some oversight so no promises!




## Installation

The package can be installed by adding `error_tracker_notifier` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:error_tracker_notifier, "~> 0.1.1"}
  ]
end
```

## Configuration

### Email Notifications

Configure email notifications in your `config.exs`:

```elixir
config :my_app, :error_tracker_notifier,
  notification_type: :email,       # can be a single atom or a list
  from_email: "support@example.com",
  to_email: "support@example.com",
  mailer: MyApp.Mailer             # your app's Swoosh mailer module
```

### Discord Webhook Notifications

Configure Discord webhook notifications in your `config.exs`:

```elixir
config :my_app, :error_tracker_notifier,
  notification_type: :discord,     # can be a single atom or a list
  webhook_url: "https://discord.com/api/webhooks/your-webhook-url"
```

### Using Multiple Notification Types Together

You can configure both email and Discord notifications to be sent simultaneously:

```elixir
config :my_app, :error_tracker_notifier,
  notification_type: [:email, :discord], # list of notification types
  from_email: "support@example.com",
  to_email: "support@example.com",
  mailer: MyApp.Mailer,               # your app's Swoosh mailer module
  webhook_url: "https://discord.com/api/webhooks/your-webhook-url",
  base_url: "https://your-app-domain.com", # base URL for error links
  error_tracker_path: "/errors",      # path to errors (default: "/dev/errors/")
  throttle_seconds: 60                # time to wait between notifications for the same error
```

### Throttling Notifications

To prevent alert fatigue during error storms, you can configure throttling:

```elixir
config :my_app, :error_tracker_notifier,
  # ... other settings
  throttle_seconds: 10  # Only send one notification per error every 10 seconds (default)
```

When multiple errors of the same type occur within the throttle period, they are batched together. The next notification will include a count of how many occurrences were throttled, helping you understand the error frequency without being overwhelmed by notifications.

### URL Configuration

You can customize the URLs generated for error links by configuring both the base URL and error path:

```elixir
config :my_app, :error_tracker_notifier,
  # ... other settings
  base_url: "https://your-app-domain.com", 
  error_tracker_path: "/errors"  # default is "/dev/errors/"
```

The full URL generated will be: `<base_url><error_tracker_path>/<error_id>`

For example, with the above configuration, an error with ID `abc123` would have the URL: 
`https://your-app-domain.com/errors/abc123`

## Setup

You have two options for setting up ErrorTrackerNotifier:

### Option 1: Add to your supervision tree (recommended)

Add ErrorTrackerNotifier to your supervision tree in `application.ex`:

```elixir
def start(_type, _args) do
  children = [
    # ...other children
    {ErrorTrackerNotifier, []}
  ]

  # Start the application supervisor with ErrorTrackerNotifier
  Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
end
```

This starts the ErrorTrackerNotifier GenServer which handles both notification sending and throttling.

### Option 2: Just attach telemetry handlers

If you don't need throttling or just want to use the telemetry handlers without starting a GenServer:

```elixir
# Call this during your application startup (after ErrorTracker is initialized)
ErrorTrackerNotifier.setup_telemetry()
```

This approach only sets up the telemetry handlers without starting the GenServer. Note that with this approach, throttling won't be available - every error will trigger a notification. 
#### Setting up a Discord Webhook

To set up a Discord webhook for error notifications:

1. **Create or use an existing Discord server**
   - You need to have the "Manage Webhooks" permission in the server

2. **Create a channel for error notifications**
   - It's recommended to create a dedicated channel like `#error-alerts`
   - Go to your Discord server
   - Click the "+" icon on the left sidebar to create a new channel
   - Name it appropriately (e.g., "error-alerts")
   - Set the appropriate permissions for who can see error notifications

3. **Create a webhook**
   - Right-click on the channel and select "Edit Channel"
   - Select the "Integrations" tab
   - Click on "Webhooks" and then "New Webhook"
   - Give the webhook a name (e.g., "Error Tracker")
   - Optionally, upload an avatar for the webhook
   - Click "Copy Webhook URL" to get the URL
   - Click "Save"

4. **Add the webhook URL to your application config**
   - Add the copied webhook URL to your `config.exs` as shown above
   - Make sure to keep this URL secure, as anyone with the URL can post messages to your Discord channel

5. **Test the webhook (optional)**
   - You can test the webhook with a tool like [Postman](https://www.postman.com/) or using curl:
   ```bash
   curl -X POST -H "Content-Type: application/json" \
        -d '{"content": "Testing error tracker webhook"}' \
        https://discord.com/api/webhooks/your-webhook-url
   ```



## How It Works

ErrorTrackerNotifier listens for telemetry events from the ErrorTracker library and sends notifications when new errors occur. It handles both new errors and new occurrences of existing errors, and implements throttling to prevent notification fatigue.

### Email Notifications

The notification emails include:
- Error ID
- Error type and message
- Stack trace information
- Location where the error occurred
- Request context
- Count of occurrences (when throttling is active)

### Discord Notifications

Discord notifications provide several advantages:
- **Real-time alerts**: Instant delivery to your team's Discord server
- **Mobile notifications**: Get alerts on your phone via the Discord mobile app
- **Better team visibility**: Entire teams can see and respond to errors
- **Threaded discussions**: Team members can discuss and coordinate fixes
- **Rich formatting**: Error details are displayed in well-formatted embeds
- **Searchable history**: Discord keeps a searchable history of all alerts

The Discord notifications include the same information as emails, formatted as rich embeds for better readability, including error occurrence counts when throttling is active.

## Dependencies

This library depends on:
- `error_tracker` for error tracking
- `telemetry` for event handling

For email notifications:
- `swoosh` for email delivery

For Discord notifications:
- `httpoison` for making HTTP requests to Discord API
- `jason` for JSON encoding

## Documentation

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/error_tracker_notifier>.

### Environment-Specific Configuration

ErrorTrackerNotifier is designed to work well with environment-specific configurations. If you only want to receive error notifications in your production environment, you can simply:

1. Only define the configuration in `prod.exs` or `runtime.exs` (using `prod` as the environment)
2. Leave the configuration undefined in `dev.exs` and `test.exs`

When running in development or test environments, ErrorTrackerNotifier will automatically detect the absence of configuration and gracefully shut down without sending any notifications or logging errors.

```elixir
# Only in prod.exs or in runtime.exs with environment check
if config_env() == :prod do
  config :my_app, :error_tracker_notifier,
    notification_type: [:email, :discord],
    # ... other configuration
end
```

This way, developers can work locally without worrying about error notifications firing in development environments.

### Testing with ErrorTrackerNotifier

ErrorTrackerNotifier provides a clean way to handle testing without affecting production behavior:

1. The library checks for a `:runtime_mode` configuration setting:
   ```elixir
   # In test_helper.exs
   Application.put_env(:error_tracker_notifier, :runtime_mode, :test)
   ```

2. In test mode, configuration validation is bypassed, allowing tests to run without error notifications
   
3. You can still configure specific test behavior if needed:
   ```elixir
   # In test setup
   Application.put_env(:your_app, :error_tracker_notifier,
     notification_type: :test  # Special test type that doesn't send actual notifications
   )
   ```

This separation ensures your tests run correctly while maintaining the production behavior of gracefully shutting down when no configuration is present.

### Email Notifications
