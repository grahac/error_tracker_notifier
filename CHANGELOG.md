# Changelog

## 0.3.0 (2026-09-16)

### Changed
- **Requirement change**: HTTPoison requirement raised from `~> 2.0` to `~> 3.0` (part of the dependency security refresh). Apps pinned to HTTPoison 2.x must upgrade to resolve this version.
- Removed unused `meck` test dependency
- Refreshed dev/test dependency locks (swoosh 1.28.1, phoenix 1.8.14, ex_doc 0.40.4)
- No library code changes — `lib/` is identical to 0.2.2

## 0.2.2 (2026-07-28)

### Fixed
- Remove an unreachable fallback in email notification subjects that triggered a compiler warning

## 0.2.1 (2026-02-15)

### Added
- **Stack traces in notifications**: Email and Discord notifications now include the top 10 stack trace lines (or all if fewer than 10) in an easy-to-copy format for pasting into AI debugging tools
- Automated tests for stack trace formatting with comprehensive edge case coverage

### Changed
- Email notifications now display stack traces in a monospace `<pre>` block with HTML escaping for security
- Discord notifications now display stack traces in code blocks with automatic truncation to respect Discord's 1024 character field limit

## 0.2.0 (2026-01-15)

### Breaking Changes
- Use standard library configuration pattern (`config :error_tracker_notifier, key: value`)
- Removed support for legacy app-nested configuration style (`config :my_app, :error_tracker_notifier, ...`)
- Added explicit error messages to help migrate from legacy configuration

## 0.1.1 (2025-03-17)
# Changed config from :error_tracker to :error_tracker_notifications. Please update config.

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
