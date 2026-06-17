// Boundary-contract tests for the AC-11 "Open Settings" core seam.
//
// Mirrors the per-feature boundary-contract pattern (e.g.
// test/features/profile/notification_preferences_boundary_contract_test.dart)
// but scans the two NEW shared core files this chore adds:
//   - lib/core/services/app_settings_service.dart
//   - lib/core/telemetry/permission_settings_telemetry.dart
//
// Three groups:
//   - Inv-1 (paise integers): NEW files contain no `.toDouble()`,
//     `parseFloat`, `/ 100`, `.toFixed`, or `double` declarations.
//     These files carry no monetary path.
//   - Inv-2 (simplifiedBalances server-only): NEW files contain no
//     reference to `simplifiedBalances`.
//   - PII-leak (SRS line 308 / ADR-0013): NEW files contain no
//     string-literal use of `'userId'`, `'uid'`, `'friendship_id'`, or
//     `'friendship_id_hash'`. The telemetry `surface` enum values are
//     SAFE non-identifying tokens (`notifications` / `contacts`).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _newFiles = <String>[
  'lib/core/services/app_settings_service.dart',
  'lib/core/telemetry/permission_settings_telemetry.dart',
];

void main() {
  group('open-settings boundary contract — files exist', () {
    test('the two new core files are present so the greps have '
        'something to scan', () {
      final missing = <String>[
        for (final path in _newFiles)
          if (!File(path).existsSync()) path,
      ];
      expect(missing, isEmpty, reason: 'Missing: ${missing.join(', ')}');
    });
  });

  group('open-settings boundary contract — no double / no /100 '
      '(invariant 1)', () {
    test('NEW files contain no monetary doubles or paise division', () {
      final violations = <String>[];
      for (final path in _newFiles) {
        violations.addAll(_scanFileForFloatViolations(File(path)));
      }
      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  });

  group('open-settings boundary contract — no simplifiedBalances '
      '(invariant 2)', () {
    test('NEW files contain no reference to simplifiedBalances', () {
      final violations = <String>[];
      for (final path in _newFiles) {
        final lines = File(path).readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (_isCommentLine(lines[i])) continue;
          if (lines[i].contains('simplifiedBalances')) {
            violations.add('$path:${i + 1}: forbidden simplifiedBalances');
          }
        }
      }
      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  });

  group('open-settings boundary contract — PII-leak guard', () {
    test('NEW files contain no string-literal uid / friendship_id keys', () {
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
      for (final path in _newFiles) {
        final lines = File(path).readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (_isCommentLine(lines[i])) continue;
          for (final literal in forbiddenLiterals) {
            if (lines[i].contains(literal)) {
              violations.add('$path:${i + 1}: forbidden PII literal $literal');
            }
          }
        }
      }
      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  });
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
      violations.add('${file.path}:${i + 1}: forbidden double declaration');
    }
    if (line.contains(RegExp(r'/\s*100\b')) && !line.contains('~/')) {
      violations.add('${file.path}:${i + 1}: forbidden / 100 paise division');
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
