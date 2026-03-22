---
name: localization
description: "Guide for managing Flutter localization with ARB files, ICU message format, Indian number formatting, and Hindi/English translations."
---

# Localization Guide

## ARB File Structure

```text
lib/core/l10n/
├── app_en.arb          # English (source of truth)
├── app_hi.arb          # Hindi
└── l10n.yaml           # Configuration
```

English (`app_en.arb`) is always the **source of truth**. Every key must exist in `app_en.arb` first, then be translated in `app_hi.arb`.

---

## l10n.yaml Configuration

```yaml
arb-dir: lib/core/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
nullable-getter: false
```

---

## ARB Format & Conventions

### Basic Strings

```json
{
  "@@locale": "en",
  "appTitle": "One By Two",
  "@appTitle": { "description": "App name displayed in app bar" }
}
```

### Strings with Placeholders

```json
{
  "youOwe": "You owe {amount}",
  "@youOwe": {
    "description": "Text showing how much user owes",
    "placeholders": {
      "amount": { "type": "String", "example": "₹2,450" }
    }
  }
}
```

### Pluralization (ICU Format)

```json
{
  "expenseCount": "{count, plural, =0{No expenses} =1{1 expense} other{{count} expenses}}",
  "@expenseCount": {
    "description": "Number of expenses with pluralization",
    "placeholders": {
      "count": { "type": "int" }
    }
  }
}
```

### Select (Enum-like)

```json
{
  "splitType": "{type, select, equal{Split equally} exact{Exact amounts} percentage{By percentage} shares{By shares} itemized{Itemized} other{Unknown}}",
  "@splitType": {
    "description": "Split type label",
    "placeholders": {
      "type": { "type": "String" }
    }
  }
}
```

### Key Naming Conventions

- **camelCase** for all keys: `groupSettingsTitle`, `addExpenseButton`
- **Prefix by screen/feature** when keys are screen-specific: `groupDetailTitle`, `groupDetailEmptyState`
- **Generic keys** for reusable strings: `cancel`, `save`, `delete`, `retry`

---

## Indian Number Formatting

### Pattern

Indian numbering uses lakhs and crores, not millions:

| Western | Indian |
|---------|--------|
| 100,000 | 1,00,000 |
| 1,000,000 | 10,00,000 |
| 10,000,000 | 1,00,00,000 |

### Formatting in Code

```dart
// Use the project's AmountFormatter — never format manually
import 'package:one_by_two/core/utils/amount_formatter.dart';

// Full format: "₹1,00,000"
final display = AmountFormatter.formatAmount(10000000); // 10000000 paise = ₹1,00,000

// Compact: "₹1L", "₹1Cr"
final compact = AmountFormatter.formatCompact(10000000);
```

### Rules

- All monetary values stored as **int paise** (1 rupee = 100 paise).
- Format only at the **display layer** — never store formatted strings.
- Amount placeholders in ARB files are always `String` type (pre-formatted with ₹ symbol).
- Negative amounts display as "−₹500" (minus sign, not hyphen).

---

## Usage in Code

### Accessing Translations

```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// Direct access in widgets
Text(AppLocalizations.of(context).youOwe(formattedAmount))
```

### Context Extension (Preferred)

```dart
extension LocalizationExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

// Shorter usage
Text(context.l10n.youOwe(formattedAmount))
Text(context.l10n.expenseCount(expenses.length))
```

### In Non-Widget Code

Pass `AppLocalizations` explicitly when needed outside the widget tree:

```dart
String buildNotificationBody(AppLocalizations l10n, int amountPaise) {
  final formatted = AmountFormatter.formatAmount(amountPaise);
  return l10n.youOwe(formatted);
}
```

---

## After Editing ARB Files

```bash
# Generate localization code
flutter gen-l10n

# Verify no issues
flutter analyze
```

Always run these two commands after any ARB file change. CI will fail if generated code is out of sync.

---

## Translation Checklist

- [ ] All keys present in both `app_en.arb` and `app_hi.arb`
- [ ] Plurals use ICU format (`=0`, `=1`, `other`)
- [ ] Placeholders have type annotations
- [ ] Amount placeholders are `String` type (pre-formatted with ₹)
- [ ] Error messages are user-friendly, not technical
- [ ] Hindi translations reviewed for natural phrasing (not literal word-for-word)
- [ ] Run `flutter gen-l10n` after every edit
- [ ] Run `flutter analyze` to catch missing keys or type errors

---

## Common Patterns

### Error Messages

```json
{
  "errorGeneric": "Something went wrong. Please try again.",
  "errorNoInternet": "No internet connection. Your changes will sync when you're back online.",
  "errorExpenseNotFound": "This expense was deleted or doesn't exist anymore."
}
```

### Confirmation Dialogs

```json
{
  "deleteExpenseTitle": "Delete expense?",
  "deleteExpenseBody": "This will remove the expense for all members. This action cannot be undone.",
  "deleteConfirm": "Delete",
  "deleteCancel": "Cancel"
}
```

### Empty States

```json
{
  "emptyExpenses": "No expenses yet",
  "emptyExpensesHint": "Tap + to add your first expense",
  "emptyGroups": "No groups yet",
  "emptyGroupsHint": "Create a group to start splitting expenses"
}
```
