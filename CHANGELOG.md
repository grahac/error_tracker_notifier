# Changelog

## 0.1.1 (2025-03-17)
# Changed config from :error_tracker to :error_tracker_notifications.  Please update config.

### Added
- Better error handling when configuration is missing
- Graceful shutdown when no configuration is present
- Improved test mode support
- Documentation updates for environment-specific configuration

## 0.1.0 (Initial Release)

### Added
- Email notifications for ErrorTracker events
- Discord webhook notifications for ErrorTracker events
- Throttling to prevent notification fatigue
- Support for multiple notification types
- Telemetry event handling