---
applyTo: "lib/**/l10n/**/*.arb"
---

# Localization ARB File Instructions

## Source of Truth

`app_en.arb` (English) is the primary. `app_hi.arb` (Hindi) must have matching keys.

## Format

```json
{
  "@@locale": "en",
  "keyName": "User-visible text with {placeholder}",
  "@keyName": {
    "description": "Context for translators",
    "placeholders": {
      "placeholder": { "type": "String", "example": "example value" }
    }
  }
}
```

## Rules

- Key names: lowerCamelCase (`expenseAdded`, not `expense_added`)
- Every key has a `@key` metadata entry with `description`
- Placeholders have `type` and `example`
- Amount placeholders are `String` type (pre-formatted with ₹ and Indian number format)
- Use ICU message format for plurals: `{count, plural, =0{none} =1{one} other{{count} items}}`
- Use ICU select for enums: `{type, select, equal{Equally} exact{Exact} other{Unknown}}`
- No HTML tags in strings
- No hardcoded numbers — use placeholders

## Indian-Specific

- Currency: Always ₹ prefix (handled by AmountFormatter, not in ARB)
- Number format: 1,00,000 (lakhs, crores — handled by AmountFormatter)
- Hindi translations should be natural, not literal translations

## After Editing

```bash
flutter gen-l10n
flutter analyze
```
