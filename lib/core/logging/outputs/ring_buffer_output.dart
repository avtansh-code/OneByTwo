import 'dart:collection';

import '../log_entry.dart';
import '../log_output.dart';

/// Keeps the last [capacity] log entries in an in-memory ring buffer.
///
/// Useful for displaying a debug log viewer within the app. When the
/// buffer is full, the oldest entries are evicted automatically.
class RingBufferOutput extends LogOutput {
  /// Creates a [RingBufferOutput] with the given [capacity].
  ///
  /// Defaults to 500 entries.
  RingBufferOutput({this.capacity = 500}) : _buffer = Queue<LogEntry>();

  /// Maximum number of entries to retain.
  final int capacity;

  final Queue<LogEntry> _buffer;

  /// Returns an unmodifiable view of the current buffer contents,
  /// ordered from oldest to newest.
  List<LogEntry> get entries => List<LogEntry>.unmodifiable(_buffer);

  /// Returns the number of entries currently in the buffer.
  int get length => _buffer.length;

  @override
  void write(LogEntry entry) {
    if (_buffer.length >= capacity) {
      _buffer.removeFirst();
    }
    _buffer.addLast(entry);
  }

  /// Clears all entries from the buffer.
  void clear() => _buffer.clear();

  @override
  Future<void> dispose() async {
    _buffer.clear();
  }
}
