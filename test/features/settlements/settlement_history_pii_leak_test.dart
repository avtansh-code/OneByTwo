// Settlement history PII-leak + boundary-contract tests (FR-SE-08).
//
// Grep-based defence-in-depth over the three NEW source files, mirroring
// the settle_up_boundary_contract pattern. Locks the invariant triad:
//
//   Inv-1 (paise integers): no `double` decls, no `.toDouble()`, no
//          `.toFixed`, no `parseFloat`, no inline `/ 100` paise math.
//   Inv-2 (simplifiedBalances client-read-only): the field is never
//          referenced on this read-only surface.
//   PII (ADR-0013): neither telemetry event carries a UID-derived
//          parameter — the source contains no `'context_id'`,
//          `'friendship_id'`, `'friendship_id_hash'`, `'uid'`, or
//          `'userId'` string-literal parameter keys. (Variable names
//          such as `currentUserUid` are deliberately NOT matched — only
//          quoted parameter-key literals are forbidden.)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const sourceFiles = [
    'lib/features/settlements/application/settlement_history_telemetry.dart',
    'lib/features/settlements/application/settlement_history_provider.dart',
    'lib/features/settlements/presentation/settlement_history_screen.dart',
  ];

  group('Inv-1 (paise integers): no inline paise→rupee math', () {
    for (final path in sourceFiles) {
      test('$path contains no double / toDouble / toFixed / `/ 100`', () {
        final lines = _sourceLines(path);
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
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
            line.contains('.toFixed'),
            isFalse,
            reason: 'Forbidden `.toFixed` call in $path:${i + 1}',
          );
          expect(
            line.contains('parseFloat'),
            isFalse,
            reason: 'Forbidden `parseFloat` call in $path:${i + 1}',
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

  group('Inv-2 (simplifiedBalances client-read-only)', () {
    for (final path in sourceFiles) {
      test('$path never references simplifiedBalances', () {
        final lines = _sourceLines(path);
        for (var i = 0; i < lines.length; i++) {
          expect(
            lines[i].contains('simplifiedBalances'),
            isFalse,
            reason:
                'Forbidden simplifiedBalances reference in $path:${i + 1}; '
                'this field is server-maintained (Invariant 2)',
          );
        }
      });
    }
  });

  group('PII (ADR-0013): no UID-derived telemetry parameter-key literals', () {
    const forbiddenLiterals = <String>[
      "'context_id'",
      '"context_id"',
      "'friendship_id'",
      '"friendship_id"',
      "'friendship_id_hash'",
      '"friendship_id_hash"',
      "'uid'",
      '"uid"',
      "'userId'",
      '"userId"',
    ];

    for (final path in sourceFiles) {
      test('$path contains no forbidden parameter-key literal', () {
        final lines = _sourceLines(path);
        for (var i = 0; i < lines.length; i++) {
          for (final literal in forbiddenLiterals) {
            expect(
              lines[i].contains(literal),
              isFalse,
              reason:
                  'Forbidden PII parameter-key literal $literal in '
                  '$path:${i + 1}',
            );
          }
        }
      });
    }
  });
}

/// Reads a source file's non-comment lines. Fails the test if the file
/// does not exist (the boundary contract must guard a real file).
List<String> _sourceLines(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    fail('Expected source file $path to exist for boundary grep');
  }
  return file
      .readAsLinesSync()
      .where((line) => !_isCommentLine(line))
      .toList(growable: false);
}

bool _isCommentLine(String raw) {
  final trimmed = raw.trim();
  return trimmed.startsWith('//') ||
      trimmed.startsWith('*') ||
      trimmed.startsWith('/*');
}
