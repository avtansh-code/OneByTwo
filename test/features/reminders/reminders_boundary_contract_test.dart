// FR-SE-09 reminders feature boundary-contract tests.
//
// Mirrors test/features/notifications/notifications_boundary_contract_test.dart.
// Greps `lib/features/reminders/**` for forbidden patterns that would
// violate the load-bearing invariants:
//
//   - Invariant 1 (paise integers): no `.toDouble()`, no `/ 100`, no
//     `double ` declarations. The reminder body is server-rendered to
//     a pre-formatted string; the client just dispatches the callable
//     and shows server-derived snackbars. Boundary-contract grep is
//     defence-in-depth (AC-20).
//
//   - Invariant 2 (simplifiedBalances server-only): no reference to
//     the string 'simplifiedBalances' anywhere in the reminders
//     client feature folder (AC-21).

// ignore_for_file: cascade_invocations

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('reminders boundary contract — no double / no /100 '
      '(invariant 1, AC-20)', () {
    test('lib/features/reminders contains no `.toDouble()`, '
        '`/ 100`, or `double ` declarations', () {
      final dir = Directory('lib/features/reminders');
      if (!dir.existsSync()) {
        fail(
          'Expected lib/features/reminders to exist; the feature must '
          'be scaffolded before this contract test can run.',
        );
      }

      final violations = _scanForFloatViolations(dir);
      expect(
        violations,
        isEmpty,
        reason:
            'Boundary violations in lib/features/reminders/**:\n'
            '${violations.join('\n')}',
      );
    });
  });

  group('reminders boundary contract — no simplifiedBalances '
      '(invariant 2, AC-21)', () {
    test('lib/features/reminders contains no reference to '
        'simplifiedBalances', () {
      final dir = Directory('lib/features/reminders');
      if (!dir.existsSync()) {
        fail('Expected lib/features/reminders to exist');
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

  group('reminders boundary contract — FR-SE-09 files exist', () {
    test('the reminders feature scaffold is present so the recursive '
        'walks above have something to walk', () {
      const expected = <String>[
        'lib/features/reminders/data/reminder_repository.dart',
        'lib/features/reminders/domain/reminder_send_error.dart',
        'lib/features/reminders/domain/reminder_send_success.dart',
        'lib/features/reminders/application/send_reminder_controller.dart',
        'lib/features/reminders/application/reminder_cooldown_provider.dart',
        'lib/features/reminders/application/reminder_telemetry.dart',
      ];
      final missing = <String>[
        for (final path in expected)
          if (!File(path).existsSync()) path,
      ];
      expect(
        missing,
        isEmpty,
        reason:
            'FR-SE-09 added these files; if any is missing, the contract '
            'is broken and the boundary walks above are unable to enforce '
            'paise / simplifiedBalances guarantees against the new code '
            'paths.\nMissing: ${missing.join(', ')}',
      );
    });
  });
}

List<String> _scanForFloatViolations(Directory dir) {
  final violations = <String>[];
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File) continue;
    if (!entity.path.endsWith('.dart')) continue;
    violations.addAll(_scanFileForFloatViolations(entity));
  }
  return violations;
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
    if (line.contains(' double ') || line.contains('(double ')) {
      violations.add('${file.path}:${i + 1}: forbidden `double` declaration');
    }
    if (line.contains(RegExp(r'/\s*100\b')) && !line.contains('~/')) {
      violations.add(
        '${file.path}:${i + 1}: forbidden `/ 100` paise division '
        '(server pre-renders the body string; client does no INR math)',
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
