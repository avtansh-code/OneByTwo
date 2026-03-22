import 'log_entry.dart';

/// Abstract interface for log output destinations.
///
/// Implementations write [LogEntry] objects to a specific destination
/// such as the debug console, a file, or an in-memory buffer.
abstract class LogOutput {
  /// Writes a single [entry] to this output destination.
  void write(LogEntry entry);

  /// Releases resources held by this output.
  ///
  /// After calling [dispose], no further [write] calls should be made.
  Future<void> dispose();
}
