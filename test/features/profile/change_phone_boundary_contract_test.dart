// FR-PR-02 change-phone boundary-contract tests.
//
// Mirrors the structure of
// test/features/profile/profile_stats_boundary_contract_test.dart
// (group blocks + per-file scan + _isCommentLine helper). The scan target
// is the THREE new FR-PR-02 files explicitly.
//
// Three groups:
//   - Inv-1 (paise integers): NEW files contain no `.toDouble()`,
//     `parseFloat`, `/ 100`, `.toFixed`, or `double `/`(double `
//     declarations. FR-PR-02 has no monetary surface.
//   - Inv-2 (simplifiedBalances server-only): NEW files contain no
//     reference to `simplifiedBalances` (untouched by this feature; the
//     name appears only in doc-comments which are skipped).
//   - PII (SRS section 5.4 / line 308): NEW files contain no string-literal
//     analytics key carrying the phone number or a UID. The phone-change
//     events are parameter-free or carry only `leg` / `error_code`.

// ignore_for_file: cascade_invocations

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _newChangePhoneFiles = <String>[
  'lib/features/profile/application/change_phone_controller.dart',
  'lib/features/profile/presentation/change_phone_screen.dart',
  'lib/features/auth/data/phone_account_repository.dart',
];

void main() {
  group(
    'change phone boundary contract — no double / no /100 (invariant 1)',
    () {
      test(
        'NEW FR-PR-02 files contain no monetary doubles or paise division',
        () {
          _assertNewFilesExist();
          final violations = <String>[];
          for (final path in _newChangePhoneFiles) {
            violations.addAll(_scanFileForFloatViolations(File(path)));
          }
          expect(
            violations,
            isEmpty,
            reason:
                'Boundary violations in FR-PR-02 new files:\n'
                '${violations.join('\n')}',
          );
        },
      );
    },
  );

  group(
    'change phone boundary contract — no simplifiedBalances (invariant 2)',
    () {
      test('NEW FR-PR-02 files contain no (non-comment) reference to '
          'simplifiedBalances', () {
        _assertNewFilesExist();
        final violations = <String>[];
        for (final path in _newChangePhoneFiles) {
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
    },
  );

  group('change phone boundary contract — PII-leak guard (SRS 5.4)', () {
    test('NEW FR-PR-02 files use no phone-number / uid string literal as an '
        'analytics key', () {
      _assertNewFilesExist();
      const forbiddenLiterals = <String>[
        "'phoneNumber'",
        '"phoneNumber"',
        "'phone_number'",
        '"phone_number"',
        "'uid'",
        '"uid"',
        "'userId'",
        '"userId"',
      ];
      final violations = <String>[];
      for (final path in _newChangePhoneFiles) {
        final file = File(path);
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (_isCommentLine(line)) continue;
          for (final literal in forbiddenLiterals) {
            if (line.contains(literal)) {
              violations.add(
                '${file.path}:${i + 1}: forbidden PII string literal '
                '$literal — the change-phone events never carry the phone '
                'number or a UID (SRS section 5.4)',
              );
            }
          }
        }
      }
      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  });

  group('change phone boundary contract — FR-PR-02 files exist', () {
    test('the three new files are present so the greps above have something '
        'to scan', () {
      final missing = <String>[
        for (final path in _newChangePhoneFiles)
          if (!File(path).existsSync()) path,
      ];
      expect(
        missing,
        isEmpty,
        reason:
            'FR-PR-02 added these files; if any is missing the contract is '
            'broken and the greps cannot enforce the paise / '
            'simplifiedBalances / PII guarantees.\nMissing: '
            '${missing.join(', ')}',
      );
    });
  });
}

void _assertNewFilesExist() {
  for (final path in _newChangePhoneFiles) {
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
        '(FR-PR-02 has no monetary path)',
      );
    }
    if (line.contains(RegExp(r'/\s*100\b')) && !line.contains('~/')) {
      violations.add(
        '${file.path}:${i + 1}: forbidden `/ 100` paise division '
        '(FR-PR-02 performs no INR math)',
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
