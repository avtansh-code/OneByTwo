---
name: review-pull-request
description: >
  Use when a pull request needs a deep review for correctness, invariant
  compliance, architecture and data-model conformance, Riverpod state
  management, accessibility, telemetry and privacy, security, performance, test
  coverage, and coding-standards adherence.
---

# Review Pull Request

## When to use

When a pull request is ready for review. This skill guides a deep, systematic
review against the project's invariants, architecture and data model, Riverpod
state management, UI/async handling, accessibility, telemetry and privacy, Cloud
Functions contracts, security, performance budgets, coding standards, CI gates,
and real test surfaces.

## When NOT to use

- When the PR is a draft and the author has not requested review.
- When the review is purely about visual design (route to Designer).

## Inputs

1. **Pull request** — the PR number or diff.
2. **Related user story** — the GitHub Issue with acceptance criteria.
3. **PR template sections** — Description, SRS Requirements, Type of Change,
   Invariant Checklist, Testing, Quality, Telemetry, Documentation, and
   Screenshots/Recordings from `.github/PULL_REQUEST_TEMPLATE.md`.
4. **Design and contract references** — for a PR that changes schema, contracts,
   or a screen: the Haldi design handoff (`design_handoff_one_by_two/screens/*.dc.html`,
   the pixel-level source of truth; pointer `.github/shared/design-pointer.md`), the
   screen spec / wireframe, the relevant ADR(s) in
   `.github/shared/decision-log.md` (latest ADR-0020), the Firestore schema
   (`docs/design/07-technical/firestore-schema.md`), the extension points
   (`docs/design/03-architecture/extension-points.md`), the telemetry plan
   (`docs/design/07-technical/telemetry-plan.md`), and the accessibility spec
   (`docs/design/07-technical/accessibility-spec.md`).

## Procedure

1. Read `.github/shared/invariants.md`, `.github/shared/coding-standards.md`,
   `.github/shared/test-strategy.md`, `docs/patterns/feature-pr-conventions.md`,
   and `.github/shared/milestone-tracking.md`. For a PR that touches schema,
   contracts, or a screen, also read the relevant ADR(s) in
   `.github/shared/decision-log.md`,
   `docs/design/03-architecture/extension-points.md`, the telemetry plan, and the
   accessibility spec.
