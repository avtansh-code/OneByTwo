import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../log_entry.dart';
import '../log_level.dart';
import '../log_output.dart';
import '../pii_sanitizer.dart';

/// Writes formatted log entries to [debugPrint] with level-based prefixes.
///
/// Uses ANSI colour codes when running on platforms that support them.
/// Output is sanitized via [PiiSanitizer] before printing.
class ConsoleOutput extends LogOutput {
  /// Maps each [LogLevel] to an emoji prefix for easy visual scanning.
  static const Map<LogLevel, String> _levelPrefixes = {
    LogLevel.verbose: '⚪',
    LogLevel.debug: '🔵',
    LogLevel.info: '🟢',
    LogLevel.warning: '🟡',
    LogLevel.error: '🔴',
    LogLevel.fatal: '💀',
  };

  @override
  void write(LogEntry entry) {
    final prefix = _levelPrefixes[entry.level] ?? '';
    final timestamp = _formatTimestamp(entry.timestamp);
    final sanitizedMessage = PiiSanitizer.sanitize(entry.message);

    final buffer = StringBuffer()
      ..write('$prefix [${entry.level.label}] ')
      ..write('$timestamp ')
      ..write('[${entry.tag}] ')
      ..write(sanitizedMessage);

    if (entry.data != null) {
      final sanitizedData = PiiSanitizer.sanitizeMap(entry.data!);
      buffer.write(' | ${jsonEncode(sanitizedData)}');
    }

    debugPrint(buffer.toString());

    if (entry.error != null) {
      debugPrint('  ↳ Error: ${PiiSanitizer.sanitize(entry.error.toString())}');
    }

    if (entry.stackTrace != null) {
      debugPrint('  ↳ StackTrace:\n${entry.stackTrace}');
    }
  }

  /// Formats a [DateTime] as `HH:mm:ss.mmm` for compact console output.
  String _formatTimestamp(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    final ms = dt.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  @override
  Future<void> dispose() async {
    // No resources to release for console output.
  }
}
