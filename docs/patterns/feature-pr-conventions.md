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
- **Scoped `dependencies`:** A provider that `ref.watch`es a **scoped** provider
  (one that is overridden in a `ProviderScope`, such as `currentUserIdProvider`) must
  declare the **directly-watched** scoped provider in its own `dependencies` list —
  **not** a transitive root reached through it. For example, a provider that watches
  `friendsListProvider` declares `dependencies: [friendsListProvider]`, not the
  transitive `currentUserIdProvider`. Omitting the list, or naming the transitive root
  instead of the direct dependency, makes Riverpod throw the
  *"... specified a `dependencies` list ..."* assertion on first read. See
  `state-management.md` section 1.1 for the worked FR-HD / FR-FR example.
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

#### Jest config separation

Three Jest configs split the Cloud Functions suites by layer; pick the config (and
its npm script) that matches what you are testing. Each describes the actual files
in `functions/`:

| Config | npm script | Roots (test dirs) | Workers | Emulators | Use it for |
|---|---|---|---|---|---|
| `jest.config.js` (default) | `npm test` (and `npm run test:canonical` for `test/simplified-debts` only) | `src` + the per-function unit dirs under `test/` (e.g. `test/simplified-debts`, `test/triggers`, `test/notifications`, `test/delete-user-account`, ...); `*.integration.test.ts` is ignored | Parallel (default) | None | Pure algorithm and function-boundary unit tests with mocked Firestore. No emulator needed. |
| `jest.rules.config.js` | `npm run test:rules` | `test/firestore-rules`, `test/storage-rules` | `maxWorkers: 1` (serial) | Firestore (`8181`) + Storage (`9199`) | Security-rules tests against the emulators. Serial because all suites share one emulator and `clearFirestore()` in one suite can race seeds in another. Run inside `firebase emulators:exec`. |
| `jest.integration.config.js` | `npm run test:integration` | `test/integration` | Parallel (default) | Full suite — Auth (`9099`), Firestore (`8181`), Functions (`5001`), Storage (`9199`) | End-to-end callable / trigger journeys (`*.integration.test.ts`) against the running emulators. Run inside `firebase emulators:exec`. |

A new unit-test directory under `functions/test/` must be added to the `roots`
array of `jest.config.js`, or Jest reports "No tests found" for it. The emulator
ports above are the ones declared in `firebase.json`.

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

### Boundary-contract tests

State-transition tests verify that calling a method transitions the controller from
state X to state Y. They are necessary but not sufficient. A controller can perform
every state transition correctly while still passing the *wrong data* across an
architectural boundary — and every state-transition test will pass, because the
states themselves were fine.

**Boundary-contract tests** verify that the *arguments passed across a boundary* have
the correct format, shape, or structure. They are required whenever a function accepts
a loosely-typed parameter (`String`, `Map<String, dynamic>`, or similar) that carries
implicit structural constraints — for example, an E.164 phone number, a Firestore
document path, or a JSON payload with expected keys.