2. Review the PR diff systematically. Tag every finding by severity —
   **[Blocking]** (invariant, security, or correctness failure), **[Major]**
   (design/contract violation or missing tests), **[Minor]** (style, naming,
   docs) — and cite a `path:line`. Work through the dimensions below; skip a
   dimension only when the diff does not touch it.

   **Invariants (blocking — `.github/shared/invariants.md`):**
   - **Integer paise:** flag `double`/`float` money, monetary fields without a
     `Paise` suffix, and paise-to-rupee conversion outside the UI. Money is
     rendered only via `formatInrFromPaise`
     (`lib/core/formatters/inr_formatter.dart`) — no inline `/100` or hand-rolled
     rupee strings. Confirm a boundary-contract test for touched paths
     (`test/features/<name>/*_boundary_contract_test.dart` or
     `functions/test/boundary-contracts/no-double-on-money-fields.test.ts`).
   - **`simplifiedBalances` write restriction:** scan `lib/**` `set()` / `update()`
     / batch writes for `simplifiedBalances`. Client writes are blocking; reads and
     named arguments for display are fine. The server writers are
     `recomputeSimplifiedBalances`, `onExpenseWriteFriendship`, `onSettlementWrite`
     (the algorithm result is written only by `recomputeAndWrite` in
     `functions/src/simplified-debts/function.ts`).
   - **System share sheet only:** flag any import or deep link targeting WhatsApp,
     Telegram, or a specific messaging app. `share_plus` (system sheet) is allowed.
   - **Single Firebase project:** flag extra project IDs in `.firebaserc`,
     `firebase.json`, app config, or workflows (CI also guards `.firebaserc`).

   **Architecture & data model (ADR-0020 is the latest; schema + extension-points docs):**
   - Feature-first layout: a new feature has `data/`, `application/`,
     `presentation/`; providers live in `application/`.
   - Schema changes match the schema doc; every new field is typed and documented;
     a new query shape has a matching composite index in `firestore.indexes.json`.
   - Extension-point obligations are met: settlement documents carry
     `method: 'manual'` (ARCH-EXT-01), `currency: 'INR'` (ARCH-EXT-02), and
     `verificationStatus: 'unverified'` (ARCH-EXT-06), with `verificationStatus`
     client-read-only in the rules (mirroring `simplifiedBalances`).
   - A genuinely new architectural decision has an ADR; the PR must not silently
     contradict an existing ADR.
   - Security-rule changes (`firestore.rules` / `storage.rules`) ship with rules
     tests; creator-only edit/soft-delete and server-read-only projections are
     enforced in the rules, not only in the client UI.

   **State management (Riverpod 2.x — ADR-0004):**
   - Providers live in the feature `application/` folder, named
     `<noun><role>Provider`; the type fits the use (`StreamProvider` for Firestore
     listeners, `AsyncNotifierProvider` for async state with loading/error,
     `StateNotifierProvider` for form/screen state, `Provider` for services).
   - A provider that `ref.watch`es a *scoped* provider declares the correct
     `dependencies` list — the directly-watched scoped provider, not a transitive
     root — or Riverpod throws a "specified a dependencies list" assert on first read.
   - No `BuildContext` in providers; fakes are injected via
     `ProviderScope.overrides` in tests; `StreamSubscription`s are disposed (prefer
     `autoDispose` / `ref.onDispose`).

   **UI, async state & formatting:**
   - A new or changed screen/component matches its Haldi handoff reference
     (`design_handoff_one_by_two/screens/*.dc.html`) exactly — layout, copy,
     components, and placement, not just colour/type tokens. Hard-coded `Color(0x…)`
     literals on converted surfaces are a finding (boundary-contract grep tests);
     colours flow from `OBTColors` tokens, money from `formatInrFromPaise`.
   - Every `AsyncValue` surface handles loading / data / empty / error (e.g. via
     `.when(...)`); no unguarded `.value!` or ignored error branch.
   - Error and offline states show user-facing messaging, not a silent failure.
   - Dates render via `DateFormat('dd MMM yyyy')` with **no** locale argument (IST;
     the app never calls `initializeDateFormatting`).

   **Accessibility (SRS section 5.6; `docs/design/07-technical/accessibility-spec.md`):**
   - Semantic labels on interactive/informational elements; headings use
     `Semantics(header: true)`; errors/status use `Semantics(liveRegion: true)`.
   - Dark mode renders correctly; contrast meets WCAG 2.1 AA (4.5:1 body, 3:1
     large); text scales at 1.5x/2x without clipping; tap targets >= 48x48 dp.
   - A widget test asserts the key semantic labels.

   **Telemetry & privacy (`docs/design/07-technical/telemetry-plan.md`):**
   - New events are listed in the telemetry plan before use; parameters are
     `snake_case`; the PR description's Telemetry section notes them.
   - Monetary amounts in telemetry are bucketed to `amount_range`; raw
     `amount_paise` must never appear in an analytics event (telemetry-plan §2.1).
   - **No PII** in any analytics / Crashlytics parameter. A deterministic
     UID-composite identifier (e.g. `friendshipId`) is hashed via `hashFriendshipId`
     (`lib/core/telemetry/event_id_hash.dart`), never sent raw. Phone numbers never
     appear in telemetry, even hashed — a full hash of a 10-digit number is
     reversible; the only PII-safe identifier is a truncated UID-composite via
     `hashFriendshipId`.

   **Cloud Functions depth (`functions/src/**`):**
   - **Region:** every function is pinned to `asia-south1` via the per-function
     `REGION` constant — none region-unset or on `us-central1`.
   - **Errors:** callables throw typed `HttpsError`s with the right code
     (`unauthenticated`, `permission-denied`, `failed-precondition`,
     `invalid-argument`, ...); raw stack traces are not leaked to the client.
   - **Atomicity:** a multi-document read-then-write that must stay consistent uses
     `runTransaction` (as in `simplified-debts/function.ts`), or a batched write
     where only atomicity is required.
   - **Idempotency:** triggers and callables tolerate redelivery / retries — the
     same input yields the same end state, with no double-applied writes and no
     duplicate activity or notification emission.
   - The simplified-debts algorithm stays a pure, side-effect-free function.

   **Security & auth:**
   - Callables validate input and authorise the caller (`unauthenticated` /
     `permission-denied`) before acting; ownership is never trusted from the client.
   - Phone auth is +91 only; any `verifyPhoneNumber` wrapper resolves its loading
     state inside `verificationCompleted` (Android instant verification fires it
     without `codeSent`).
   - No secrets in source (use GitHub Actions secrets / Remote Config); Storage
     rules constrain receipt / avatar size and content-type.

   **Performance & data access (SRS section 5):**
   - Watch for N+1 / fan-out read patterns (one `get()` per friendship); prefer a
     denormalised rollup or a batched read, and file a follow-up if deferred.
   - New queries have the supporting composite index; unbounded lists are capped
     (e.g. a 50-item `StreamProvider.family`).
   - No heavy synchronous work on the UI isolate that risks the cold-start (< 3 s)
     or transition (< 300 ms) NFR targets.

   **Coding standards & docs (`.github/shared/coding-standards.md`):**
   - British English; no emojis; Dart <= 80 cols; `very_good_analysis` clean; no
     `// ignore` without a code-review-approved justification.
   - DartDoc on public APIs; JSDoc on exported functions and CF entry points
     (trigger type, input, output, error conditions).
   - Imports sorted dart / package / relative (relative within a feature,
     `package:` across); no `TODO` without an issue number or role tag.

   **CI and quality gates:**
   - Expected gates: `dart format --set-exit-if-changed .`,
     `flutter analyze --fatal-infos`, `flutter test --coverage`, `npm run lint`,
     `npm test`, the rules/integration emulator jobs, per-feature/module coverage
     >= 70%, overall >= 50%, the `.firebaserc` single-project guard, and the
     Conventional-Commits PR-title lint.
   - The PR description carries every section in order (the convention-citation
     line, the Invariant Checklist with explicit rationale, the before/after
     coverage line per touched scope, and the Cloud Functions checklist when
     `functions/src/**` is touched).

   **Tests:**
   - New code has tests in real locations (`test/**`, `functions/test/**`,
     `functions/test/{firestore-rules,storage-rules}/**`,
     `functions/test/integration/*.integration.test.ts`).
   - At least one negative case covers invalid input, a denied rule, an error UI, or
     a trigger-failure path.
   - A simplified-debts change has canonical, property, settlement-folding,
     reserved-key, and emulator-integration coverage.
   - Critical-journey reachability: a new screen/provider is reachable from a
     navigation entry point (no orphaned widget or never-overridden provider), and
     the journey is covered by an executable end-to-end test — not only isolated
     widget tests.

   **Acceptance criteria:**
   - Each acceptance criterion from the user story maps to a test or is demonstrably
     covered.

   **Milestone reconciliation (on merge — `.github/shared/milestone-tracking.md`):**
   - Every issue the PR closes (`Closes #NN`) carries the correct sprint milestone
     before merge; an unmilestoned closed issue is a tracking defect.
   - A re-scoped remainder (a partial close) is re-homed to the milestone matching
     its new target sprint, with a comment.
   - If the PR closes the last open issue in a sprint milestone, that milestone is
     closed and the next sprint's milestone is open and populated.

