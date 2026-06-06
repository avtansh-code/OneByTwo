// Settle Up boundary-contract tests (FR-SE-05).
//
// Grep-based contract enforcement matching the friends_list_boundary
// + friend_detail_boundary patterns (PR #35 + PR #42). Locks the two
// write-side invariants on the new source files:
//
//   Inv-1: no `.toDouble()`, no inline `/ 100` paise→rupee math, no
//          `double` declarations near monetary values.
//   Inv-2: no `simplifiedBalances =` assignment anywhere on the
//          write-side files (the controller's call to
//          netBalancePaise(simplifiedBalances: ...) is a named-argument
//          READ and is explicitly allowed — but lives in the consumer
//          file, not in the settlements/** tree).
//
// These tests run as plain Dart unit tests (no Flutter binding
// required) because they only grep source files on disk.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // All write-side source files for the Settle Up feature. The
  // OBTSettleUpCard lives under friends/ (per Architect Notes §2.6)
  // because it is a navigational affordance hosted by the friends
  // context; the settlement write logic lives in settlements/.
  const sourceFiles = [
    'lib/features/settlements/data/settlement_repository.dart',
    'lib/features/settlements/domain/settlement_doc.dart',
    'lib/features/settlements/domain/settle_up_draft.dart',
    'lib/features/settlements/domain/settlement_create_error.dart',
    'lib/features/settlements/application/settle_up_controller.dart',
    'lib/features/settlements/application/settle_up_state.dart',
    'lib/features/settlements/application/settle_up_telemetry.dart',
    'lib/features/settlements/presentation/settle_up_bottom_sheet.dart',
    'lib/features/settlements/presentation/widgets/settle_up_header.dart',
    'lib/features/friends/presentation/widgets/obt_settle_up_card.dart',
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

  group(
    'Inv-2 (simplifiedBalances client-read-only): no write to the field',
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
          final mapLiteralPattern = RegExp(
            r"""['"]simplifiedBalances['"]\s*:""",
          );
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
    },
  );
}

bool _isCommentLine(String raw) {
  final trimmed = raw.trim();
  return trimmed.startsWith('//') ||
      trimmed.startsWith('*') ||
      trimmed.startsWith('/*');
}
