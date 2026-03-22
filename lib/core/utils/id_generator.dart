import 'package:uuid/uuid.dart';

/// Generates UUID v4 identifiers for Firestore documents.
///
/// All document IDs in OneByTwo are generated on-device using UUID v4
/// to support offline-first creation. This avoids depending on a server
/// roundtrip to obtain a document ID.
///
/// Usage:
/// ```dart
/// final expenseId = IdGenerator.generate();
/// // → 'f47ac10b-58cc-4372-a567-0e02b2c3d479'
/// ```
abstract final class IdGenerator {
  static const Uuid _uuid = Uuid();

  /// Generates a new UUID v4 string.
  ///
  /// Returns a random UUID in the standard format:
  /// `xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx`.
  ///
  /// Each call produces a unique, collision-resistant identifier suitable
  /// for use as a Firestore document ID.
  static String generate() => _uuid.v4();

  /// Generates a UUID v4 string with hyphens removed.
  ///
  /// Useful where a shorter, alphanumeric-only ID is preferred
  /// (e.g., invite codes).
  ///
  /// Returns a 32-character hexadecimal string.
  static String generateCompact() => _uuid.v4().replaceAll('-', '');
}
