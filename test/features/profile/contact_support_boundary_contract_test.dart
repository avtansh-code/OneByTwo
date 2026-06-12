// FR-PR-05 Contact Support boundary-contract tests.
//
// Mirrors the STRUCTURE of
// test/features/profile/notification_preferences_boundary_contract_test.dart
// (group blocks + per-file scan + _isCommentLine helper). The SCAN TARGET is
// the explicit list of files ADDED by FR-PR-05 — the modified
// profile_screen.dart is intentionally excluded because its layout code holds
// legitimate `double` declarations (sizes / widths) that would spuriously
// trip the invariant-1 scan.
//
// Three guarantees, enforced statically over the new code:
//   - PII-leak (AC-7 defence-in-depth): the new files contain no
//     string-literal use of `'userId'`, `'uid'`, `'email'`, `'deviceModel'`,
//     `'osVersion'` (and snake_case variants) as analytics-payload keys. The
//     only telemetry parameter is the safe `method` enum token; userId and
//     device diagnostics live solely in the user-visible mailto body.
//   - Invariant 1 (paise integers): no `.toDouble()`, `parseFloat`, `/ 100`,
//     `.toFixed`, or `double` declarations (this surface handles no money).
//   - Invariant 2 (simplifiedBalances server-only): no reference to
//     `simplifiedBalances` (this surface performs no Firestore access).

// ignore_for_file: cascade_invocations

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _newContactSupportFiles = <String>[
  'lib/core/remote_config/remote_config_keys.dart',
  'lib/core/remote_config/remote_config_service.dart',
  'lib/core/services/url_launcher_service.dart',
  'lib/features/profile/domain/support_diagnostics.dart',
  'lib/features/profile/data/device_diagnostics_service.dart',
  'lib/features/profile/application/contact_support_controller.dart',
  'lib/features/profile/application/contact_support_telemetry.dart',
  'lib/features/profile/presentation/contact_support_fallback_dialog.dart',
];

void main() {
  group('contact support boundary contract — PII-leak guard (AC-7)', () {
    test('NEW Contact Support files contain no string-literal '
        'uid / email / device / OS keys in analytics payloads', () {
      _assertNewFilesExist();
      const forbiddenLiterals = <String>[
        "'userId'",
        '"userId"',
        "'uid'",
        '"uid"',
        "'email'",
        '"email"',
        "'deviceModel'",
        '"deviceModel"',
        "'device_model'",
        '"device_model"',
        "'osVersion'",
        '"osVersion"',
        "'os_version'",
        '"os_version"',
      ];
      final violations = <String>[];
      for (final path in _newContactSupportFiles) {
        final file = File(path);
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (_isCommentLine(line)) continue;
          for (final literal in forbiddenLiterals) {
            if (line.contains(literal)) {
              violations.add(
                '${file.path}:${i + 1}: forbidden PII string literal '
                '$literal — `support_email_opened` must carry only the '
                'safe `method` token; userId / email / device details '
                'belong solely in the user-visible mailto body (AC-7)',
              );
            }
          }
        }
      }
      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  });

  group('contact support boundary contract — no double / no /100 '
      '(invariant 1)', () {
    test('NEW Contact Support files contain no monetary doubles '
        'or paise division', () {
      _assertNewFilesExist();
      final violations = <String>[];
      for (final path in _newContactSupportFiles) {
        violations.addAll(_scanFileForFloatViolations(File(path)));
      }
      expect(
        violations,
        isEmpty,
        reason:
            'Boundary violations in FR-PR-05 new files:\n'
            '${violations.join('\n')}',
      );
    });
  });

  group('contact support boundary contract — no simplifiedBalances '
      '(invariant 2)', () {
    test('NEW Contact Support files contain no reference '
        'to simplifiedBalances', () {
      _assertNewFilesExist();
      final violations = <String>[];
      for (final path in _newContactSupportFiles) {
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

  group('contact support boundary contract — FR-PR-05 files exist', () {
    test('the new files are present so the greps above '
        'have something to scan', () {
      final missing = <String>[
        for (final path in _newContactSupportFiles)
          if (!File(path).existsSync()) path,
      ];
      expect(
        missing,
        isEmpty,
        reason:
            'FR-PR-05 added these files; if any is missing, the contract '
            'is broken and the greps above are unable to enforce the '
            'PII / paise / simplifiedBalances guarantees against the new '
            'code paths.\nMissing: ${missing.join(', ')}',
      );
    });
  });
}

void _assertNewFilesExist() {
  for (final path in _newContactSupportFiles) {
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
        '${file.path}:${i + 1}: forbidden `double` declaration '
        '(Contact Support handles no monetary values)',
      );
    }
    if (line.contains(RegExp(r'/\s*100\b')) && !line.contains('~/')) {
      violations.add(
        '${file.path}:${i + 1}: forbidden `/ 100` paise division '
        '(Contact Support performs no INR math)',
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