The OTP resend bug (PR #29) illustrates why this matters. All state-transition tests
passed, because the controller moved through the correct loading/success/error states.
The defect was that the controller passed raw digits (`'9876543210'`) to
`PhoneAuthRepository.resendOtp` instead of the E.164-formatted string
(`'+919876543210'`). No existing test inspected the argument at the boundary.

**The rule:** every controller-to-repository boundary and every repository-to-Firebase
SDK boundary must have at least one test that asserts the format or shape of the
arguments crossing that boundary. This applies wherever loosely-typed parameters carry
implicit structure. It does not apply to every function call — only to boundary
crossings with structural contracts.

**Worked example — auth controller to repository boundary:**

The `FakePhoneAuthRepository` in
`test/features/auth/otp_entry_controller_test.dart` must expose a
`lastResendPhoneNumber` field so tests can inspect the value passed at the boundary.
Add the field to the fake:

```dart
/// Last phone number passed to [resendOtp].
String? lastResendPhoneNumber;
```

Then record it inside the fake's `resendOtp` override:

```dart
@override
Future<void> resendOtp({
  required String phoneNumber,
  required void Function(VerificationSession session) onCodeSent,
  required void Function(AuthError error) onError,
  int? resendToken,
}) async {
  resendOtpCallCount++;
  lastResendPhoneNumber = phoneNumber; // <-- record the boundary argument
  if (resendOtpError != null) {
    onError(resendOtpError!);
    return;
  }
  if (resendOtpSession != null) {
    onCodeSent(resendOtpSession!);
  }
}
```

The boundary-contract test itself:

```dart
test('resend passes E.164-formatted phone number to repository', () async {
  // Arrange — 10-digit raw number as the controller receives it.
  final fakeRepo = FakePhoneAuthRepository();
  fakeRepo.resendOtpSession = VerificationSession(
    verificationId: 'new-vid',
    resendToken: 42,
  );
  final controller = OtpEntryController(
    phoneNumber: '9876543210',
    verificationId: 'initial-vid',
    repository: fakeRepo,
    analytics: FakeAnalyticsService(),
  );

  // Tick past the resend cooldown so canResend is true.
  await Future<void>.delayed(Duration.zero);
  controller.startResendTimer();
  // ... advance timer to enable resend ...

  // Act
  await controller.resend();

  // Assert — the repository must receive E.164 format, not raw digits.
  expect(fakeRepo.lastResendPhoneNumber, equals('+919876543210'));
  // This test would have FAILED before PR #29's fix, because the
  // controller was passing '9876543210' instead of '+919876543210'.

  controller.dispose();
});
```

This test does not check state transitions — other tests already cover those. It
checks that the *value crossing the boundary* conforms to the structural contract
(E.164 format). That is what makes it a boundary-contract test.

### Enforced coverage thresholds

The following coverage thresholds are enforced automatically. They are drawn from
SRS section 5.7 and DoD section 2.

| Scope | Threshold |
|---|---|
| Per-feature folder (`lib/features/<feature>/**`) | >= 70% |
| Per-module folder (`functions/src/<module>/**`) | >= 70% |
| Overall Flutter | >= 50% |
| Overall Cloud Functions | >= 50% |
| Simplified-debts module | 100% canonical test matrix coverage (validated by `npm run test:canonical`, not Istanbul branch metric) |

These thresholds are enforced at two points:

1. **lefthook pre-push (scoped gate).** Runs coverage only on feature folders
   touched by the push. Fails the push if any touched feature folder is below 70%.
   Skips gracefully for docs-only pushes. Escape hatch: `git push --no-verify`.

2. **GitHub Actions PR pipeline (authoritative gate).** The `coverage-gate` job
   runs after the test jobs complete. It checks ALL feature folders and overall
   thresholds. Any breach fails the PR check. `coverage-gate` is a required status
   check on `main` — PRs cannot merge until it passes.

Cross-references: SRS section 5.7, DoD section 2.

### Coverage quality note

Coverage as a number is gameable. Tests that execute code without asserting
meaningful behaviour add coverage percentage but not confidence in correctness.
The boundary-contract pattern described above is one defence against this: it
forces tests to inspect values at architectural boundaries, not merely trigger
code paths. The discipline is to write tests that actually constrain behaviour,
not just touch lines. Mutation testing is a more rigorous anti-gaming technique
but is not enforced for v1.0 due to its overhead and tooling weight. Reviewers
should assess whether tests in a PR are assertion-rich — verifying return values,
state fields, and boundary arguments — not merely line-covering.

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
6. **Testing** — checkboxes for unit, widget, integration, negative cases; and a
   **before/after coverage line for each touched feature/module** (see "Coverage
   tracking" below). Keep it lightweight — one line per touched scope, not a report.
7. **Quality** — format, analyse, lint, DartDoc, no secrets, Conventional Commits.
8. **Telemetry** — events added, PII check.
9. **Documentation** — story file updated, ADR if applicable.
10. **Files Added/Modified** — table grouped by purpose (implementation, tests, config).
11. **Manual Smoke Test** — bullet list of manual checks performed.
12. **"Next PR"** — one-line pointer to what comes next.

### Coverage tracking

Every PR that touches `lib/features/<feature>/**` or `functions/src/<module>/**`
records a **before/after line-coverage figure per touched feature/module** in the
Testing section. This keeps the SRS section 5.7 / DoD section 2 thresholds visible
at review time without a heavyweight report — one line per touched scope:

| Scope (touched feature / module) | Before | After |
|---|---|---|
| `lib/features/friends/**` | 78% | 81% |
| `functions/src/<module>/**` | 90% | 92% |

- One row per feature or module the PR actually touches — not the whole tree.
- Figures come from the same coverage run the gate uses (`flutter test --coverage`
  for Flutter, the Functions Istanbul report for Cloud Functions); a single overall
  percentage per scope is enough.
- A PR that touches no `lib/` / `functions/` code (pure docs, design, or CI) records
  "N/A — no `lib/` / `functions/` code touched." in place of the table.
- This is a description field, not a new gate: the authoritative enforcement remains
  the `coverage-gate` CI job and the lefthook pre-push scoped gate (see section 3,
  "Enforced coverage thresholds").

### Cloud Functions PR checklist

A PR that adds or changes a Cloud Function (`functions/src/**`) confirms these
Cloud-Functions-specific points in addition to the standard checklist:

- **Region pinning.** Every function is pinned to `asia-south1` (Mumbai) — the single
  deployment region — via the per-function `region` option (the
  `REGION = "asia-south1"` constant passed to each `onCall` / `onRequest` / trigger
  builder, as in `functions/src/**/index.ts`). No function is deployed to `us-central1`
  or left region-unset.
- **Error-code mapping.** Callable functions throw typed `HttpsError`s with the correct
  code (`unauthenticated`, `permission-denied`, `failed-precondition`,
  `invalid-argument`, ...); internal failures are not leaked as raw stack traces to the
  client.
- **Transaction usage.** Multi-document reads-then-writes that must stay consistent use
  a Firestore `runTransaction` (or a batched write where atomicity, not read
  consistency, is required) rather than independent `get` / `set` calls.
- **Idempotency.** Trigger handlers and callables tolerate redelivery and retries:
  re-running with the same input produces the same end state (no double-applied writes,
  no duplicate activity or notification emission).

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
