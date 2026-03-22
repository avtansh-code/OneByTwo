import 'log_level.dart';

/// Immutable log entry with structured data.
///
/// Each log entry captures a [timestamp], severity [level], source [tag],
/// human-readable [message], and optional structured [data], [error], and
/// [stackTrace] for diagnostics.
class LogEntry {
  /// Creates an immutable log entry.
  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.data,
    this.error,
    this.stackTrace,
  });

  /// When the log event occurred.
  final DateTime timestamp;

  /// Severity level of this entry.
  final LogLevel level;

  /// Source component that produced the log, e.g. `'ExpenseRepository'`.
  final String tag;

  /// Human-readable description of the event.
  final String message;

  /// Optional structured data attached to the log entry.
  final Map<String, dynamic>? data;

  /// Optional error object associated with this entry.
  final Object? error;

  /// Optional stack trace associated with the [error].
  final StackTrace? stackTrace;

  /// Converts this entry to a JSON-serialisable map for file output.
  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'level': level.label,
    'tag': tag,
    'message': message,
    if (data != null) 'data': data,
    if (error != null) 'error': error.toString(),
    if (stackTrace != null) 'stackTrace': stackTrace.toString(),
  };
}
