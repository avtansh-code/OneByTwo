# Feature PR Conventions

> Ratified after PR #4. Every feature PR from PR #6 onwards must follow these
> conventions. Cite this file at the top of the PR description:
> "Follows `docs/patterns/feature-pr-conventions.md` as ratified after PR #4."

---

## 1. File layout for a new feature

### Source

```
lib/features/<feature>/
  application/          # Controllers, state notifiers, service abstractions
  data/                 # Repositories, data sources, DTOs
  domain/               # Models, value objects, enums (if the feature needs them)
  presentation/
    screens/            # Full-page screen widgets (or directly in presentation/)
    widgets/            # Feature-specific reusable widgets
```

- Feature folders use `snake_case` matching the feature name (e.g., `auth`, `expenses`,
  `settle_up`).
- Files use `snake_case.dart`.
- Shared widgets that serve multiple features live in `lib/core/widgets/`.
- Shared validators live in `lib/core/validators.dart`.
- The app theme lives in `lib/app/theme.dart` and is consumed via
  `Theme.of(context)` — never bypassed with hardcoded colours.

### Tests

```
test/features/<feature>/
  <class_name>_test.dart
```

- Mirror the source structure but flatten intermediate directories.
  Example: `lib/features/auth/presentation/widgets/india_phone_input_formatter.dart`
  is tested by `test/features/auth/india_phone_input_formatter_test.dart`.
- Every test file imports only from `package:onebytwo/` (package imports) and
  `package:flutter_test/`.

### Smoke test

- `test/widget_test.dart` is the app-level smoke test. Update it whenever the
  initial route changes. It must always pass without Firebase initialisation.

---

## 2. State management

- **Framework:** Riverpod 2.x (ADR-0004, confirmed).
- **Provider location:** Providers live in the feature's `application/` folder.
- **Provider naming:** `<noun><role>Provider`.
  - `phoneEntryControllerProvider` (StateNotifierProvider).
  - `analyticsServiceProvider` (Provider).
  - `expenseListProvider` (FutureProvider / StreamProvider).
- **Provider types:**
  - `Provider` — static singletons, service abstractions.
  - `StateNotifierProvider` — mutable form state, screen controllers.
  - `AsyncNotifierProvider` — async-initialised state with loading/error.
  - `StreamProvider` — Firestore real-time listeners.
  - `FutureProvider` — one-shot async reads.
- **Scoping:** Use `ProviderScope.overrides` in tests to inject fakes. Production
  providers should not depend on `BuildContext`.
- **Code generation:** `riverpod_generator` and `riverpod_annotation` are available
  but optional. Manual provider declarations are acceptable.

---

## 3. Test discipline

### Test-first ordering

1. **Commit 1:** Write failing tests (red) for the new feature's validator, formatter,
   controller, and screen widget.
2. **Commits 2-N:** Implement code to make tests pass (green).
3. **Final commit(s):** Integration wiring, smoke test update.

### Three test layers

| Layer | Tool | Responsibility | Location |
|---|---|---|---|
| Unit | `flutter_test` | Pure logic: validators, formatters, controllers, models. | `test/features/<feature>/` |
| Widget | `flutter_test` | Screen rendering, interaction, state transitions, accessibility. | `test/features/<feature>/` |
| Integration | `integration_test` + Emulator Suite | End-to-end user journeys against Firebase emulators. | `integration_test/` |

### Minimum coverage shape for a feature

- Every public function in `application/` has a dedicated unit test file.
- Every screen in `presentation/` has a widget test covering:
  - Default render.
  - All interactive states (enabled, disabled, loading, error).
  - At least one negative case (invalid input, error state).
  - Telemetry event assertions (if the screen fires events).
  - Accessibility: semantic labels present.
- Overall project coverage >= 50%; non-UI code >= 70%.

### Cloud Functions Testing Layers

Use a five-layer test pyramid for Cloud Functions, mirroring the boundary split ratified in PR #12 (`FUNC-01`, simplified-debts):

| Layer | Purpose | File Location | Tool | Required? |
|---|---|---|---|---|
| Algorithm unit | Pure logic, no Firebase | `functions/test/<name>/algorithm.test.ts` | Jest | Yes |
| Algorithm property | Invariant verification with random inputs | `functions/test/<name>/algorithm.property.test.ts` | Jest + fast-check | Recommended for algorithmic functions |
| Function boundary | Handler with mocked Firestore | `functions/test/<name>/function.test.ts` | Jest + mocks | Yes |
| Security rules | Firestore/Storage rules against emulator | `functions/test/firestore-rules/`, `functions/test/storage-rules/` | Jest + `@firebase/rules-unit-testing` | Yes for any rule change |
| Integration | Full emulator suite end-to-end | `functions/test/integration/` | Jest + Firebase Emulators | Yes for callable/trigger functions |

Jest configs are separated by layer: `jest.config.js` (unit, parallel), `jest.rules.config.js` (rules, serial — `maxWorkers: 1` to avoid emulator race conditions), and `jest.integration.config.js` (integration).

### Field-Level Security Rules Pattern