3. Summarise findings grouped by severity — Blocking Issues, Major,
   Recommendations, and Approved Items — each with a `path:line` citation and the
   invariant, ADR, convention, or SRS reference it relates to.

## Output format

A structured review comment with sections: **Blocking Issues** (invariant,
security, or correctness failures that must be fixed before merge), **Major**
(design, contract, or missing-test issues), **Recommendations** (minor / style),
and **Approved Items**. Every finding cites a `path:line` and references the
invariant, ADR, convention, or SRS section it relates to.

## Validation checks

- [ ] All four invariants checked against the diff.
- [ ] Architecture/data-model conformance checked: schema doc, indexes for new
      queries, extension-point fields (`method` / `currency` / `verificationStatus`),
      and an ADR for any new decision.
- [ ] State management reviewed: provider location/type, scoped-provider
      `dependencies` lists, no `BuildContext` in providers.
- [ ] UI async states (loading/data/empty/error), `formatInrFromPaise` for money,
      and locale-free `DateFormat` checked.
- [ ] Screen/component fidelity checked against the Haldi handoff
      (`design_handoff_one_by_two/screens/*.dc.html`): layout, copy, components,
      and placement match; no hard-coded hex on converted surfaces.
- [ ] Accessibility reviewed: semantic labels, live regions, dark mode, dynamic
      type, 48 dp tap targets.
