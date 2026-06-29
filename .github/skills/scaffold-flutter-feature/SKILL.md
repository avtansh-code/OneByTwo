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
4. **Screens** — list of screens this feature includes (from SRS section 6.3,
   the Designer's specs, or the matching Haldi handoff screens in
   `design_handoff_one_by_two/screens/*.dc.html` — the pixel-level reference).

## Procedure

1. Read `.github/shared/invariants.md`.
2. Read `.github/shared/coding-standards.md` for Dart conventions.
3. Read SRS section 13.1 for the project structure, and skim
   `lib/features/friends/README.md` as the layout and documentation
   gold standard.
4. Create the four-layer feature-first folder structure (this is what every
   shipped feature under `lib/features/` uses):
   ```
   lib/features/<feature_name>/
     README.md                              # short feature doc (see friends)
     application/
       <feature_name>_provider.dart         # StreamProvider / FutureProvider
       <x>_controller.dart                  # StateNotifier + matching state
       <x>_state.dart                       # immutable state class
       <x>_telemetry.dart                   # event / param name constants
     data/
       <feature_name>_repository.dart       # Firestore reads/writes
       <x>_service.dart                     # optional service wrappers
     domain/
       <x>_doc.dart                         # value type / DTO (strict parsing)
     presentation/
       <feature_name>_screen.dart
       widgets/
   ```
   Note: providers and controllers live under `application/` — there is no
   `providers/` folder. Not every feature needs all files (e.g., `reminders`
   has no `presentation/`).
5. Create the matching test structure. Tests are **flat** under
   `test/features/<feature_name>/`, named after what they exercise (not
   mirroring the lib sub-folders):
   ```
   test/features/<feature_name>/
     <x>_controller_test.dart
     <x>_state_test.dart
     <feature_name>_repository_test.dart
     <x>_doc_test.dart
     <feature_name>_screen_test.dart                 # widget test
     <feature_name>_boundary_contract_test.dart      # grep-based guardrail
     <feature_name>_pii_leak_test.dart               # telemetry PII guardrail
   ```
   Cross-feature or emulator-backed flows go under
   `test/integration/<feature_name>/`.
6. In each file, include:
   a. **Domain value type:** Dart class with strict `fromFirestore` / parsing
      and a `toCreateMap` (or `toFirestore`). All money fields are `int` with a
      `Paise` suffix. The project uses plain value types, not Freezed.
   b. **Repository:** class that wraps Firestore operations for this feature,
      exposed via a hand-written `Provider<...>`. Read `simplifiedBalances` but
      never write it (Invariant 2).
   c. **Providers/controllers (Riverpod 2.x, hand-written — no codegen):**
      - `StreamProvider` / `StreamProvider.family` for real-time listeners.
      - `FutureProvider.autoDispose.family` for one-shot reads.
      - A controller extending `StateNotifier<State>` exposed via
        `StateNotifierProvider.autoDispose(.family)` for form/mutable state.
      Do **not** use `@riverpod` codegen or `AsyncNotifier`; the only `Notifier`
      in the codebase is `NotificationPermissionController`.
   d. **Screen:** `ConsumerWidget` (or `ConsumerStatefulWidget`) with a
      `ref.watch` on the provider. Include a placeholder `build` returning a
      `Scaffold`. Match the matching Haldi handoff screen
      (`design_handoff_one_by_two/screens/*.dc.html`) for layout, copy, and
      placement; pull colours from `OBTColors` tokens, never hard-coded hex.
   e. **README.md:** follow the friends structure — short intro, implemented
      scope, layout tree, invariants honoured, hand-off boundaries.
   f. **Test stubs:** import the unit under test and add one passing placeholder
      test with `// TODO(qa): expand test coverage`.
7. All money display must use the shared formatter
   `formatInrFromPaise` from `lib/core/formatters/inr_formatter.dart`
   (it already exists — do not recreate it). Never format paise inline.
8. All sharing actions must use the system share sheet via `share_plus`
   (`ShareServiceBase` wrapper in `friends/data/share_service.dart` is the
   reference) — never import platform-specific share packages (Invariant 3).
9. Format and analyse with the fvm-pinned toolchain before handing off:
   `fvm flutter format .`, `fvm flutter analyze`, `fvm flutter test`.

## Output format

A list of created files with their full paths, each containing compilable Dart code
with DartDoc comments on all public APIs.

## Validation checks

- [ ] Folder structure matches the four-layer feature-first layout
      (`application/`, `data/`, `domain/`, `presentation/` + `presentation/widgets/`).
- [ ] A `README.md` is present for the feature (friends structure).
- [ ] All money fields are `int` with `Paise` suffix; display uses
      `formatInrFromPaise` from `lib/core/formatters/inr_formatter.dart`.
- [ ] No writes to `simplifiedBalances` in the repository.
- [ ] No platform-specific share package imports (system share sheet only).
- [ ] Riverpod 2.x providers are hand-written (`StreamProvider`,
      `FutureProvider`, `StateNotifierProvider`) — no `@riverpod` codegen,
      no `AsyncNotifier`, no `ChangeNotifier` or BLoC.
- [ ] Tests exist under `test/features/<feature_name>/` for every production
      file, including a `*_boundary_contract_test.dart` and, where telemetry is
      emitted, a `*_pii_leak_test.dart`.
- [ ] DartDoc comments on all public APIs.
- [ ] `fvm flutter format .`, `fvm flutter analyze`, and `fvm flutter test`
      are clean.

## Examples

### Positive example

**Input:** Feature name: `settlements`, SRS requirements: FR-SE-05, FR-SE-08.

**Output:** Files created:
- `lib/features/settlements/README.md`
- `lib/features/settlements/application/settle_up_controller.dart`
- `lib/features/settlements/application/settle_up_state.dart`
- `lib/features/settlements/application/settle_up_telemetry.dart`
- `lib/features/settlements/application/settlement_history_provider.dart`
- `lib/features/settlements/data/settlement_repository.dart`
- `lib/features/settlements/domain/settlement_doc.dart`
- `lib/features/settlements/domain/settle_up_draft.dart`
- `lib/features/settlements/presentation/settle_up_bottom_sheet.dart`
- `lib/features/settlements/presentation/widgets/settle_up_header.dart`
- `test/features/settlements/settle_up_controller_test.dart`
- `test/features/settlements/settlement_repository_test.dart`
- `test/features/settlements/settlement_doc_test.dart`
- `test/features/settlements/settle_up_bottom_sheet_widget_test.dart`
- `test/features/settlements/settle_up_boundary_contract_test.dart`
- `test/features/settlements/settle_up_pii_leak_test.dart`

The `settlement_doc.dart` contains `amountPaise: int` (not `amount: double`),
and `settleUpControllerProvider` is a
`StateNotifierProvider.autoDispose.family` (no codegen).

### Negative example (should refuse)

**Input:** "Scaffold a feature for UPI payment integration."

**Response:** Refused. UPI integration is listed in SRS section 12.3 as out of scope
for v1.0.
