// Friends list boundary-contract tests.
//
// State-transition tests verify that the provider/widget moves through the
// correct AsyncLoading → AsyncData/AsyncError states. They cannot catch a
// boundary defect such as the provider crossing a `double` net balance into
// the widget, or a widget recomputing paise → rupees inline instead of
// using the shared INR formatter. These tests assert the TYPE and
// STRUCTURE of arguments crossing the provider → widget and helper
// boundaries.
//
// Conventions: `docs/patterns/feature-pr-conventions.md` § "Boundary-contract
// tests". The discipline mirrors PR #29's E.164 boundary fix and PR #32's
// match-and-invite boundary tests.
//
// These tests are written BEFORE the implementation exists (test-first).

// ignore_for_file: cascade_invocations

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/balances/net_balance.dart';
import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/features/friends/domain/friend_list_item.dart';
import 'package:onebytwo/features/friends/domain/friendship_doc.dart';

void main() {
  group('FriendListItem boundary contract — type discipline', () {
    test('netBalancePaise is declared as int (not double, not num, not '
        'String)', () {
      const item = FriendListItem(
        friendshipId: 'uid-aaa_uid-me',
        otherUserId: 'uid-aaa',
        displayName: 'Aarav',
        photoUrl: null,
        netBalancePaise: 12345,
      );

      expect(item.netBalancePaise, isA<int>());
      expect(item.netBalancePaise, isNot(isA<double>()));
      // `num` would also match double; the assertion above is the
      // load-bearing one.
    });

    test('FriendListItem carries every field the widget needs and nothing '
        'more', () {
      const item = FriendListItem(
        friendshipId: 'fid',
        otherUserId: 'oid',
        displayName: 'name',
        photoUrl: null,
        netBalancePaise: 0,
      );

      expect(item.friendshipId, isA<String>());
      expect(item.otherUserId, isA<String>());
      expect(item.displayName, isA<String>());
      // photoUrl is nullable String — the type contract for an avatar that
      // may not exist.
      expect(item.photoUrl, isNull);
      expect(item.netBalancePaise, isA<int>());
    });
  });

  group('netBalancePaise pure-function boundary contract', () {
    test('return value is int (invariant 1: paise stays integer)', () {
      final v = netBalancePaise(
        simplifiedBalances: const {
          'uid-friend': {'uid-me': 100},
        },
        currentUserId: 'uid-me',
        otherUserId: 'uid-friend',
      );
      expect(v, isA<int>());
      expect(v, isNot(isA<double>()));
    });
  });

  group('formatInrFromPaise boundary contract', () {
    test('accepts int, returns String — never accepts double', () {
      final s = formatInrFromPaise(12345);
      expect(s, isA<String>());
      // We rely on Dart's static type system to forbid a `double` argument;
      // this test documents the contract for future readers.
    });
  });

  group('FriendshipDoc boundary contract — simplifiedBalances shape', () {
    test('simplifiedBalances is Map<String, Map<String, int>>', () {
      const doc = FriendshipDoc(
        friendshipId: 'fid',
        memberIds: ['uid-aaa', 'uid-me'],
        simplifiedBalances: {
          'uid-aaa': {'uid-me': 1000},
        },
        lastActivityAt: null,
      );

      expect(doc.simplifiedBalances, isA<Map<String, Map<String, int>>>());
    });
  });

  group('Widget-layer source contract — no inline paise→rupee arithmetic', () {
    // Grep the rendered screen and per-feature widgets to confirm no
    // illicit float arithmetic exists on values derived from
    // simplifiedBalances. This complements (does not replace) the type
    // contract above; the grep catches structural drift, the type
    // contract catches local regressions.
    //
    // The pattern is conservative — we only forbid suspicious
    // arithmetic operators applied near identifiers we know carry
    // paise. False positives are guarded against by also excluding
    // documented comment text via `_isCommentLine`.
    const sourceFiles = [
      'lib/features/friends/presentation/friends_list_screen.dart',
      'lib/features/friends/presentation/widgets/friend_list_tile.dart',
      'lib/features/friends/application/friends_list_provider.dart',
      'lib/features/friends/presentation/friend_history_screen.dart',
      'lib/features/friends/application/friend_history_provider.dart',
    ];

    for (final path in sourceFiles) {
      test('$path contains no `double`, `toDouble`, or `/ 100` math', () {
        final file = File(path);
        if (!file.existsSync()) {
          fail('Expected source file $path to exist for boundary grep');
        }
        final content = file.readAsLinesSync();
        for (var i = 0; i < content.length; i++) {
          final line = content[i];
          if (_isCommentLine(line)) continue;
          expect(
            line.contains(' double ') || line.contains('(double '),
            isFalse,
            reason: 'Forbidden `double` declaration in $path:${i + 1}',
          );
          expect(
            line.contains('.toDouble()'),
            isFalse,
            reason: 'Forbidden `.toDouble()` call in $path:${i + 1}',
          );
          expect(
            line.contains(RegExp(r'/\s*100\b')) && !line.contains('~/'),
            isFalse,
            reason:
                'Forbidden `/ 100` paise division in $path:${i + 1}; '
                'use the shared formatInrFromPaise() instead',
          );
        }
      });
    }
  });
}

bool _isCommentLine(String raw) {
  final trimmed = raw.trim();
  return trimmed.startsWith('//') ||
      trimmed.startsWith('*') ||
      trimmed.startsWith('/*');
}

// Imports of widget so the analyzer cannot tree-shake the package import
// away when we only use it as a documentation marker.
// ignore: unused_element
typedef _PinWidget = Widget;
