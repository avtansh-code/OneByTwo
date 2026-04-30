---
name: scaffold-flutter-feature
description: >
  Use when a new Flutter feature needs its folder structure, models, providers,
  screens, and test stubs created following the feature-first layout.
---

# Scaffold Flutter Feature

## When to use

When a new feature area (e.g., `auth`, `expenses`, `settlements`) needs its initial
folder structure, Dart model files, Riverpod providers, screen widgets, and test
stubs created under `lib/features/` and `test/`.

## When NOT to use

- When adding code to an existing feature that already has its scaffold.
- When the task is backend-only (route to Functions Dev).
- When the schema has not been designed yet (use `design-firestore-schema` first).

## Inputs

1. **Feature name** — snake_case name for the feature folder (e.g., `expenses`).
2. **SRS requirement IDs** — the functional requirements this feature covers.
3. **Schema** — the Firestore document structure from the Architect.
4. **Screens** — list of screens this feature includes (from SRS section 6.3 or
   the Designer's specs).

## Procedure

1. Read `.github/shared/invariants.md`.
2. Read `.github/shared/coding-standards.md` for Dart conventions.
3. Read SRS section 13.1 for the project structure.
4. Create the following folder structure:
   ```
   lib/features/<feature_name>/
     data/
       <feature_name>_repository.dart
     domain/
       <feature_name>_model.dart
     presentation/
       <feature_name>_screen.dart
       widgets/
     providers/
       <feature_name>_provider.dart
   ```
5. Create matching test structure:
   ```
   test/features/<feature_name>/
     data/
       <feature_name>_repository_test.dart
     domain/
       <feature_name>_model_test.dart
     presentation/
       <feature_name>_screen_test.dart
     providers/
       <feature_name>_provider_test.dart
   ```
6. In each file, include:
   a. **Model:** Dart class with `fromFirestore` and `toFirestore` methods. All
      money fields are `int` with `Paise` suffix. Include `copyWith`.
   b. **Repository:** class that wraps Firestore operations for this feature.
      Read `simplifiedBalances` but never write it.
   c. **Provider:** Riverpod provider(s) — use `AsyncNotifier` for mutable state,
      `StreamProvider` for real-time Firestore listeners.
   d. **Screen:** `ConsumerWidget` with a `ref.watch` on the provider. Include
      placeholder `build` method returning a `Scaffold`.
   e. **Test stubs:** import the class under test, create one passing placeholder
      test with `// TODO(qa): expand test coverage`.
7. All money display must use a shared formatter from `lib/core/money_formatter.dart`
   (create a stub if it does not exist).
8. All sharing actions must use the system share sheet — never import
   platform-specific share packages.

## Output format

A list of created files with their full paths, each containing compilable Dart code
with DartDoc comments on all public APIs.

## Validation checks

- [ ] Folder structure matches the feature-first layout.
- [ ] All money fields are `int` with `Paise` suffix.
- [ ] No writes to `simplifiedBalances` in the repository.
- [ ] No platform-specific share package imports.
- [ ] Riverpod providers are used (not raw `ChangeNotifier` or BLoC).
- [ ] Test stubs exist for every production file.
- [ ] DartDoc comments on all public APIs.
- [ ] Files are `dart format`-clean.

## Examples

### Positive example

**Input:** Feature name: `settlements`, SRS requirements: FR-SE-01 to FR-SE-08.

**Output:** Files created:
- `lib/features/settlements/data/settlements_repository.dart`
- `lib/features/settlements/domain/settlement_model.dart`
- `lib/features/settlements/presentation/settle_up_screen.dart`
- `lib/features/settlements/presentation/widgets/`
- `lib/features/settlements/providers/settlements_provider.dart`
- `test/features/settlements/data/settlements_repository_test.dart`
- `test/features/settlements/domain/settlement_model_test.dart`
- `test/features/settlements/presentation/settle_up_screen_test.dart`
- `test/features/settlements/providers/settlements_provider_test.dart`

The `settlement_model.dart` contains `amountPaise: int` (not `amount: double`).

### Negative example (should refuse)

**Input:** "Scaffold a feature for UPI payment integration."

**Response:** Refused. UPI integration is listed in SRS section 12.3 as out of scope
for v1.0.
