// Activity feature boundary-contract tests (FR-AC-01).
//
// Greps lib/features/activity/** and lib/core/widgets/lists/
// obt_activity_row.dart for forbidden patterns that would violate the
// load-bearing invariants:
//
// - Invariant 1 (paise integers): no `.toDouble()`, no `/ 100`, no
//   `double ` declarations anywhere on the amount path.
// - Invariant 2 (simplifiedBalances server-only): no reference to
//   the string 'simplifiedBalances' in the activity feature folder.
//
// Mirrors test/features/expenses/expense_creation_boundary_contract_test.dart
// — the conventions established for write-side guarding (FR-EX-01) and
// read-side guarding (FR-FR-03) are extended here to the activity-feed
// read-side path.

// ignore_for_file: cascade_invocations

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('activity boundary contract — no double / no /100 (invariant 1)', () {
    test('lib/features/activity contains no `.toDouble()`, `/ 100`, or '
        '`double ` declarations (AC-15)', () {
      final dir = Directory('lib/features/activity');
      if (!dir.existsSync()) {
        fail(
          'Expected lib/features/activity to exist; the feature must be '
          'scaffolded before this contract test can run.',
        );
      }

      final violations = <String>[];
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File) continue;
        if (!entity.path.endsWith('.dart')) continue;

        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (_isCommentLine(line)) continue;

          if (line.contains('.toDouble()')) {
            violations.add('${entity.path}:${i + 1}: forbidden .toDouble()');
          }
          if (line.contains(' double ') || line.contains('(double ')) {
            violations.add(
              '${entity.path}:${i + 1}: forbidden `double` declaration',
            );
          }
          if (line.contains(RegExp(r'/\s*100\b')) && !line.contains('~/')) {
            violations.add(
              '${entity.path}:${i + 1}: forbidden `/ 100` paise division '
              '(use formatInrFromPaise instead)',
            );
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Boundary violations in lib/features/activity/**:\n'
            '${violations.join('\n')}',
      );
    });

    test('lib/core/widgets/lists/obt_activity_row.dart contains no '
        '`.toDouble()`, `/ 100`, or `double ` declarations (AC-15)', () {
      final file = File('lib/core/widgets/lists/obt_activity_row.dart');
      if (!file.existsSync()) {
        fail('Expected OBTActivityRow source to exist');
      }
      final violations = <String>[];
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (_isCommentLine(line)) continue;
        if (line.contains('.toDouble()')) {
          violations.add('${file.path}:${i + 1}: forbidden .toDouble()');
        }
        if (line.contains(' double ') || line.contains('(double ')) {
          violations.add(
            '${file.path}:${i + 1}: forbidden `double` declaration',
          );
        }
        if (line.contains(RegExp(r'/\s*100\b')) && !line.contains('~/')) {
          violations.add(
            '${file.path}:${i + 1}: forbidden `/ 100` paise division',
          );
        }
      }
      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  });

  group('activity boundary contract — no simplifiedBalances (invariant 2)', () {
    test('lib/features/activity contains no reference to simplifiedBalances '
        '(AC-16)', () {
      final dir = Directory('lib/features/activity');
      if (!dir.existsSync()) {
        fail('Expected lib/features/activity to exist');
      }

      final violations = <String>[];
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File) continue;
        if (!entity.path.endsWith('.dart')) continue;

        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (_isCommentLine(line)) continue;
          if (line.contains('simplifiedBalances')) {
            violations.add(
              '${entity.path}:${i + 1}: forbidden reference to '
              'simplifiedBalances (server-maintained, client-read-only)',
            );
          }
        }
      }

      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  });

  group('activity boundary contract — FR-AC-01 files exist', () {
    test('the activity-feature scaffold and OBTActivityRow are present '
        'and therefore covered by the recursive walks above', () {
      const expected = <String>[
        'lib/features/activity/data/activity_feed_repository.dart',
        'lib/features/activity/domain/activity_feed_item.dart',
        'lib/features/activity/domain/activity_event_type.dart',
        'lib/features/activity/application/activity_feed_provider.dart',
        'lib/features/activity/application/relative_timestamp_formatter.dart',
        'lib/features/activity/presentation/activity_feed_screen.dart',
        'lib/features/activity/presentation/widgets/activity_feed_skeleton.dart',
        'lib/core/widgets/lists/obt_activity_row.dart',
      ];
      final missing = <String>[
        for (final path in expected)
          if (!File(path).existsSync()) path,
      ];
      expect(
        missing,
        isEmpty,
        reason:
            'FR-AC-01 added these files; if any is missing, the FR-AC-01 '
            'contract is broken and the boundary walks above are unable '
            'to enforce paise / simplifiedBalances guarantees against '
            'the new code paths.\nMissing: ${missing.join(', ')}',
      );
    });
  });

  group('activity boundary contract — row-tap does NOT switch primary tabs '
      '(FR-AC-05)', () {
    test('activity_feed_screen.dart contains no selectTab / '
        'shellNavigationController reference', () {
      final file = File(
        'lib/features/activity/presentation/activity_feed_screen.dart',
      );
      if (!file.existsSync()) {
        fail('Expected activity_feed_screen.dart to exist');
      }
      final lines = file.readAsLinesSync();
      final violations = <String>[];
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (_isCommentLine(line)) continue;
        if (line.contains('selectTab') ||
            line.contains('shellNavigationController')) {
          violations.add(
            '${file.path}:${i + 1}: forbidden tab-switch reference — the '
            'activity-feed row tap is an in-tab navigation and must never '
            'select a primary tab (FR-AC-05 tab-switch is FCM-dispatch only)',
          );
        }
      }
      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  });
}

bool _isCommentLine(String raw) {
  final trimmed = raw.trim();
  return trimmed.startsWith('//') ||
      trimmed.startsWith('*') ||
      trimmed.startsWith('/*');
}
