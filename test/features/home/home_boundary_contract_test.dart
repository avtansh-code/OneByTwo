// Home dashboard boundary-contract tests (invariants 1 and 2).
//
// Complements the state-transition widget tests: a grep over the home
// feature's source files asserts that no illicit float arithmetic
// (`double`, `.toDouble()`, `/ 100`) and no client write to
// `simplifiedBalances` exists. The widget/provider tests catch
// behavioural regressions; this grep catches structural drift.
//
// Mirrors `friends_list_boundary_contract_test.dart`.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _homeSourceFiles = [
  'lib/features/home/application/home_balances_providers.dart',
  'lib/features/home/application/home_telemetry.dart',
  'lib/features/home/application/monthly_spend_breakdown_provider.dart',
  'lib/features/home/domain/monthly_spend_breakdown.dart',
  'lib/features/home/domain/monthly_spend_aggregator.dart',
  'lib/features/home/presentation/home_dashboard_screen.dart',
  'lib/features/home/presentation/widgets/net_balance_header_card.dart',
  'lib/features/home/presentation/widgets/top_balance_tile.dart',
  'lib/features/home/presentation/widgets/spending_breakdown_card.dart',
  'lib/features/home/presentation/widgets/spending_category_palette.dart',
  'lib/features/home/presentation/widgets/spending_donut_chart.dart',
];

void main() {
  group('home boundary contract — invariant 1 (no float money math)', () {
    for (final path in _homeSourceFiles) {
      test('$path contains no `double`, `toDouble`, or `/ 100` math', () {
        final file = File(path);
        expect(
          file.existsSync(),
          isTrue,
          reason: 'Expected source file $path to exist for boundary grep',
        );
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (_isCommentLine(line)) continue;
          expect(
            line.contains(' double ') || line.contains('(double '),
            isFalse,
            reason: 'Forbidden `double` in $path:${i + 1}',
          );
          expect(
            line.contains('.toDouble()'),
            isFalse,
            reason: 'Forbidden `.toDouble()` in $path:${i + 1}',
          );
          expect(
            line.contains(RegExp(r'/\s*100\b')) && !line.contains('~/'),
            isFalse,
            reason:
                'Forbidden `/ 100` paise division in $path:${i + 1}; use '
                'formatInrFromPaise() instead',
          );
        }
      });
    }
  });

  group('home boundary contract — invariant 2 (simplifiedBalances '
      'read-only)', () {
    for (final path in _homeSourceFiles) {
      test('$path never writes simplifiedBalances', () {
        final lines = File(path).readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (_isCommentLine(line)) continue;
          // No assignment to or update-map key for the field. The
          // dashboard is a pure read-side projection.
          expect(
            line.contains("'simplifiedBalances'") ||
                line.contains('"simplifiedBalances"') ||
                line.contains('.simplifiedBalances ='),
            isFalse,
            reason:
                'Home is read-only over simplifiedBalances; suspicious '
                'reference in $path:${i + 1}',
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
