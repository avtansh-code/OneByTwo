/// Severity levels for log entries.
///
/// Each level has a numeric [priority] for filtering and a human-readable
/// [label] for display. Higher priority values indicate more severe events.
enum LogLevel {
  /// Extremely detailed tracing information.
  verbose(0, 'VERBOSE'),

  /// Detailed information useful during development.
  debug(1, 'DEBUG'),

  /// General operational information about app flow.
  info(2, 'INFO'),

  /// Potentially harmful situations that deserve attention.
  warning(3, 'WARNING'),

  /// Error events that might still allow the app to continue.
  error(4, 'ERROR'),

  /// Severe errors that will likely lead to app termination.
  fatal(5, 'FATAL');

  const LogLevel(this.priority, this.label);

  /// Numeric priority for level comparison and filtering.
  final int priority;

  /// Human-readable label for log output.
  final String label;
}
