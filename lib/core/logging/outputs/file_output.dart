import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../log_entry.dart';
import '../log_file_rotator.dart';
import '../log_output.dart';
import '../pii_sanitizer.dart';

/// Writes log entries as JSON Lines to a file with automatic rotation.
///
/// Each entry is written as a single JSON object per line (JSONL format).
/// File rotation is handled by [LogFileRotator] with a default maximum
/// of 5 MB per file and 3 rotated files.
///
/// Must be initialised via [FileOutput.create] before use, because
/// resolving the app documents directory is asynchronous.
class FileOutput extends LogOutput {
  FileOutput._(this._rotator);

  final LogFileRotator _rotator;
  IOSink? _sink;
  bool _disposed = false;

  /// Creates and initialises a [FileOutput].
  ///
  /// Resolves the application documents directory and sets up the log file
  /// at `<docs>/logs/app.log`.
  static Future<FileOutput> create({
    int maxFileSizeBytes = 5 * 1024 * 1024,
    int maxFiles = 3,
  }) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final logDir = Directory('${docsDir.path}/logs');
    if (!logDir.existsSync()) {
      await logDir.create(recursive: true);
    }

    final basePath = '${logDir.path}/app.log';
    final rotator = LogFileRotator(
      basePath: basePath,
      maxFileSizeBytes: maxFileSizeBytes,
      maxFiles: maxFiles,
    );

    final output = FileOutput._(rotator);
    await output._openSink();
    return output;
  }

  /// Opens (or reopens) the file sink for writing.
  Future<void> _openSink() async {
    await _rotator.rotateIfNeeded();
    final file = _rotator.activeFile;
    _sink = file.openWrite(mode: FileMode.append);
  }

  @override
  void write(LogEntry entry) {
    if (_disposed || _sink == null) return;

    final json = entry.toJson();

    // Sanitize PII from the JSON map before writing.
    if (json.containsKey('data') && json['data'] is Map<String, dynamic>) {
      json['data'] = PiiSanitizer.sanitizeMap(
        json['data'] as Map<String, dynamic>,
      );
    }
    if (json.containsKey('message') && json['message'] is String) {
      json['message'] = PiiSanitizer.sanitize(json['message'] as String);
    }

    _sink!.writeln(jsonEncode(json));

    // Check rotation asynchronously; don't block the write call.
    _checkRotation();
  }

  /// Checks if the file needs rotation and re-opens the sink if so.
  Future<void> _checkRotation() async {
    if (_disposed) return;

    final file = _rotator.activeFile;
    if (!file.existsSync()) return;

    final size = await file.length();
    if (size >= _rotator.maxFileSizeBytes) {
      await _sink?.flush();
      await _sink?.close();
      await _rotator.rotateIfNeeded();
      await _openSink();
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
  }
}
