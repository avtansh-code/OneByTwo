// Profile cluster Haldi boundary-contract test (DC-10).
//
// Mirrors the DC-09 no-`Color(0x…)` grep in
// test/features/notifications/notifications_boundary_contract_test.dart.
//
// The load-bearing rule: no hard-coded Haldi hex may remain in the converted
// Profile presentation. Every colour must flow from
// Theme.of(context).colorScheme / OBTColors tokens. The old hand-rolled
// `_ShimmerEffect` greys (Color(0xFFE0E0E0) / Color(0xFFF5F5F5)) were the only
// hex literals in the cluster; they are re-pointed to the shared OBTSkeleton
// set. A literal hex left at a call site is a blocking defect.

// ignore_for_file: cascade_invocations

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The converted Profile presentation surfaces (AC-1 / AC-2). The deleted
/// `profile_placeholder_screen.dart` (AC-3) is intentionally absent.
const _convertedSurfaces = <String>[
  'lib/features/profile/presentation/profile_screen.dart',
  'lib/features/profile/presentation/edit_profile_screen.dart',
  'lib/features/profile/presentation/change_phone_screen.dart',
  'lib/features/profile/presentation/notification_preferences_screen.dart',
  'lib/features/profile/presentation/delete_account_screen.dart',
  'lib/features/profile/presentation/contact_support_fallback_dialog.dart',
  'lib/features/profile/presentation/widgets/photo_picker_sheet.dart',
];

void main() {
  group('profile boundary contract — no hard-coded Haldi hex in the '
      'converted surfaces (tokens only, DC-10)', () {
    for (final path in _convertedSurfaces) {
      test('$path contains no `Color(0x…)` literal — every colour flows from '
          'Theme.of(context).colorScheme / OBTColors tokens', () {
        final file = File(path);
        if (!file.existsSync()) {
          fail('Expected $path to exist (DC-10 converted surface)');
        }
        final violations = <String>[];
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (_isCommentLine(line)) continue;
          if (line.contains(RegExp(r'Color\(0x'))) {
            violations.add(
              '$path:${i + 1}: forbidden hard-coded hex `Color(0x…)` — '
              're-point to a Haldi token (ColorScheme / OBTColors); a literal '
              'hex left at a call site is a blocking defect',
            );
          }
        }
        expect(violations, isEmpty, reason: violations.join('\n'));
      });
    }
  });

  group('profile boundary contract — the AC-3 placeholder is deleted', () {
    test('profile_placeholder_screen.dart no longer exists', () {
      final file = File(
        'lib/features/profile/presentation/profile_placeholder_screen.dart',
      );
      expect(
        file.existsSync(),
        isFalse,
        reason:
            'AC-3: profile_placeholder_screen.dart is superseded by the Haldi '
            '27 profile_screen.dart and must be deleted, not converted.',
      );
    });
  });
}

bool _isCommentLine(String raw) {
  final trimmed = raw.trim();
  return trimmed.startsWith('//') ||
      trimmed.startsWith('*') ||
      trimmed.startsWith('/*');
}
