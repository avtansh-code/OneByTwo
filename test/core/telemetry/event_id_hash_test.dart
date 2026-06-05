// Event ID hash utility tests.
//
// Tests `hashFriendshipId(String)` — the SHA-256-based one-way hash used
// to produce a stable, opaque correlation ID for telemetry events that
// otherwise would carry a deterministic friendshipId (composed of two
// UIDs and therefore PII-adjacent).
//
// These tests are written BEFORE the implementation exists (test-first).

import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/telemetry/event_id_hash.dart';

void main() {
  group('hashFriendshipId', () {
    test('returns a 16-character lowercase hex string', () {
      final out = hashFriendshipId('uid-aaa_uid-bbb');
      expect(out, hasLength(16));
      expect(
        RegExp(r'^[0-9a-f]{16}$').hasMatch(out),
        isTrue,
        reason: 'Expected 16 lowercase hex chars, got "$out"',
      );
    });

    test('is deterministic — same input produces the same hash', () {
      final h1 = hashFriendshipId('uid-aaa_uid-bbb');
      final h2 = hashFriendshipId('uid-aaa_uid-bbb');
      expect(h1, equals(h2));
    });

    test('different inputs produce different hashes', () {
      final h1 = hashFriendshipId('uid-aaa_uid-bbb');
      final h2 = hashFriendshipId('uid-aaa_uid-ccc');
      expect(h1, isNot(equals(h2)));
    });

    test(
      'output never contains any substring of the input UIDs (PII safety)',
      () {
        const friendshipId = 'uid-priyalakshmi_uid-rahulagarwal';
        final out = hashFriendshipId(friendshipId);
        for (final fragment in [
          'priya',
          'rahul',
          'lakshmi',
          'agarwal',
          'uid-',
        ]) {
          expect(
            out.contains(fragment),
            isFalse,
            reason: 'Hash leaked PII fragment "$fragment" in "$out"',
          );
        }
      },
    );

    test('empty string input is handled without throwing', () {
      expect(() => hashFriendshipId(''), returnsNormally);
      expect(hashFriendshipId(''), hasLength(16));
    });
  });
}
