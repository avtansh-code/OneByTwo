---
name: localization
description: Guide for managing localization (i18n/l10n) in the One By Two app. Use this when adding, updating, or fixing translated strings, ARB files, plural rules, and locale-specific formatting.
---

## Localization Setup

The app uses Flutter's built-in `flutter_localizations` with ARB (Application Resource Bundle) files.

**Supported locales (P0):** English (en), Hindi (hi)

## File Structure

```
lib/
├── l10n/
│   ├── app_en.arb          # English strings (source of truth)
│   ├── app_hi.arb          # Hindi translations
│   └── l10n.yaml           # Generation config
├── core/
│   └── l10n/
│       └── generated/      # Auto-generated (do not edit)
│           ├── app_localizations.dart
│           ├── app_localizations_en.dart
│           └── app_localizations_hi.dart
```

## ARB File Format

### English (source of truth)

```json
{
  "@@locale": "en",
  "appTitle": "One By Two",
  "@appTitle": {
    "description": "App name shown in app bar"
  },
  "youOwe": "You owe {name}",
  "@youOwe": {
    "description": "Balance text when current user owes money",
    "placeholders": {
      "name": { "type": "String", "example": "Rahul" }
    }
  },
  "amountInRupees": "₹{amount}",
  "@amountInRupees": {
    "placeholders": {
      "amount": { "type": "String", "example": "150.50" }
    }
  },
  "expenseCount": "{count, plural, =0{No expenses} =1{1 expense} other{{count} expenses}}",
  "@expenseCount": {
    "description": "Number of expenses in a group",
    "placeholders": {
      "count": { "type": "int" }
    }
  },
  "memberCount": "{count, plural, =1{1 member} other{{count} members}}",
  "@memberCount": {
    "placeholders": {
      "count": { "type": "int" }
    }
  }
}
```

### Hindi

```json
{
  "@@locale": "hi",
  "appTitle": "वन बाय टू",
  "youOwe": "आप {name} को देते हैं",
  "amountInRupees": "₹{amount}",
  "expenseCount": "{count, plural, =0{कोई खर्च नहीं} =1{1 खर्च} other{{count} खर्चे}}",
  "memberCount": "{count, plural, =1{1 सदस्य} other{{count} सदस्य}}"
}
```

## Usage in Code

```dart
// Access localized strings
final l10n = AppLocalizations.of(context)!;
Text(l10n.appTitle);
Text(l10n.youOwe('Rahul'));
Text(l10n.expenseCount(5));
Text(l10n.amountInRupees('150.50'));
```

## Adding New Strings

1. **Add to `app_en.arb`** (English is always the source of truth)
2. **Add metadata** with `@key` for description and placeholders
3. **Add to `app_hi.arb`** with Hindi translation
4. **Run code generation:**
   ```bash
   flutter gen-l10n
   ```
5. **Use in code** via `AppLocalizations.of(context)!.newKey`

## Rules

1. **Never hardcode user-facing strings** — always use ARB files
2. **English ARB is the source** — Hindi follows; missing Hindi keys fall back to English
3. **Use ICU message format** for plurals, selects, and gender
4. **Placeholders must be typed** (`String`, `int`, `double`, `DateTime`)
5. **Amount formatting:** Always format with `₹` symbol and 2 decimal places
6. **Date formatting:** Use `DateFormat` from `intl` package, locale-aware
7. **Number formatting:** Use `NumberFormat` from `intl` package for comma separators (Indian: 1,00,000)
8. **Do NOT translate:**
   - App name in marketing contexts ("One By Two")
   - Currency symbol (₹)
   - Technical identifiers

## Indian Number Formatting

India uses a unique grouping: `1,00,000` (not `100,000`).

```dart
import 'package:intl/intl.dart';

String formatIndianAmount(int paise) {
  final rupees = paise / 100;
  final formatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );
  return formatter.format(rupees);
}
// 1000000 paise → "₹10,000.00"
// 10000050 paise → "₹1,00,000.50"
```

## l10n.yaml Configuration

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-dir: lib/core/l10n/generated
synthetic-package: false
nullable-getter: false
```

## Testing Localized Strings

```dart
testWidgets('displays Hindi text when locale is hi', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('hi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const HomeScreen(),
    ),
  );

  expect(find.text('वन बाय टू'), findsOneWidget);
});
```

## Reference

- Requirements: `docs/REQUIREMENTS.md` (Section 7 — English + Hindi P0)
- Architecture: `docs/architecture/01_ARCHITECTURE_OVERVIEW.md` (i18n section)
