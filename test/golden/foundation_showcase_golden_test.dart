@Tags(['golden'])
library;

// DC-01 — golden harness scaffold (bootstrap for DC-13).
//
// This file establishes the foundation token/type showcase, the baseline
// names, and the pinned-frame pump so that golden baselines accrue from
// PR #1. This group is ENABLED: the pixel comparison runs here and is no
// longer skipped. Determinism comes from the bundled OFL fonts (Bricolage
// Grotesque + Hanken Grotesk), loaded once via `loadHaldiFonts` in
// `golden_harness.dart` and served to google_fonts through its test http
// seam, so the real Haldi type ramp rasterises identically offline.
// Baselines are authored on ubuntu-latest via the manual `golden-refresh`
// workflow and committed under `goldens/`; the `golden-a11y-checks` CI job
// (pinned Flutter version) compares against them on every PR and fails on
// any unintended pixel diff (04-qa-test-strategy.md sections A.2.2 and E).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';

import 'golden_harness.dart';

/// A static showcase of the Haldi foundation: the core colour swatches,
/// the category palette, and the type ramp (including a tabular amount).
/// Rendered light and dark to anchor the foundation goldens.
class FoundationShowcase extends StatelessWidget {
  /// Creates a [FoundationShowcase].
  const FoundationShowcase({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final obt = Theme.of(context).extension<OBTColors>()!;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('One By Two', style: text.displayMedium),
              const SizedBox(height: 8),
              Text(r'$5,234.00 owed', style: text.titleSmall),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Color>[
                  scheme.primary,
                  scheme.secondary,
                  scheme.tertiary,
                  scheme.error,
                  scheme.surfaceContainerHighest,
                  obt.warning,
                  obt.balanceZero,
                  for (final c in OBTCategory.values) obt.categoryColor(c),
                ].map(_Swatch.new).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppTheme.radiusChipInput),
      ),
    );
  }
}

void main() {
  group('Foundation token/type showcase', () {
    setUp(loadHaldiFonts);

    for (final brightness in Brightness.values) {
      final name = brightness.name;
      testWidgets('renders the foundation showcase ($name)', (tester) async {
        await pumpForGolden(
          tester,
          const FoundationShowcase(),
          brightness: brightness,
        );

        await expectLater(
          find.byType(FoundationShowcase),
          matchesGoldenFile('goldens/foundation_showcase__$name.png'),
        );
      });
    }
  });
}
