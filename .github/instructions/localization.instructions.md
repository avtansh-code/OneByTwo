---
applyTo: "lib/**/l10n/**/*.arb,lib/l10n/**/*.arb"
---

# Localization File Instructions

- English (`app_en.arb`) is the source of truth — add keys here first
- Every key must have a `@key` metadata entry with `description`
- Use ICU message format for plurals: `{count, plural, =0{...} =1{...} other{...}}`
- All placeholders must have type declarations (`String`, `int`, `double`, `DateTime`)
- Hindi (`app_hi.arb`) must contain all keys from English — missing keys fall back to English
- Format amounts with ₹ symbol and Indian number grouping (1,00,000)
- Never translate the app name "One By Two" in marketing contexts
- After editing ARB files, run `flutter gen-l10n` to regenerate
- Do NOT manually edit files in `core/l10n/generated/` — they are auto-generated
