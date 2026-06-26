// OBTBottomNav + AuthenticatedShell boundary-contract tests.
//
// Mirrors STRUCTURE of test/features/profile/notification_preferences_boundary_contract_test.dart:
//   - hard-coded constant list of NEW files (so spurious recursive
//     scans never flag legitimate layout-related double declarations
//     elsewhere in lib/);
//   - three group blocks: Inv-1 (paise), Inv-2 (simplifiedBalances),
//     PII-leak (uid / friendship_id);
//   - the _isCommentLine helper to skip comments.
//
// Per the chore story §Invariant Compliance: all four invariants are
// N/A on this surface (no money, no simplifiedBalances, no share sheet,
// no Firebase SDK). This grep is the defence-in-depth assertion that
// the shell does not accidentally pick up forbidden patterns through
// future refactors.

// ignore_for_file: cascade_invocations

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _newShellFiles = <String>[
  'lib/features/shell/application/shell_telemetry.dart',
  'lib/features/shell/presentation/authenticated_shell.dart',
  'lib/features/shell/presentation/groups_coming_soon_tab.dart',
  'lib/core/widgets/nav/obt_bottom_nav.dart',
  // FR-HD-04 additions — the two new shell-owned files that ship the
  // persistent FAB primitive and the Add Expense context picker. The
  // boundary-contract grep extends to these so AC-16 (PII guard) +
  // AC-17 (Inv-1 paise) + AC-18 (Inv-2 simplifiedBalances) cover them.
  'lib/core/widgets/nav/obt_floating_action_button.dart',
  'lib/features/shell/presentation/add_expense_context_picker_sheet.dart',
  // FR-PR-04 addition — the shell navigation controller that replaces
  // the in-shell `setState(_currentIndex)`. No money, no
  // simplifiedBalances, no PII flows through tab-index state.
  'lib/features/shell/application/shell_navigation_controller.dart',
];

void main() {
  group(
    'shell boundary contract — no double / no /100 (invariant 1, AC-16)',
    () {
      test('NEW shell files contain no monetary doubles or paise division', () {
        _assertNewFilesExist();
        final violations = <String>[];
        for (final path in _newShellFiles) {
          violations.addAll(_scanFileForFloatViolations(File(path)));
        }
        expect(
          violations,
          isEmpty,
          reason:
              'Boundary violations in new shell files:\n'
              '${violations.join('\n')}',
        );
      });
    },
  );

  group(
    'shell boundary contract — no simplifiedBalances (invariant 2, AC-17)',
    () {
      test('NEW shell files contain no reference to simplifiedBalances', () {
        _assertNewFilesExist();
        final violations = <String>[];
        for (final path in _newShellFiles) {
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

  group('shell boundary contract — PII-leak guard (AC-15)', () {
    test(
      'NEW shell files contain no string-literal uid / friendship_id keys',
      () {
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
        for (final path in _newShellFiles) {
          final file = File(path);
          final lines = file.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            if (_isCommentLine(line)) continue;
            for (final literal in forbiddenLiterals) {
              if (line.contains(literal)) {
                violations.add(
                  '${file.path}:${i + 1}: forbidden PII string literal '
                  '$literal — bottom_nav_tab_selected payload carries only '
                  'tab_index + tab_label (AC-15)',
                );
              }
            }
          }
        }
        expect(violations, isEmpty, reason: violations.join('\n'));
      },
    );
  });

  group('shell boundary contract — new shell files exist', () {
    test(
      'the new shell files are present so the greps have something to scan',
      () {
        final missing = <String>[
          for (final path in _newShellFiles)
            if (!File(path).existsSync()) path,
        ];
        expect(
          missing,
          isEmpty,
          reason:
              'The OBTBottomNav shell change + the FR-HD-04 persistent-FAB '
              'change collectively added these files; if any is missing, '
              'the contract is broken and the greps above cannot enforce '
              'paise / simplifiedBalances / PII guarantees against the new '
              'code paths.\nMissing: ${missing.join(', ')}',
        );
      },
    );
  });

  group('shell boundary contract — temporary HomePlaceholderScreen '
      'deletion (AC-14)', () {
    test('lib/features/auth/presentation/home_placeholder_screen.dart '
        'is deleted', () {
      const path =
          'lib/features/auth/presentation/home_placeholder_screen.dart';
      expect(
        File(path).existsSync(),
        isFalse,
        reason:
            'Per architect §2.4 and AC-14, the temporary '
            'HomePlaceholderScreen must be deleted by the OBTBottomNav '
            'shell change. Its body content was extracted to the Home '
            'tab; the in-AppBar Activity/Profile shortcut buttons are '
            'obsoleted by the OBTBottomNav.',
      );
    });
  });
}

void _assertNewFilesExist() {
  for (final path in _newShellFiles) {
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
        'the shell surface (Invariant 1 defence-in-depth — no money '
        'flows through the bottom nav or tab placeholders)',
      );
    }
    if (line.contains(RegExp(r'/\s*100\b')) && !line.contains('~/')) {
      violations.add(
        '${file.path}:${i + 1}: forbidden `/ 100` paise division '
        '(shell performs no INR math)',
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
