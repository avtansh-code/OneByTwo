---
applyTo: "lib/**/*.dart"
---

# Dart Code Instructions

- Follow Clean Architecture: domain layer has zero Flutter/Firebase imports
- Use `freezed` + `json_serializable` for immutable data models
- Use Riverpod `@riverpod` annotations with code generation
- All monetary amounts are integers in paise (1 ₹ = 100 paise) — never use `double` for money
- Wrap repository return values in `Result<T>` (Success/Failure)
- All user-facing strings must be in ARB files (never hardcoded)
- Prefer `const` constructors wherever possible
- Use named parameters for functions with more than 2 parameters
- Every syncable entity must have a `syncStatus` field
- Run `dart run build_runner build` after modifying `@freezed` or `@riverpod` annotated classes
- Use `AppLogger.instance` for all logging — never use `print()` or `debugPrint()` directly
- Define `static const _tag = 'Layer.Component'` in each class (e.g., `Repo.Expense`, `UC.AddExpense`)
- Log business events at `info`, state changes at `debug`, failures at `error` with error object and stack trace
- Always include entity IDs in log data maps — never include PII (phone, email, names, tokens)
