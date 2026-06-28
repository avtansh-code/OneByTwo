// OBTText helper tests (Sprint-3 retro — design-fidelity remediation).
//
// Pins the `rupeeAware` contract added by the Sprint-3 cleanup: amounts
// embedded in a Hanken text run must still render the rupee sign (U+20B9),
// which the bundled Hanken static instance lacks. The helper appends
// Bricolage Grotesque as a glyph fallback so only the missing sign borrows
// Bricolage while the surrounding prose keeps its primary family.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/core/theme/obt_text.dart';

void main() {
  group('OBTText.rupeeAware', () {
    test('returns null for a null style', () {
      expect(OBTText.rupeeAware(ThemeData.light(), null), isNull);
    });

    test('adds the amount family as a glyph fallback, prose preserved', () {
      final theme = ThemeData(
        textTheme: const TextTheme(
          titleSmall: TextStyle(fontFamily: 'Bricolage'),
        ),
      );
      const base = TextStyle(fontFamily: 'Hanken');

      final aware = OBTText.rupeeAware(theme, base)!;

      // The prose run stays Hanken; Bricolage is added only as a fallback.
      expect(aware.fontFamily, 'Hanken');
      expect(aware.fontFamilyFallback, contains('Bricolage'));
    });

    test('keeps any existing fallbacks and appends the amount family', () {
      final theme = ThemeData(
        textTheme: const TextTheme(
          titleSmall: TextStyle(fontFamily: 'Bricolage'),
        ),
      );
      const base = TextStyle(fontFamilyFallback: <String>['Existing']);

      final aware = OBTText.rupeeAware(theme, base)!;

      expect(
        aware.fontFamilyFallback,
        containsAll(<String>['Existing', 'Bricolage']),
      );
    });
  });
}
