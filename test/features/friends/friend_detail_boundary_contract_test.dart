// Friend Detail boundary-contract tests (FR-FR-04).
//
// Grep-based contract enforcement matching the friends_list_boundary
// pattern (PR #35). Locks the two read-side invariants on the new files:
//
//   Inv-1: no `.toDouble()`, no inline `/ 100` paise→rupee math, no
//          `double` declarations near monetary values.
//   Inv-2: no `simplifiedBalances =` assignment anywhere on the
//          read-side files.
//
// These tests run as plain Dart unit tests (no Flutter binding required)
// because they only grep source files on disk.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const sourceFiles = [
    'lib/features/friends/presentation/friend_detail_screen.dart',
    'lib/features/friends/presentation/widgets/friend_detail_header.dart',
    'lib/features/friends/presentation/widgets/friend_detail_timeline.dart',
    'lib/features/friends/presentation/widgets/friend_detail_states.dart',
    'lib/features/friends/application/friend_detail_provider.dart',
  ];

  group('Inv-1 (paise integers): no inline paise→rupee math', () {
    for (final path in sourceFiles) {
      test('$path contains no `double`, `toDouble`, or `/ 100` math', () {
        final file = File(path);
        if (!file.existsSync()) {
          fail('Expected source file $path to exist for boundary grep');
        }
        final content = file.readAsLinesSync();
        for (var i = 0; i < content.length; i++) {
          final line = content[i];
          if (_isCommentLine(line)) continue;
          expect(
            line.contains(' double ') || line.contains('(double '),
            isFalse,
            reason: 'Forbidden `double` declaration in $path:${i + 1}',
          );
          expect(
            line.contains('.toDouble()'),
            isFalse,
            reason: 'Forbidden `.toDouble()` call in $path:${i + 1}',
          );
          expect(
            line.contains(RegExp(r'/\s*100\b')) && !line.contains('~/'),
            isFalse,
            reason:
                'Forbidden `/ 100` paise division in $path:${i + 1}; '
                'use the shared formatInrFromPaise() instead',
          );
        }
      });
    }
  });

  group('Inv-2 (simplifiedBalances client-read-only): no write to the field',
      () {
    for (final path in sourceFiles) {
      test('$path contains no assignment to simplifiedBalances', () {
        final file = File(path);
        if (!file.existsSync()) {
          fail('Expected source file $path to exist for boundary grep');
        }
        final content = file.readAsLinesSync();
        // Forbid: (a) Dart-style assignment `simplifiedBalances = X` where
        // the `=` is not the `==` equality operator, and (b) the quoted
        // map-literal key `'simplifiedBalances':` or `"simplifiedBalances":`
        // which would indicate a write payload field.
        //
        // We deliberately ALLOW `simplifiedBalances:` (without quotes) as
        // a named argument, e.g. the call site of `netBalancePaise(
        // simplifiedBalances: ..., currentUserId: ..., otherUserId: ...)`
        // — this is a READ contract, not a write.
        final assignmentPattern = RegExp(r'simplifiedBalances\s*=[^=]');
        final mapLiteralPattern =
            RegExp(r"""['"]simplifiedBalances['"]\s*:""");
        for (var i = 0; i < content.length; i++) {
          final line = content[i];
          if (_isCommentLine(line)) continue;
          expect(
            assignmentPattern.hasMatch(line),
            isFalse,
            reason:
                'Forbidden simplifiedBalances assignment in $path:${i + 1}; '
                'this field is server-maintained (Invariant 2)',
          );
          expect(
            mapLiteralPattern.hasMatch(line),
            isFalse,
            reason:
                'Forbidden simplifiedBalances map-literal key in '
                '$path:${i + 1}; this field is server-maintained '
                '(Invariant 2)',
          );
        }
      });
    }
  });
}

bool _isCommentLine(String raw) {
  final trimmed = raw.trim();
  return trimmed.startsWith('//') ||
      trimmed.startsWith('*') ||
      trimmed.startsWith('/*');
}
