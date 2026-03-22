import 'package:flutter_test/flutter_test.dart';
import 'package:one_by_two/core/utils/id_generator.dart';

void main() {
  group('IdGenerator', () {
    // ── generate() ──────────────────────────────────────────────────────

    group('generate()', () {
      test('should return a valid UUID v4 format string', () {
        // Arrange & Act
        final id = IdGenerator.generate();

        // Assert — UUID v4: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
        final uuidV4Regex = RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        );
        expect(uuidV4Regex.hasMatch(id), isTrue, reason: 'Got: $id');
      });

      test('should return a 36-character string (including hyphens)', () {
        final id = IdGenerator.generate();
        expect(id.length, equals(36));
      });

      test('should have version nibble 4', () {
        final id = IdGenerator.generate();
        // The 14th character (0-indexed: 14) should be '4'
        expect(id[14], equals('4'));
      });

      test('should have variant nibble in [8, 9, a, b]', () {
        final id = IdGenerator.generate();
        // The 19th character (0-indexed: 19) should be '8', '9', 'a', or 'b'
        expect(id[19], isIn(['8', '9', 'a', 'b']));
      });

      test('two generated IDs should never be the same', () {
        final id1 = IdGenerator.generate();
        final id2 = IdGenerator.generate();

        expect(id1, isNot(equals(id2)));
      });

      test('should generate 100 unique IDs', () {
        final ids = List.generate(100, (_) => IdGenerator.generate());
        final uniqueIds = ids.toSet();

        expect(uniqueIds.length, equals(100));
      });
    });

    // ── generateCompact() ───────────────────────────────────────────────

    group('generateCompact()', () {
      test('should return a UUID without hyphens', () {
        final id = IdGenerator.generateCompact();

        expect(id.contains('-'), isFalse);
      });

      test('should return a 32-character hexadecimal string', () {
        final id = IdGenerator.generateCompact();

        expect(id.length, equals(32));
        expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(id), isTrue);
      });

      test('should still contain version nibble 4', () {
        final id = IdGenerator.generateCompact();
        // In compact form, version nibble is at index 12
        expect(id[12], equals('4'));
      });

      test('two compact IDs should never be the same', () {
        final id1 = IdGenerator.generateCompact();
        final id2 = IdGenerator.generateCompact();

        expect(id1, isNot(equals(id2)));
      });

      test('compact ID should be the standard ID without hyphens', () {
        // Since generateCompact() uses v4().replaceAll('-', ''),
        // we can't compare them directly (they're different calls),
        // but we can verify structural equivalence
        final compactId = IdGenerator.generateCompact();
        // A standard UUID v4 without hyphens is exactly 32 hex chars
        expect(compactId.length, equals(32));
        expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(compactId), isTrue);
      });
    });
  });
}