- [ ] Telemetry events are in the plan, `snake_case`, and PII-free: amounts
      bucketed to `amount_range` (never raw `amount_paise`), no phone numbers even
      hashed, and UID composites hashed via `hashFriendshipId`.
- [ ] Cloud Functions reviewed: region pinning, typed `HttpsError`s, transaction
      atomicity, idempotency.
- [ ] Security/auth reviewed: input validation, caller authorisation, +91
      phone-auth loading-state handling, no secrets, Storage size/content-type rules.
- [ ] Performance reviewed: N+1/fan-out reads, composite indexes, list caps vs SRS
      section 5 budgets.
- [ ] PR template sections are complete and consistent with the diff.
- [ ] Relevant CI gates and coverage thresholds verified.
- [ ] Acceptance criteria cross-referenced.
- [ ] Critical-journey reachability checked: a new screen/provider is reachable
      from a navigation entry point and covered by an executable end-to-end test,
      not only isolated widget tests.
- [ ] Boundary-contract grep tests considered for invariants 1 and 2.
- [ ] No secrets or PII leaks in source or logs.
- [ ] PR title follows Conventional Commits.
- [ ] Milestones reconciled on merge per `.github/shared/milestone-tracking.md`
      (closed issues milestoned; re-scoped remainders re-homed; a completed sprint
      milestone closed).

## Examples

### Positive example

**Input:** PR adds a new expense creation flow.

**Output:**
```
## Blocking Issues
- `expense_model.dart:12` — money stored as `double` (invariant 1). Use integer paise.
- `expense_repository.dart:45` — client write includes `simplifiedBalances`
  (invariant 2); it is server-maintained by `recomputeAndWrite`. Remove it.

## Major
- `expense_list_provider.dart:8` — `StreamProvider` watches the scoped
  `friendsListProvider` but declares `dependencies: [currentUserIdProvider]` (the
  transitive root). Declare `dependencies: [friendsListProvider]` or it asserts at
  first read.
- `add_expense_screen.dart:60` — `AsyncValue` rendered with `.value!`; loading and
  error branches are unhandled. Use `.when(...)`.
- `add_expense_screen.dart:88` — amount shown via `'₹${amount / 100}'`. Render
  through `formatInrFromPaise`.
- No widget test asserts the amount field's semantic label (accessibility).

## Recommendations
- `expense_telemetry.dart:14` — `expense_added` carries a raw `friendshipId`; hash
  it via `hashFriendshipId` (no PII in telemetry).
- Add a boundary-contract test for the new write path and an offline error-state
  widget test.

## Approved
- Splits sum to `amountPaise`; settlement docs carry `method` / `currency` /
  `verificationStatus`.
- Widget tests cover loading, populated, empty, and error states.
```

### Negative example (should refuse)

**Input:** "Review a PR that adds WhatsApp deep-link sharing."

**Response:** Refused. The PR violates invariant 3 (system share sheet only).
The feature must be removed before review can proceed. Cite SRS sections 3.4 and
4.11.
