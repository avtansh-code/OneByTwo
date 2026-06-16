// FR-AU-09 account-deletion boundary-contract tests.
//
// Mirrors test/features/profile/change_phone_boundary_contract_test.dart
// (group blocks + per-file scan + _isCommentLine helper). The scan target
// is the FIVE new FR-AU-09 lib files explicitly.
//
// Three guarantees enforced by grepping the new (non-comment) source:
//   - Inv-1 (paise integers): NO `.toDouble()`, `parseFloat`, `/ 100`,
//     `.toFixed`, or `double `/`(double ` declarations. FR-AU-09 has no
//     monetary surface.
//   - Inv-2 (simplifiedBalances server-only): NO reference to
//     `simplifiedBalances` — the deletion cascade must NEVER recompute,
//     zero, or strip the surviving members' balances (this is the highest
//     risk regression), and the client never touches the field.
//   - PII (SRS section 5.4 / line 308): NO string-literal analytics key
//     carrying the phone number or a UID. The delete-account events are
//     parameter-free except `delete_account_failed`, which carries only a
//     PII-free `error_code`.

// ignore_for_file: cascade_invocations

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _newDeleteAccountFiles = <String>[
  'lib/features/profile/application/delete_account_controller.dart',
  'lib/features/profile/application/delete_account_telemetry.dart',
  'lib/features/profile/presentation/delete_account_screen.dart',
  'lib/features/profile/data/delete_account_repository.dart',
  'lib/features/profile/data/delete_account_callable_adapter.dart',
];

void main() {
  group('delete account boundary contract — no double / no /100 '
      '(invariant 1)', () {
    test(
      'NEW FR-AU-09 files contain no monetary doubles or paise division',
      () {
        _assertNewFilesExist();
        final violations = <String>[];
        for (final path in _newDeleteAccountFiles) {
          violations.addAll(_scanFileForFloatViolations(File(path)));
        }
        expect(
          violations,
          isEmpty,
          reason:
              'Boundary violations in FR-AU-09 new files:\n'
              '${violations.join('\n')}',
        );
      },
    );
  });

  group('delete account boundary contract — no simplifiedBalances '
      '(invariant 2)', () {
    test('NEW FR-AU-09 files contain no (non-comment) reference to '
        'simplifiedBalances', () {
      _assertNewFilesExist();
      final violations = <String>[];
      for (final path in _newDeleteAccountFiles) {
        final file = File(path);
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (_isCommentLine(line)) continue;
          if (line.contains('simplifiedBalances')) {
            violations.add(
              '${file.path}:${i + 1}: forbidden reference to '
              'simplifiedBalances (server-maintained, preserved on delete)',
            );
          }
        }
      }
      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  });

  group('delete account boundary contract — PII-leak guard (SRS 5.4)', () {
    test('NEW FR-AU-09 files use no phone-number / uid string literal as an '
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
      for (final path in _newDeleteAccountFiles) {
        final file = File(path);
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (_isCommentLine(line)) continue;
          for (final literal in forbiddenLiterals) {
            if (line.contains(literal)) {
              violations.add(
                '${file.path}:${i + 1}: forbidden PII string literal '
                '$literal — the delete-account events never carry the phone '
                'number or a UID (SRS section 5.4)',
              );
            }
          }
        }
      }
      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  });

  group('delete account boundary contract — FR-AU-09 files exist', () {
    test('the five new files are present so the greps above have something '
        'to scan', () {
      final missing = <String>[
        for (final path in _newDeleteAccountFiles)
          if (!File(path).existsSync()) path,
      ];
      expect(
        missing,
        isEmpty,
        reason:
            'FR-AU-09 added these files; if any is missing the contract is '
            'broken and the greps cannot enforce the paise / '
            'simplifiedBalances / PII guarantees.\nMissing: '
            '${missing.join(', ')}',
      );
    });
  });
}

void _assertNewFilesExist() {
  for (final path in _newDeleteAccountFiles) {
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
        '(FR-AU-09 has no monetary path)',
      );
    }
    if (line.contains(RegExp(r'/\s*100\b')) && !line.contains('~/')) {
      violations.add(
        '${file.path}:${i + 1}: forbidden `/ 100` paise division '
        '(FR-AU-09 performs no INR math)',
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
