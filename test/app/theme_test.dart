// DC-01 — theme token / type / radius foundation tests.
//
// Verifies the Haldi migration of `lib/app/theme.dart` against the
// constant-by-constant map in
// `docs/audits/design-conversion/03-foundation-plan.md` sections 1 to 3:
//   - the Haldi ColorScheme (marigold primary + ink onPrimary);
//   - the OBTColors theme extension (tokens, category hues, shadows);
//   - the named radius scale and CardTheme;
//   - the Bricolage / Hanken TextTheme and the OBTText amount helpers.
//
// No screen is converted and no OBT* widget is restyled here (DC-02).
//
// AppTheme builds its TextTheme via google_fonts, whose runtime font fetch
// must run inside a test zone. A leading `testWidgets` primes the theme and
// fonts and captures the resolved values; the pure-`test` assertions then
// read those captures without re-triggering a fetch.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/theme/obt_text.dart';

late ThemeData lightTheme;
late ThemeData darkTheme;
late TextTheme textTheme;
late String headingFamily;
late String bodyFamily;

void main() {
  testWidgets('prime: AppTheme builds with the Haldi fonts', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const SizedBox.shrink()),
    );
    lightTheme = AppTheme.light;
    darkTheme = AppTheme.dark;
    textTheme = lightTheme.textTheme;
    headingFamily = GoogleFonts.bricolageGrotesque().fontFamily!;
    bodyFamily = GoogleFonts.hankenGrotesk().fontFamily!;
  });

  group('ColorScheme — light (AC #1)', () {
    test('primary is marigold and onPrimary is ink, never white', () {
      final scheme = lightTheme.colorScheme;
      expect(scheme.primary, const Color(0xFFE0922E));
      expect(scheme.onPrimary, const Color(0xFF2A211B));
      expect(scheme.onPrimary, isNot(Colors.white));
    });

    test('secondary / tertiary / error semantic colours', () {
      final scheme = lightTheme.colorScheme;
      expect(scheme.secondary, const Color(0xFFC75D3C));
      expect(scheme.onSecondary, const Color(0xFFFFF7E8));
      expect(scheme.tertiary, const Color(0xFF0F7D6B));
      expect(scheme.onTertiary, const Color(0xFFFFFFFF));
      expect(scheme.error, const Color(0xFFBC4030));
      expect(scheme.onError, const Color(0xFFFFFFFF));
    });

    test('surfaces, text and outline', () {
      final scheme = lightTheme.colorScheme;
      expect(scheme.surface, const Color(0xFFFFFFFF));
      expect(scheme.onSurface, const Color(0xFF2A211B));
      expect(scheme.surfaceContainerHighest, const Color(0xFFFFF6E6));
      expect(scheme.onSurfaceVariant, const Color(0xFF6F6557));
      expect(scheme.outline, const Color(0xFFE7DDCD));
      expect(scheme.primaryContainer, const Color(0xFFC77F22));
    });

    test('scaffold background and divider', () {
      expect(lightTheme.scaffoldBackgroundColor, const Color(0xFFFBF6EE));
      expect(lightTheme.dividerColor, const Color(0xFFE7DDCD));
    });
  });

  group('ColorScheme — dark (AC #1)', () {
    test('primary is marigold-dark and onPrimary is ink, never white', () {
      final scheme = darkTheme.colorScheme;
      expect(scheme.primary, const Color(0xFFEAA24A));
      expect(scheme.onPrimary, const Color(0xFF1A1510));
      expect(scheme.onPrimary, isNot(Colors.white));
    });

    test('light/warm fills take ink foregrounds (section 1.3)', () {
      final scheme = darkTheme.colorScheme;
      // Dark danger is a light salmon; white would be ~2.5:1, so ink.
      expect(scheme.error, const Color(0xFFF2856B));
      expect(scheme.onError, const Color(0xFF1A1510));
      expect(scheme.onSecondary, const Color(0xFF1A1510));
      expect(scheme.onTertiary, const Color(0xFF1A1510));
    });

    test('surfaces, text and outline', () {
      final scheme = darkTheme.colorScheme;
      expect(scheme.surface, const Color(0xFF241D16));
      expect(scheme.onSurface, const Color(0xFFF3EBDD));
      expect(scheme.surfaceContainerHighest, const Color(0xFF2E2620));
      expect(scheme.onSurfaceVariant, const Color(0xFFB9AE9D));
      expect(scheme.outline, const Color(0xFF3A322A));
      expect(darkTheme.scaffoldBackgroundColor, const Color(0xFF1A1510));
    });
  });

  group('OBTColors extension (AC #2)', () {
    test('light tokens resolve to the documented hex', () {
      final c = lightTheme.extension<OBTColors>();
      expect(c, isNotNull);
      expect(c!.balanceZero, const Color(0xFF6F6557));
      expect(c.balancePositive, const Color(0xFF0F7D6B));
      expect(c.balanceNegative, const Color(0xFFBC4030));
      expect(c.warning, const Color(0xFFE8A33D));
      expect(c.primaryPressed, const Color(0xFFC77F22));
      expect(c.textTertiary, const Color(0xFF776E64));
      expect(c.link, const Color(0xFFA35E16));
      expect(c.disabledFill, const Color(0xFFE4DCCE));
      expect(c.disabledText, const Color(0xFFB8AC9B));
    });

    test('dark tokens resolve to the documented hex', () {
      final c = darkTheme.extension<OBTColors>()!;
      expect(c.balanceZero, const Color(0xFFA99C8C));
      expect(c.balancePositive, const Color(0xFF34C0A4));
      expect(c.balanceNegative, const Color(0xFFF2856B));
      expect(c.warning, const Color(0xFFF2B863));
      expect(c.primaryPressed, const Color(0xFFD08F3C));
      expect(c.textTertiary, const Color(0xFF9C8E7C));
      expect(c.link, const Color(0xFFEAA24A));
    });

    test('the 8-hue category palette (light + dark)', () {
      final l = lightTheme.extension<OBTColors>()!;
      expect(l.categoryColor(OBTCategory.food), const Color(0xFFE8762B));
      expect(l.categoryColor(OBTCategory.transport), const Color(0xFF2E78C9));
      expect(l.categoryColor(OBTCategory.groceries), const Color(0xFF4FA13E));
      expect(
        l.categoryColor(OBTCategory.entertainment),
        const Color(0xFFB5489B),
      );
      expect(l.categoryColor(OBTCategory.rent), const Color(0xFF6C4FC9));
      expect(l.categoryColor(OBTCategory.utilities), const Color(0xFF1FA39A));
      expect(l.categoryColor(OBTCategory.shopping), const Color(0xFFD94F87));
      expect(l.categoryColor(OBTCategory.other), const Color(0xFF8A7B6B));

      final d = darkTheme.extension<OBTColors>()!;
      expect(d.categoryColor(OBTCategory.food), const Color(0xFFF59A52));
      expect(d.categoryColor(OBTCategory.other), const Color(0xFFA99986));
      expect(d.category.length, OBTCategory.values.length);
    });

    test('soft-warm shadow model: light row shadow, dark uses border', () {
      final l = lightTheme.extension<OBTColors>()!;
      final d = darkTheme.extension<OBTColors>()!;
      expect(l.rowShadow, isNotEmpty);
      expect(l.heroShadow, isNotEmpty);
      // Dark rows use a 1px outline border, not a shadow (section 2.2).
      expect(d.rowShadow, isEmpty);
      expect(d.heroShadow, isNotEmpty);
    });

    test('lerp blends between light and dark token sets', () {
      final l = lightTheme.extension<OBTColors>()!;
      final d = darkTheme.extension<OBTColors>()!;
      final mid = l.lerp(d, 0.5);
      expect(mid.balanceZero, Color.lerp(l.balanceZero, d.balanceZero, 0.5));
      expect(mid.category.length, OBTCategory.values.length);
    });

    test('copyWith overrides only the given fields', () {
      final c = lightTheme.extension<OBTColors>()!;
      final copy = c.copyWith(warning: const Color(0xFF010203));
      expect(copy.warning, const Color(0xFF010203));
      expect(copy.balanceZero, c.balanceZero);
      expect(copy.balancePositive, c.balancePositive);
      expect(copy.balanceNegative, c.balanceNegative);
      expect(copy.primaryPressed, c.primaryPressed);
      expect(copy.textTertiary, c.textTertiary);
      expect(copy.link, c.link);
      expect(copy.disabledFill, c.disabledFill);
      expect(copy.disabledText, c.disabledText);
      expect(copy.category, c.category);
      expect(copy.rowShadow, c.rowShadow);
      expect(copy.heroShadow, c.heroShadow);
    });

    test('lerp returns this when other is not OBTColors', () {
      final c = lightTheme.extension<OBTColors>()!;
      expect(c.lerp(null, 0.5), same(c));
    });
  });

  group('Radius scale + CardTheme (AC #2, section 2.1)', () {
    test('named radius tokens have the Haldi values', () {
      expect(AppTheme.radiusChipInput, 12.0);
      expect(AppTheme.radiusButton, 16.0);
      expect(AppTheme.radiusCard, 20.0);
      expect(AppTheme.radiusPill, 18.0);
      expect(AppTheme.radiusSheet, 28.0);
      expect(AppTheme.radiusFull, 999.0);
    });

    test('CardTheme uses radiusCard and is flat (elevation 0)', () {
      for (final theme in <ThemeData>[lightTheme, darkTheme]) {
        final card = theme.cardTheme;
        expect(card.elevation, 0);
        final shape = card.shape! as RoundedRectangleBorder;
        expect(shape.borderRadius, BorderRadius.circular(AppTheme.radiusCard));
      }
    });
  });

  group('Page transitions (AC #2 motion, section 2.3)', () {
    test('Haldi page transition installed on both themes', () {
      for (final theme in <ThemeData>[lightTheme, darkTheme]) {
        final builders = theme.pageTransitionsTheme.builders;
        expect(
          builders.keys,
          containsAll(<TargetPlatform>[
            TargetPlatform.android,
            TargetPlatform.iOS,
          ]),
        );
        expect(
          builders[TargetPlatform.android]!.transitionDuration,
          AppTheme.motionDurationMedium,
        );
      }
    });
  });

  group('Typography — Bricolage + Hanken (AC #1, section 3.3)', () {
    test('display + headline slots are Bricolage', () {
      expect(textTheme.displayLarge!.fontFamily, headingFamily);
      expect(textTheme.displayMedium!.fontFamily, headingFamily);
      expect(textTheme.headlineLarge!.fontFamily, headingFamily);
      expect(textTheme.headlineMedium!.fontFamily, headingFamily);
    });

    test('row names and body / labels are Hanken', () {
      expect(textTheme.titleLarge!.fontFamily, bodyFamily);
      expect(textTheme.titleMedium!.fontFamily, bodyFamily);
      expect(textTheme.bodyLarge!.fontFamily, bodyFamily);
      expect(textTheme.bodyMedium!.fontFamily, bodyFamily);
      expect(textTheme.labelLarge!.fontFamily, bodyFamily);
    });

    test('amount slots are Bricolage with tabular figures', () {
      expect(textTheme.displayLarge!.fontFamily, headingFamily);
      expect(
        textTheme.displayLarge!.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      // titleSmall is the amount-row slot.
      expect(textTheme.titleSmall!.fontFamily, headingFamily);
      expect(
        textTheme.titleSmall!.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });
  });

  group('OBTText amount helpers (AC #4)', () {
    testWidgets('amount + amountHero are Bricolage tabular styles', (
      tester,
    ) async {
      late TextStyle amount;
      late TextStyle amountHero;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) {
              amount = OBTText.amount(context);
              amountHero = OBTText.amountHero(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final heading = GoogleFonts.bricolageGrotesque().fontFamily;
      expect(amount.fontFamily, heading);
      expect(amount.fontFeatures, contains(const FontFeature.tabularFigures()));
      expect(amountHero.fontFamily, heading);
      expect(
        amountHero.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });
  });
}
