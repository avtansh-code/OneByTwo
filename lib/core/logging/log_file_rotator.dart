import 'dart:io';

/// Handles log file rotation based on size limits.
///
/// Maintains up to [maxFiles] log files, each capped at [maxFileSizeBytes].
/// When the active file exceeds the size limit, older files are rotated
/// (renamed) and the active file is replaced.
class LogFileRotator {
  /// Creates a [LogFileRotator].
  ///
  /// - [basePath]: full path to the active log file, e.g.
  ///   `/data/user/0/com.example/files/logs/app.log`.
  /// - [maxFileSizeBytes]: defaults to 5 MB.
  /// - [maxFiles]: defaults to 3.
  LogFileRotator({
    required this.basePath,
    this.maxFileSizeBytes = 5 * 1024 * 1024,
    this.maxFiles = 3,
  });

  /// Maximum size in bytes for a single log file before rotation.
  final int maxFileSizeBytes;

  /// Maximum number of rotated log files to keep (including the active file).
  final int maxFiles;

  /// Base path for log files. Rotated files are named `<base>.1`, `<base>.2`,
  /// etc.
  final String basePath;

  /// Returns the [File] handle for the active log file.
  File get activeFile => File(basePath);

  /// Returns the rotated file path for the given [index] (1-based).
  String _rotatedPath(int index) => '$basePath.$index';

  /// Checks if the active file needs rotation and performs it if so.
  ///
  /// Rotation shifts existing files:
  /// `app.log.2` → deleted, `app.log.1` → `app.log.2`,
  /// `app.log` → `app.log.1`, then a fresh `app.log` is created.
  Future<void> rotateIfNeeded() async {
    final file = activeFile;
    if (!file.existsSync()) return;

    final size = await file.length();
    if (size < maxFileSizeBytes) return;

    await _rotate();
  }

  /// Performs the actual file rotation.
  Future<void> _rotate() async {
    // Delete the oldest rotated file if it exists.
    final oldestPath = _rotatedPath(maxFiles - 1);
    final oldestFile = File(oldestPath);
    if (oldestFile.existsSync()) {
      await oldestFile.delete();
    }

    // Shift rotated files: .2 → .3, .1 → .2, etc.
    for (var i = maxFiles - 2; i >= 1; i--) {
      final source = File(_rotatedPath(i));
      if (source.existsSync()) {
        await source.rename(_rotatedPath(i + 1));
      }
    }

    // Move active file to .1.
    final active = activeFile;
    if (active.existsSync()) {
      await active.rename(_rotatedPath(1));
    }
  }

  /// Deletes all log files (active and rotated).
  Future<void> deleteAll() async {
    final active = activeFile;
    if (active.existsSync()) {
      await active.delete();
    }
    for (var i = 1; i < maxFiles; i++) {
      final rotated = File(_rotatedPath(i));
      if (rotated.existsSync()) {
        await rotated.delete();
      }
    }
  }
}
