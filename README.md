# ErrorTrackerNotifier

An Elixir library that attaches to ErrorTracker telemetry events and sends email notifications for new errors.

## Installation

The package can be installed by adding `error_tracker_notifier` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:error_tracker_notifier, "~> 0.1.0"}
  ]
end
```

## Configuration

### Email Notifications

Configure email notifications in your `config.exs`:

```elixir
config :my_app, :error_tracker,
  notification_type: :email,       # can be a single atom or a list
  from_email: "support@example.com",
  to_email: "support@example.com",
  mailer: MyApp.Mailer             # your app's Swoosh mailer module
```

### Discord Webhook Notifications

Configure Discord webhook notifications in your `config.exs`:

```elixir
config :my_app, :error_tracker,
  notification_type: :discord,     # can be a single atom or a list
  webhook_url: "https://discord.com/api/webhooks/your-webhook-url"
```

### Using Multiple Notification Types Together

You can configure both email and Discord notifications to be sent simultaneously:

```elixir
config :my_app, :error_tracker,
  notification_type: [:email, :discord], # list of notification types
  from_email: "support@example.com",
  to_email: "support@example.com",
  mailer: MyApp.Mailer,               # your app's Swoosh mailer module
  webhook_url: "https://discord.com/api/webhooks/your-webhook-url"
```

## Setup

Add to your `application.ex`:

```elixir
def start(_type, _args) do
  children = [
    # ...other children
  ]

  # Start the application supervisor
  result = Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
  
  # Set up error notifications after the supervisor starts
  ErrorTrackerNotifier.setup()
  
  result
end
``` 
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

ErrorTrackerNotifier listens for telemetry events from the ErrorTracker library and sends notifications when new errors occur. It handles both new errors and new occurrences of existing errors.

### Email Notifications

The notification emails include:
- Error ID
- Error type and message
- Stack trace information
- Location where the error occurred
- Request context

### Discord Notifications

Discord notifications provide several advantages:
- **Real-time alerts**: Instant delivery to your team's Discord server
- **Mobile notifications**: Get alerts on your phone via the Discord mobile app
- **Better team visibility**: Entire teams can see and respond to errors
- **Threaded discussions**: Team members can discuss and coordinate fixes
- **Rich formatting**: Error details are displayed in well-formatted embeds
- **Searchable history**: Discord keeps a searchable history of all alerts

The Discord notifications include the same information as emails, formatted as rich embeds for better readability.

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