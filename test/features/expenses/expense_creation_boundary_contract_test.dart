// Expense creation boundary-contract tests (FR-EX-01).
//
// Greps lib/features/expenses/** for forbidden patterns that would
// violate the load-bearing invariants:
//
// - Invariant 1 (paise integers): no `.toDouble()`, no `/ 100`, no
//   `double ` declarations anywhere on the amount path.
// - Invariant 2 (simplifiedBalances server-only): no reference to
//   the string 'simplifiedBalances' in the expense feature folder.
//
// Mirrors test/features/friends/friends_list_boundary_contract_test.dart
// — the conventions established for read-side guarding are extended here
// to the FIRST client-side write path.

// ignore_for_file: cascade_invocations

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('expenses boundary contract — no double / no /100 (invariant 1)', () {
    test('lib/features/expenses contains no `.toDouble()`, `/ 100`, or '
        '`double ` declarations (AC-15)', () {
      final dir = Directory('lib/features/expenses');
      if (!dir.existsSync()) {
        fail(
          'Expected lib/features/expenses to exist; the feature must be '
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
            'Boundary violations in lib/features/expenses/**:\n'
            '${violations.join('\n')}',
      );
    });
  });

  group('expenses boundary contract — no simplifiedBalances (invariant 2)', () {
    test('lib/features/expenses contains no reference to simplifiedBalances '
        '(AC-16)', () {
      final dir = Directory('lib/features/expenses');
      if (!dir.existsSync()) {
        fail('Expected lib/features/expenses to exist');
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
}

bool _isCommentLine(String raw) {
  final trimmed = raw.trim();
  return trimmed.startsWith('//') ||
      trimmed.startsWith('*') ||
      trimmed.startsWith('/*');
}
