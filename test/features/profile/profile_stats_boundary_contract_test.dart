// FR-PR-04 profile-stats boundary-contract tests.
//
// Mirrors STRUCTURE of
// test/features/profile/notification_preferences_boundary_contract_test.dart
// (group blocks + per-file scan + _isCommentLine helper). The SCAN
// TARGET is NARROWED to the two NEW FR-PR-04 files explicitly — a
// recursive walk of lib/features/profile/** would spuriously flag the
// legitimate layout-related `double` declarations in profile_screen.dart
// (skeleton size / width / height).
//
// Three groups:
//   - Inv-1 (paise integers): NEW files contain no `.toDouble()`,
//     `parseFloat`, `/ 100`, `.toFixed`, or `double `/`(double `
//     declarations. FR-PR-04 renders COUNTS (cardinality), never money.
//   - Inv-2 (simplifiedBalances server-only): NEW files contain no
//     reference to `simplifiedBalances` (the friend count is a read-only
//     `.length` projection; the field name appears only in a doc-comment
//     in friend_count_provider.dart, which is skipped as a comment line).
//   - PII-leak (AC-9 defence-in-depth): NEW files contain no
//     string-literal use of `'userId'`, `'uid'`, `'friendship_id'`, or
//     `'friendship_id_hash'` as analytics-payload keys. The two
//     profile-stats events are parameter-free.

// ignore_for_file: cascade_invocations

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _newProfileStatsFiles = <String>[
  'lib/features/profile/application/friend_count_provider.dart',
  'lib/features/profile/application/profile_stats_telemetry.dart',
];

void main() {
  group('profile stats boundary contract — '
      'no double / no /100 (invariant 1)', () {
    test('NEW FR-PR-04 files contain no monetary doubles or paise '
        'division', () {
      _assertNewFilesExist();
      final violations = <String>[];
      for (final path in _newProfileStatsFiles) {
        violations.addAll(_scanFileForFloatViolations(File(path)));
      }
      expect(
        violations,
        isEmpty,
        reason:
            'Boundary violations in FR-PR-04 new files:\n'
            '${violations.join('\n')}',
      );
    });
  });

  group('profile stats boundary contract — '
      'no simplifiedBalances (invariant 2)', () {
    test('NEW FR-PR-04 files contain no (non-comment) reference '
        'to simplifiedBalances', () {
      _assertNewFilesExist();
      final violations = <String>[];
      for (final path in _newProfileStatsFiles) {
        final file = File(path);
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (_isCommentLine(line)) continue;
          if (line.contains('simplifiedBalances')) {
            violations.add(
              '${file.path}:${i + 1}: forbidden reference to '
              'simplifiedBalances (server-maintained, client-read-only)',
            );
          }
        }
      }
      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  });

  group('profile stats boundary contract — PII-leak guard (AC-9)', () {
    test('NEW FR-PR-04 files contain no string-literal uid / friendship_id '
        'keys in analytics payloads', () {
      _assertNewFilesExist();
      const forbiddenLiterals = <String>[
        "'userId'",
        '"userId"',
        "'uid'",
        '"uid"',
        "'friendship_id'",
        '"friendship_id"',
        "'friendship_id_hash'",
        '"friendship_id_hash"',
      ];
      final violations = <String>[];
      for (final path in _newProfileStatsFiles) {
        final file = File(path);
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (_isCommentLine(line)) continue;
          for (final literal in forbiddenLiterals) {
            if (line.contains(literal)) {
              violations.add(
                '${file.path}:${i + 1}: forbidden PII string literal '
                '$literal — profile_friends_tapped / profile_groups_tapped '
                'are parameter-free (AC-9)',
              );
            }
          }
        }
      }
      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  });

  group('profile stats boundary contract — FR-PR-04 files exist', () {
    test('the two new files are present so the greps above have '
        'something to scan', () {
      final missing = <String>[
        for (final path in _newProfileStatsFiles)
          if (!File(path).existsSync()) path,
      ];
      expect(
        missing,
        isEmpty,
        reason:
            'FR-PR-04 added these files; if any is missing, the contract '
            'is broken and the greps above are unable to enforce paise / '
            'simplifiedBalances / PII guarantees against the new code '
            'paths.\nMissing: ${missing.join(', ')}',
      );
    });
  });
}

void _assertNewFilesExist() {
  for (final path in _newProfileStatsFiles) {
    if (!File(path).existsSync()) {
      fail('Expected $path to exist before scanning for violations.');
    }
  }
}

List<String> _scanFileForFloatViolations(File file) {
  final violations = <String>[];
  final lines = file.readAsLinesSync();
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (_isCommentLine(line)) continue;

    if (line.contains('.toDouble()')) {
      violations.add('${file.path}:${i + 1}: forbidden .toDouble()');
    }
    if (line.contains('parseFloat')) {
      violations.add('${file.path}:${i + 1}: forbidden parseFloat');
    }
    if (line.contains('.toFixed')) {
      violations.add('${file.path}:${i + 1}: forbidden .toFixed');
    }
    if (line.contains(' double ') || line.contains('(double ')) {
      violations.add(
        '${file.path}:${i + 1}: forbidden `double` declaration on '
        'a monetary path (FR-PR-04 renders integer counts only)',
      );
    }
    if (line.contains(RegExp(r'/\s*100\b')) && !line.contains('~/')) {
      violations.add(
        '${file.path}:${i + 1}: forbidden `/ 100` paise division '
        '(FR-PR-04 performs no INR math)',
      );
    }
  }
  return violations;
}

bool _isCommentLine(String raw) {
  final trimmed = raw.trim();
  return trimmed.startsWith('//') ||
      trimmed.startsWith('*') ||
      trimmed.startsWith('/*');
}