When a Firestore rule must allow writes to some fields but deny writes to others (for example, allow `displayName` updates but block `simplifiedBalances` writes), use the `diff().affectedKeys()` pattern:

```rules
allow update: if
  !request.resource.data.diff(resource.data).affectedKeys().hasAny(['simplifiedBalances'])
  && <other conditions>;
```

This pattern is critical for Invariant 2 enforcement. Every collection with mixed user-authored and server-managed fields must use it in its `allow update` rule. Reference: ADR-0010, `firestore.rules` lines 117-123 and 163-170.

### Fake pattern

- Abstract service interfaces (e.g., `AnalyticsService`) with production
  implementations and `Fake*` test implementations.
- Override providers in `ProviderScope.overrides` in test `setUp`.
- Assert against the fake's recorded state (e.g., `fakeAnalytics.loggedEvents`).

---

## 4. Telemetry

- **Event name catalogue:** `docs/design/07-technical/telemetry-plan.md`.
- **Analytics provider location:** `lib/features/<feature>/application/analytics_provider.dart`
  (or a shared one in `lib/core/` if multiple features use it).
- **Parameter naming:** `snake_case`. No PII in any parameter.
- **New events:** Must be listed in the telemetry plan before implementation. If the
  event is not in the plan, propose it and get PM + architect approval.
- **Review:** Every PR that adds a telemetry event must note it in the PR description
  under the "Telemetry" section.

---

## 5. Accessibility

Every screen must meet these minimum requirements before a PR can be opened:

- **Semantic labels:** All interactive elements and informational containers have
  `Semantics` widgets with appropriate labels.
- **Headings:** Screen headings use `Semantics(header: true)`.
- **Live regions:** Error messages and status changes use
  `Semantics(liveRegion: true)` so screen readers announce them.
- **Focus order:** Logical top-to-bottom, left-to-right. Verify by tabbing through
  with a keyboard or using the accessibility inspector.
- **Dark mode:** Every screen renders correctly in both light and dark themes. Verify
  contrast ratios against WCAG 2.1 AA (4.5:1 for body text, 3:1 for large text).
- **Dynamic type:** Text scales correctly at 1.5x and 2x without clipping or overlap.
- **Tap targets:** All interactive elements have a minimum hit area of 48x48 dp.

Reference: `docs/design/07-technical/accessibility-spec.md` and SRS section 5.6.

---

## 6. PR shape

### Title

Conventional Commits format: `<type>(<scope>): <subject>`.

- `feat(auth): implement OTP entry screen (FR-AU-03)`
- `fix(expenses): correct split rounding for three-way split`
- Subject: imperative mood, lowercase, no trailing full stop, max 72 characters.

### Description sections (in order)

1. **Description** — what and why. Reference the user story file path.
2. **References** — links to story file, screen spec, wireframe.
3. **SRS Requirement(s)** — FR-XX-NN IDs covered.
4. **Type of Change** — checkbox.
5. **Invariant Checklist** — all four boxes ticked with explicit rationale ("Compliant
   by absence" or "Compliant: [explanation]"). Never silently skipped.
6. **Testing** — checkboxes for unit, widget, integration, negative cases, coverage.
7. **Quality** — format, analyse, lint, DartDoc, no secrets, Conventional Commits.
8. **Telemetry** — events added, PII check.
9. **Documentation** — story file updated, ADR if applicable.
10. **Files Added/Modified** — table grouped by purpose (implementation, tests, config).
11. **Manual Smoke Test** — bullet list of manual checks performed.
12. **"Next PR"** — one-line pointer to what comes next.

### Convention citation

The first line after the description heading must read:
> Follows `docs/patterns/feature-pr-conventions.md` as ratified after PR #4.

---

## 7. Commit rhythm

### Conventional Commit scopes

Map to feature folders:

| Scope | Folder / area |
|---|---|
| `auth` | `lib/features/auth/` |
| `expenses` | `lib/features/expenses/` |
| `groups` | `lib/features/groups/` |
| `friends` | `lib/features/friends/` |
| `settlements` | `lib/features/settlements/` |
| `profile` | `lib/features/profile/` |
| `activity` | `lib/features/activity/` |
| `core` | `lib/core/` |
| `ci` | `.github/workflows/` |
| `hooks` | `.github/hooks/` |
| `shared` | `.github/shared/` |

### Splitting commits

- **One commit per logical unit:** tests, implementation, wiring, CI fixes.
- **TDD rhythm:** red tests first, then green implementations.
- **Agent role splits (where reasonable):**
  - `test(auth): add red tests for OTP screen` (flutter-dev)
  - `feat(auth): implement OTP controller and screen` (flutter-dev)
  - `chore(ci): add emulator config for OTP integration test` (devops)
- **Never:** mix unrelated changes in a single commit. If a CI fix is needed during
  feature work, it gets its own commit with a `fix(ci):` or `chore(ci):` prefix.
- **Squash on merge:** PRs are squash-merged. The PR title (which must be Conventional
  Commits format) becomes the commit message on `main`. Individual branch commits
  provide an audit trail in the PR but do not appear on the main branch.
