@Tags(['a11y-contrast'])
library;

// DC-01 — WCAG 2.1 contrast gate (04-qa-test-strategy.md section B).
//
// Reads the RESOLVED token pairs from AppTheme (not hard-coded hex) and
// computes the WCAG contrast ratio (L1 + 0.05) / (L2 + 0.05) via
// Color.computeLuminance(), so a one-token chromatic drift is caught.
// Each pairing must meet its role threshold (>= 4.5 body text, >= 3.0
// large/UI) and stay close to its measured figure.
//
// Canonical negative case (AC #3): white on marigold ~ 2.5:1 FAILS AA, so
// onPrimary must be the ink token, never white.
//
// A leading `testWidgets` primes the theme/fonts in a test zone (AppTheme
// builds via google_fonts) and captures the resolved colours; the pure
// `test` assertions then run on those captures.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';

/// WCAG 2.1 relative-contrast ratio between [a] and [b].
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

late ColorScheme light;
late ColorScheme dark;
late Color lightBg;
late Color darkBg;
late OBTColors obtLight;
late OBTColors obtDark;

void main() {
  testWidgets('prime: resolve the Haldi token pairs', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const SizedBox.shrink()),
    );
    light = AppTheme.light.colorScheme;
    dark = AppTheme.dark.colorScheme;
    lightBg = AppTheme.light.scaffoldBackgroundColor;
    darkBg = AppTheme.dark.scaffoldBackgroundColor;
    obtLight = AppTheme.light.extension<OBTColors>()!;
    obtDark = AppTheme.dark.extension<OBTColors>()!;
  });

  group('Handoff-verified pairings (meet role threshold + measured)', () {
    test('ink on background (light) is AAA', () {
      final r = contrastRatio(light.onSurface, lightBg);
      expect(r, greaterThanOrEqualTo(7.0));
      expect(r, closeTo(14.66, 0.1));
    });

    test('ink on marigold (onPrimary) is AA', () {
      final r = contrastRatio(light.onPrimary, light.primary);
      expect(r, greaterThanOrEqualTo(4.5));
      expect(r, closeTo(6.25, 0.1));
    });

    test('positive on white is AA (body)', () {
      final r = contrastRatio(light.tertiary, light.surface);
      expect(r, greaterThanOrEqualTo(4.5));
      expect(r, closeTo(5.04, 0.1));
    });

    test('negative on white is AA (body)', () {
      final r = contrastRatio(light.error, light.surface);
      expect(r, greaterThanOrEqualTo(4.5));
      expect(r, closeTo(5.36, 0.1));
    });

    test('dark text on dark canvas is AAA', () {
      final r = contrastRatio(dark.onSurface, darkBg);
      expect(r, greaterThanOrEqualTo(7.0));
      expect(r, closeTo(15.31, 0.1));
    });
  });

  group('Foundation design-intent pairings (meet role threshold)', () {
    test('onPrimary dark — ink on marigold-dark is AA', () {
      final r = contrastRatio(dark.onPrimary, dark.primary);
      expect(r, greaterThanOrEqualTo(4.5));
      expect(r, closeTo(8.43, 0.1));
    });

    test('onError dark — ink on danger-dark salmon', () {
      final r = contrastRatio(dark.onError, dark.error);
      expect(r, greaterThanOrEqualTo(4.5));
      expect(r, closeTo(7.20, 0.1));
    });

    test('onSecondary light — cream on terracotta clears large/UI', () {
      final r = contrastRatio(light.onSecondary, light.secondary);
      expect(r, greaterThanOrEqualTo(3.0));
      expect(r, closeTo(3.90, 0.1));
    });

    test('onTertiary light — white on success is AA', () {
      final r = contrastRatio(light.onTertiary, light.tertiary);
      expect(r, greaterThanOrEqualTo(4.5));
      expect(r, closeTo(5.04, 0.1));
    });

    test('onTertiary dark — ink on success-dark clears large/UI', () {
      final r = contrastRatio(dark.onTertiary, dark.tertiary);
      expect(r, greaterThanOrEqualTo(3.0));
      expect(r, closeTo(7.96, 0.1));
    });
  });

  group('Balance-signal colours meet AA on surface (section 1.5)', () {
    test('balancePositive / balanceNegative on light surface', () {
      expect(
        contrastRatio(obtLight.balancePositive, light.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrastRatio(obtLight.balanceNegative, light.surface),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('Meta text (textTertiary) clears AA on its surfaces (DC-02)', () {
    // Timestamps and cooldown captions are 12px bodySmall (normal text), so
    // the role threshold is 4.5:1 — not the 3:1 large-text allowance.
    test('light textTertiary clears AA on the warm light surfaces', () {
      expect(
        contrastRatio(obtLight.textTertiary, lightBg),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrastRatio(obtLight.textTertiary, light.surfaceContainerHighest),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrastRatio(obtLight.textTertiary, light.surface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('dark textTertiary clears AA on the elevated dark surface', () {
      // surfaceContainerHighest is the highest-luminance dark surface and so
      // the worst case for light-on-dark meta text (the settle-up caption).
      expect(
        contrastRatio(obtDark.textTertiary, dark.surfaceContainerHighest),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrastRatio(obtDark.textTertiary, darkBg),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('Canonical negative case — white on marigold (AC #3)', () {
    test('white on marigold FAILS AA (~2.5:1)', () {
      final r = contrastRatio(Colors.white, light.primary);
      expect(r, lessThan(4.5));
      expect(r, closeTo(2.52, 0.1));
    });

    test('onPrimary is the ink token, never white', () {
      expect(light.onPrimary, isNot(Colors.white));
      expect(dark.onPrimary, isNot(Colors.white));
      // And the chosen ink clears AA where white would not.
      expect(
        contrastRatio(light.onPrimary, light.primary),
        greaterThan(contrastRatio(Colors.white, light.primary)),
      );
    });
  });

  // --- DC-11 (#123): warm-fill-takes-ink in DARK (the load-bearing AC-2) ---
  // In dark, onPrimary / onError / onSecondary are ink #1A1510 on the warm
  // fills marigold #EAA24A / salmon #F2856B / terracotta #E07A55. White on any
  // of them is ~2.5:1 and MUST fail the gate (03-foundation-plan §1.2 / §1.3),
  // while the on* ink token clears its role threshold. This is the negative
  // case DC-11 locks alongside the white-on-marigold one above.
  group('DC-11 — warm-fill-takes-ink in dark (negative cases)', () {
    test('white on dark marigold FAILS; ink (onPrimary) clears AA', () {
      final white = contrastRatio(Colors.white, dark.primary);
      expect(white, lessThan(3.0));
      expect(white, closeTo(2.15, 0.1));
      expect(
        contrastRatio(dark.onPrimary, dark.primary),
        greaterThanOrEqualTo(4.5),
      );
      expect(dark.onPrimary, isNot(Colors.white));
    });

    test('white on dark danger salmon FAILS; ink (onError) clears AA', () {
      final white = contrastRatio(Colors.white, dark.error);
      expect(white, lessThan(3.0));
      expect(white, closeTo(2.52, 0.1));
      expect(
        contrastRatio(dark.onError, dark.error),
        greaterThanOrEqualTo(4.5),
      );
      expect(dark.onError, isNot(Colors.white));
    });

    test('white on dark terracotta FAILS; ink (onSecondary) passes UI', () {
      final white = contrastRatio(Colors.white, dark.secondary);
      expect(white, lessThan(3.0));
      expect(white, closeTo(2.96, 0.1));
      expect(
        contrastRatio(dark.onSecondary, dark.secondary),
        greaterThanOrEqualTo(3.0),
      );
      expect(dark.onSecondary, isNot(Colors.white));
    });
  });

  group('DC-11 — dark balance trio clears AA on the dark surface', () {
    // The hero balance signal renders the trio as a foreground on the dark
    // surface (net-balance card, balance pill, friend / expense detail).
    test('balancePositive / balanceNegative / balanceZero on dark surface', () {
      expect(
        contrastRatio(obtDark.balancePositive, dark.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrastRatio(obtDark.balanceNegative, dark.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrastRatio(obtDark.balanceZero, dark.surface),
        greaterThanOrEqualTo(4.5),
      );
    });
  });
}
