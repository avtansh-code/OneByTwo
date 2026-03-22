import 'package:flutter/foundation.dart';

import 'log_entry.dart';
import 'log_level.dart';
import 'log_output.dart';
import 'outputs/console_output.dart';
import 'outputs/file_output.dart';
import 'outputs/ring_buffer_output.dart';

/// Singleton logger for the OneByTwo app.
///
/// Must be initialised via [initialize] before any log calls are made
/// (typically in [bootstrap]).
///
/// Usage:
/// ```dart
/// AppLogger.info('ExpenseRepo', 'Expense created', data: {'id': expenseId});
/// AppLogger.error('AuthRepo', 'OTP verification failed', error: e, stackTrace: st);
/// ```
class AppLogger {
  AppLogger._();

  static LogLevel _minimumLevel = LogLevel.debug;
  static final List<LogOutput> _outputs = [];
  static RingBufferOutput? _ringBuffer;
  static bool _initialized = false;

  /// Initialises the logger with configured outputs.
  ///
  /// - In debug mode: console + ring buffer + file outputs.
  /// - In release mode: file + ring buffer outputs (no console).
  ///
  /// [minimumLevel] controls the minimum severity that will be recorded.
  static Future<void> initialize({
    LogLevel minimumLevel = LogLevel.debug,
  }) async {
    if (_initialized) return;

    _minimumLevel = minimumLevel;

    // Console output — debug builds only.
    if (kDebugMode) {
      _outputs.add(ConsoleOutput());
    }

    // Ring buffer — always available for in-app debug viewer.
    _ringBuffer = RingBufferOutput();
    _outputs.add(_ringBuffer!);

    // File output — write logs to disk.
    try {
      final fileOutput = await FileOutput.create();
      _outputs.add(fileOutput);
    } on Exception catch (e) {
      // If file output fails (e.g., during tests), continue without it.
      if (kDebugMode) {
        debugPrint('AppLogger: Failed to create file output: $e');
      }
    }

    _initialized = true;
  }

  /// Returns the in-memory ring buffer entries for the debug log viewer.
  ///
  /// Returns an empty list if the logger has not been initialised.
  static List<LogEntry> get bufferedEntries => _ringBuffer?.entries ?? const [];

  /// Logs a message at [LogLevel.verbose].
  static void verbose(
    String tag,
    String message, {
    Map<String, dynamic>? data,
  }) => _log(LogLevel.verbose, tag, message, data: data);

  /// Logs a message at [LogLevel.debug].
  static void debug(String tag, String message, {Map<String, dynamic>? data}) =>
      _log(LogLevel.debug, tag, message, data: data);

  /// Logs a message at [LogLevel.info].
  static void info(String tag, String message, {Map<String, dynamic>? data}) =>
      _log(LogLevel.info, tag, message, data: data);

  /// Logs a message at [LogLevel.warning].
  static void warning(
    String tag,
    String message, {
    Map<String, dynamic>? data,
    Object? error,
  }) => _log(LogLevel.warning, tag, message, data: data, error: error);

  /// Logs a message at [LogLevel.error].
  static void error(
    String tag,
    String message, {
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  }) => _log(
    LogLevel.error,
    tag,
    message,
    data: data,
    error: error,
    stackTrace: stackTrace,
  );

  /// Logs a message at [LogLevel.fatal].
  static void fatal(
    String tag,
    String message, {
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  }) => _log(
    LogLevel.fatal,
    tag,
    message,
    data: data,
    error: error,
    stackTrace: stackTrace,
  );

  /// Core logging method. Creates a [LogEntry] and dispatches it to all
  /// registered outputs if the [level] meets the minimum threshold.
  static void _log(
    LogLevel level,
    String tag,
    String message, {
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.priority < _minimumLevel.priority) return;

    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
      data: data,
      error: error,
      stackTrace: stackTrace,
    );

    for (final output in _outputs) {
      try {
        output.write(entry);
      } on Exception catch (e) {
        // Avoid infinite loops — only debugPrint if output fails.
        if (kDebugMode) {
          debugPrint('AppLogger: Output failed: $e');
        }
      }
    }
  }

  /// Disposes all outputs and resets the logger state.
  ///
  /// Should be called during app shutdown or in test tearDown.
  static Future<void> dispose() async {
    for (final output in _outputs) {
      await output.dispose();
    }
    _outputs.clear();
    _ringBuffer = null;
    _initialized = false;
  }
}
