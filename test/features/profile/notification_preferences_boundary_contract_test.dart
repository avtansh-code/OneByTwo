// FR-PR-03 notification preferences boundary-contract tests.
//
// Mirrors STRUCTURE of test/features/reminders/reminders_boundary_contract_test.dart
// (group blocks + per-file scan + _isCommentLine helper). However, the
// SCAN TARGET is NARROWED to the three new files explicitly — recursive
// walk of lib/features/profile/** would spuriously flag the legitimate
// layout-related `double` declarations at profile_screen.dart:497/518/519
// (size / width / height). See architect §Additional emphases for the
// rationale.
//
// Three groups:
//   - Inv-1 (paise integers): NEW files contain no `.toDouble()`,
//     `parseFloat`, `/ 100`, `.toFixed`, or `double `/`(double `
//     declarations. The prefs feature mutates `Map<String, bool>` only.
//   - Inv-2 (simplifiedBalances server-only): NEW files contain no
//     reference to `simplifiedBalances`.
//   - PII-leak (AC-20 defence-in-depth): NEW files contain no
//     string-literal use of `'userId'`, `'uid'`, `'friendship_id'`, or
//     `'friendship_id_hash'` as analytics-payload keys.

// ignore_for_file: cascade_invocations

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _newPrefsFiles = <String>[
  'lib/features/profile/application/notification_preferences_telemetry.dart',
  'lib/features/profile/application/notification_preferences_controller.dart',
  'lib/features/profile/presentation/notification_preferences_screen.dart',
];

void main() {
  group('notification preferences boundary contract — '
      'no double / no /100 (invariant 1, AC-21)', () {
    test('NEW notification preferences files contain no monetary '
        'doubles or paise division', () {
      _assertNewFilesExist();
      final violations = <String>[];
      for (final path in _newPrefsFiles) {
        violations.addAll(_scanFileForFloatViolations(File(path)));
      }
      expect(
        violations,
        isEmpty,
        reason:
            'Boundary violations in FR-PR-03 new files:\n'
            '${violations.join('\n')}',
      );
    });
  });

  group('notification preferences boundary contract — '
      'no simplifiedBalances (invariant 2, AC-22)', () {
    test('NEW notification preferences files contain no reference '
        'to simplifiedBalances', () {
      _assertNewFilesExist();
      final violations = <String>[];
      for (final path in _newPrefsFiles) {
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

  group('notification preferences boundary contract — '
      'PII-leak guard (AC-20)', () {
    test('NEW notification preferences files contain no string-literal '
        'uid / friendship_id keys in analytics payloads', () {
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
      for (final path in _newPrefsFiles) {
        final file = File(path);
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (_isCommentLine(line)) continue;
          for (final literal in forbiddenLiterals) {
            if (line.contains(literal)) {
              violations.add(
                '${file.path}:${i + 1}: forbidden PII string literal '
                '$literal — telemetry payloads must not include '
                'UID-derived parameters (AC-20)',
              );
            }
          }
        }
      }
      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  });

  group(
    'notification preferences boundary contract — FR-PR-03 files exist',
    () {
      test('the three new files are present so the greps above '
          'have something to scan', () {
        final missing = <String>[
          for (final path in _newPrefsFiles)
            if (!File(path).existsSync()) path,
        ];
        expect(
          missing,
          isEmpty,
          reason:
              'FR-PR-03 added these files; if any is missing, the contract '
              'is broken and the greps above are unable to enforce paise / '
              'simplifiedBalances / PII guarantees against the new code '
              'paths.\nMissing: ${missing.join(', ')}',
        );
      });
    },
  );
}

void _assertNewFilesExist() {
  for (final path in _newPrefsFiles) {
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
        'a monetary path (prefs feature is bool-only)',
      );
    }
    if (line.contains(RegExp(r'/\s*100\b')) && !line.contains('~/')) {
      violations.add(
        '${file.path}:${i + 1}: forbidden `/ 100` paise division '
        '(prefs feature performs no INR math)',
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
