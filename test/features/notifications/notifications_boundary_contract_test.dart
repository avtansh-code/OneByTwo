// Notifications feature boundary-contract tests (FR-AC-03).
//
// Mirrors test/features/activity/activity_boundary_contract_test.dart.
// Greps `lib/features/notifications/**` and
// `lib/core/routing/notification_deep_links.dart` for forbidden
// patterns that would violate the load-bearing invariants:
//
//   - Invariant 1 (paise integers): no `.toDouble()`, no `/ 100`, no
//     `double ` declarations. The notification body is server-rendered
//     to a pre-formatted string; the client just displays it. The
//     boundary-contract grep is defence-in-depth (AC-15).
//
//   - Invariant 2 (simplifiedBalances server-only): no reference to
//     the string 'simplifiedBalances' (AC-16).

// ignore_for_file: cascade_invocations

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('notifications boundary contract — no double / no /100 '
      '(invariant 1, AC-15)', () {
    test('lib/features/notifications contains no `.toDouble()`, '
        '`/ 100`, or `double ` declarations', () {
      final dir = Directory('lib/features/notifications');
      if (!dir.existsSync()) {
        fail(
          'Expected lib/features/notifications to exist; the feature '
          'must be scaffolded before this contract test can run.',
        );
      }

      final violations = _scanForFloatViolations(dir);
      expect(
        violations,
        isEmpty,
        reason:
            'Boundary violations in lib/features/notifications/**:\n'
            '${violations.join('\n')}',
      );
    });

    test('lib/core/routing/notification_deep_links.dart contains no '
        '`.toDouble()`, `/ 100`, or `double ` declarations', () {
      final file = File('lib/core/routing/notification_deep_links.dart');
      if (!file.existsSync()) {
        fail('Expected notification_deep_links.dart to exist');
      }
      final violations = _scanFileForFloatViolations(file);
      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  });

  group('notifications boundary contract — no simplifiedBalances '
      '(invariant 2, AC-16)', () {
    test('lib/features/notifications contains no reference to '
        'simplifiedBalances', () {
      final dir = Directory('lib/features/notifications');
      if (!dir.existsSync()) {
        fail('Expected lib/features/notifications to exist');
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

    test('lib/core/routing/notification_deep_links.dart contains no '
        'reference to simplifiedBalances', () {
      final file = File('lib/core/routing/notification_deep_links.dart');
      if (!file.existsSync()) {
        fail('Expected notification_deep_links.dart to exist');
      }
      final lines = file.readAsLinesSync();
      final violations = <String>[];
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (_isCommentLine(line)) continue;
        if (line.contains('simplifiedBalances')) {
          violations.add(
            '${file.path}:${i + 1}: forbidden reference to '
            'simplifiedBalances',
          );
        }
      }
      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  });

  group('notifications boundary contract — FR-AC-03 / FR-AC-05 files '
      'exist', () {
    test('the notifications-feature scaffold + shared routing helper are '
        'present so the recursive walks above have something to walk', () {
      const expected = <String>[
        'lib/features/notifications/domain/notification_payload.dart',
        'lib/features/notifications/data/fcm_token_service.dart',
        'lib/features/notifications/data/notification_handler.dart',
        'lib/features/notifications/application/firebase_messaging_provider.dart',
        'lib/features/notifications/application/pending_deep_link_provider.dart',
        'lib/features/notifications/application/deep_link_handler.dart',
        'lib/features/notifications/application/notification_permission_controller.dart',
        'lib/features/notifications/presentation/pre_permission_dialog.dart',
        'lib/features/notifications/presentation/widgets/in_app_notification_banner.dart',
        'lib/core/routing/notification_deep_links.dart',
      ];
      final missing = <String>[
        for (final path in expected)
          if (!File(path).existsSync()) path,
      ];
      expect(
        missing,
        isEmpty,
        reason:
            'FR-AC-03 / FR-AC-05 added these files; if any is missing, '
            'the contract is broken and the boundary walks above are '
            'unable to enforce paise / simplifiedBalances guarantees '
            'against the new code paths.\nMissing: '
            '${missing.join(', ')}',
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
