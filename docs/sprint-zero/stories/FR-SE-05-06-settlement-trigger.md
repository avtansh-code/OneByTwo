# FR-SE-05/06: `onSettlementWrite` Cloud Function Trigger

> Implementation-ready user story for the second automatic Firestore trigger in
> the application and the first on a **top-level collection**. Wraps the
> existing `recomputeSimplifiedBalances` algorithm in a Firestore
> `onDocumentWritten` trigger at `settlements/{settlementId}`, extends
> `recomputeAndWrite` to actually READ settlements into the net-balance
> computation (the algorithm catalogue's "settlements" row of the read table
> becomes truthful for the first time), and ships the missing Firestore
> security rules so clients can write settlements at all.

---

## SRS Requirement ID(s)

FR-SE-05 (SRS section 4.6 — settlements are recorded by the algorithm),
FR-SE-06 (SRS section 4.6 — partial settlements are supported),
FR-EX-04 (SRS section 4.5 — paise integers; symmetric for settlement
amountPaise).

## Relevant SRS Sections

- Section 4.6 — Simplify & Settle
- Section 5.4 — Privacy and PII handling
- Section 5.10 — Observability
- Section 7.1 — Cloud Functions runtime (region pinning)
- Section 7.2 — Firestore schema (`settlements/{settlementId}`)
- Section 7.3 — Key architectural decisions (Invariant 1; Invariant 2
  parallel for `verificationStatus` per ARCH-EXT-06)
- Section 7.5 — Security rules (settlements)

## Priority

**P0 — Must have.** Settlements that do not affect `simplifiedBalances` are
useless to users. The algorithm extension is the load-bearing piece; without
it, the trigger ships meaningless side-effects. Shipping this trigger BEFORE
the first client producer of settlements (FR-SE-08 / settle-up UI) means
balances "just work" the moment the settle-up flow lands.

## Story Points

**5.** Three concerns bundled (security rules + algorithm core extension +
trigger), each small (~150 lines code + tests). Patterns from PR #36 are
ratified; this story reuses, does not re-derive.

## User Story

As a **member of a friendship**,
I want **the app to recompute the simplified balance and bump the activity
timestamp automatically whenever any settlement involving me is created,
edited, or soft-deleted**,
so that **after I pay my friend back (or they pay me back), the friends list
and per-friend net-balance pill immediately reflect the post-payment
truthful state without any client-side orchestration**.

## Preconditions

1. A friendship document exists at `friendships/{fid}` with valid
   `memberIds` (two sorted UIDs) and a server-managed `simplifiedBalances`
   field (initialised to `{}` by Cloud Functions per Invariant 2 and now
   correctly reflecting expenses thanks to PR #36's
   `onExpenseWriteFriendship` trigger).
2. The shared `recomputeAndWrite` core from PR #36 is live in
   `functions/src/simplified-debts/function.ts` and exports the typed
   `RecomputeResult` discriminated union.
3. The `hashId()` utility from PR #36 is live at
   `functions/src/utils/id-hash.ts`.
4. The trigger deploys to `asia-south1` (Mumbai) per SRS section 7.1.
5. The Firebase Emulator Suite is available for pre-merge integration
   testing (Firestore on port 8181, Functions on port 5001, per
   `firebase.json`).
6. The settlement write originates from the `fromUserId` (debtor) per the
   new security rules.

---

## Acceptance Criteria

### AC-1 — Settlements rules: create allowed for `fromUserId` only

> Given an authenticated user
> When they write a settlement to `settlements/{settlementId}` with
> `fromUserId == request.auth.uid` AND all schema invariants satisfied
> (amount > 0, valid context discriminator, both parties are members of
> the parent context, extension-point locks satisfied, allowed key set
> exactly)
> Then the write succeeds.
>
> Given `fromUserId != request.auth.uid`
> Then the write is rejected by the security rules.

### AC-2 — Settlements rules: read allowed for both parties

> Given a settlement with `fromUserId: A` and `toUserId: B`
> Then both A and B can read the document
> And outsiders cannot read
> And unauthenticated callers cannot read.

### AC-3 — Settlements rules: `verificationStatus` is server-only

> Given a settlement exists with `verificationStatus: 'unverified'`
> When a client attempts to update the field to ANY other value
> (`'verified'`, `'pending'`, `'failed'`, even back to `'unverified'`
> with the diff still flagging the affected key)
> Then the write is rejected by the field-level diff rule.
>
> This is the **Invariant-2 parallel for settlements** per ARCH-EXT-06.
> v1.0 leaves `verificationStatus` at the literal `'unverified'` default
> and no server logic writes it; the rules are the enforcement mechanism.

### AC-4 — Settlements rules: extension-point locks

> Given a settlement create
> Then `method == 'manual'` (ARCH-EXT-01), `currency == 'INR'`
> (ARCH-EXT-02), and `verificationStatus == 'unverified'` (ARCH-EXT-06)
> are mandatory
> And any other value for these fields is rejected
> And `contextType in {'friendship', 'group'}` is enforced
> And both `fromUserId` and `toUserId` must be in the parent context's
> `memberIds`.

### AC-5 — Settlements rules: immutability of historical fields

> Given a settlement exists
> When a client attempts to mutate `fromUserId`, `toUserId`,
> `amountPaise`, `contextType`, `contextId`, `date`, `method`,
> `currency`, `createdAt`, or `note`
> Then the write is rejected.
>
> The ONLY mutable field is `deleted` (soft-delete via setting
> `deleted: true`). Settlements are historical records; the supported
> correction path is soft-delete plus a new settlement.

### AC-6 — Settlements rules: hard delete denied

> Given a settlement exists
> When any client attempts to hard-delete the document
> Then the write is rejected
> And admin-SDK paths (e.g. cleanup scripts) bypass the rules as usual.

### AC-7 — `recomputeAndWrite` reads settlements

> Given a friendship has both expenses AND settlements (the latter is the
> NEW data class fed into the algorithm in this PR)
> When the algorithm runs
> Then the net balance for each member reflects BOTH:
> - Expense splits (payer credited +amountPaise; each split member
>   debited −sharePaise; the existing PR #12 / PR #36 behaviour).
> - Settlement payments (the `fromUserId` credited +amountPaise — the
>   payment reduces their debt; the `toUserId` debited −amountPaise —
>   the recipient is now owed less).
> And the resulting `simplifiedBalances` map matches the canonical
> settlement test matrix.

### AC-8 — `recomputeAndWrite` filters soft-deleted settlements

> Given a settlement document with `deleted: true`
> When the algorithm runs
> Then the soft-deleted settlement is excluded from the net-balance
> computation
> And the resulting `simplifiedBalances` matches the state computed from
> the non-deleted settlement set
> (same posture as expenses — `where('deleted', '!=', true)` or in-code
> filter; see Architect Notes §2 for the chosen implementation).

### AC-9 — Trigger fires on settlement create

> Given a settlement is written to `settlements/{settlementId}` with
> `contextType: 'friendship'`, `contextId: 'fid'`
> When the trigger fires
> Then within the invocation window the parent friendship doc
> `friendships/fid` has:
> - `simplifiedBalances` recomputed (now reflecting BOTH expenses and the
>   new settlement)
> - `lastActivityAt` updated to the trigger's `event.time` (subject to
>   the monotonicity guard from PR #36 AC-12).
> And both writes happen in the same Firestore transaction (atomicity
> property inherited from PR #36 AC-6).

### AC-10 — Trigger fires on settlement update and soft-delete

> Given an existing settlement
> When a client soft-deletes the settlement (sets `deleted: true`)
> Then the recomputation runs and the resulting `simplifiedBalances`
> excludes the soft-deleted settlement.
>
> Given an existing settlement
> When ANY field is modified (including the soft-delete branch above)
> Then the trigger fires the recompute path
> And the on-document-after side carries the post-edit data shape from
> which the discriminator (`contextType`, `contextId`) is read.

### AC-11 — Trigger fires on hard delete (admin SDK only)

> Given an existing settlement
> When the document is hard-deleted (admin SDK only — client hard-deletes
> are denied per AC-6)
> Then the trigger fires
> And the discriminator (`contextType`, `contextId`) is read from the
> `change.before` snapshot data (the `change.after` snapshot has
> `exists == false` on hard delete)
> And the recomputation runs over the remaining settlement set.

### AC-12 — Trigger handles missing context gracefully

> Given a settlement with `contextType: 'friendship'` and a `contextId`
> pointing at a deleted friendship doc
> When the trigger fires
> Then the handler logs
> `simplified_debts_compute_failed { errorCode: 'CONTEXT_NOT_FOUND' }`
> via structured logging
> And the handler returns successfully (no throw) so Cloud Functions
> does NOT retry
> And no orphaned writes are produced.
>
> (Mirror of PR #36 AC-10.)

### AC-13 — Stale-event guard

> Given a settlement-trigger event whose `event.time` is older than 7
> days (the Cloud Functions event-delivery retention window)
> When the trigger receives the event
> Then the handler logs `settlement_trigger_stale_event_dropped` and
> returns successfully without writing.
>
> (Mirror of PR #36 AC-11.)

### AC-14 — `lastActivityAt` monotonicity

> Given two settlement-trigger invocations for the same friendship
> arrive out of order
> When the later invocation by wall-clock arrival has an earlier
> `event.time`
> Then the trigger writes `max(existingLastActivityAt, eventTimestamp)`
> so the field never regresses.
>
> (Mirror of PR #36 AC-12 — the monotonicity guard lives in the shared
> `recomputeAndWrite` core; the settlement trigger inherits it for free.)

### AC-15 — Canonical settlement test cases pass end-to-end

> The integration test suite walks the following matrix end-to-end via
> the registered trigger (not via direct DI):
>
> **Case A — Full debt settlement (zeros the debt)**
> > Given B owes A 5000 paise (from one expense, equal split of 10000)
> > When B pays A 5000 paise (a settlement of `fromUserId: B, toUserId: A,
> > amountPaise: 5000`)
> > Then `simplifiedBalances` becomes `{}` (empty — no residual debt).
>
> **Case B — Partial settlement (FR-SE-06)**
> > Given B owes A 5000 paise
> > When B pays A 2000 paise (a partial settlement)
> > Then `simplifiedBalances` becomes `{B: {A: 3000}}` — the residual
> > debt is precisely the unpaid portion.
> > This satisfies FR-SE-06 without any additional algorithm support
> > (the algorithm naturally handles partials because settlements
> > directly adjust the net-balance map).
>
> **Case C — Overshoot (debtor pays more than owed)**
> > Given B owes A 5000 paise
> > When B pays A 8000 paise (overshoots the debt by 3000)
> > Then `simplifiedBalances` becomes `{A: {B: 3000}}` — the net
> > balance flips sign; A now owes B 3000. The algorithm correctly
> > handles this because the net-balance map is signed and the
> > simplify step is sign-agnostic.

### AC-16 (Regression — Invariant 2) — `simplifiedBalances` still client-read-only

> The new settlements code does NOT introduce a second writer of
> `simplifiedBalances` in `functions/src/**`. The existing
> field-level diff rule on `friendships/{id}` and `groups/{id}`
> continues to reject any client write attempt.
>
> Verification: grep across `functions/src/**` for
> `tx.update.*simplifiedBalances` MUST return exactly 1 match (the
> existing `recomputeAndWrite` writer; the settlements-read extension
> does NOT add a second).

### AC-17 (Regression) — Existing `onExpenseWriteFriendship` still works

> The extension to `recomputeAndWrite` (now reading settlements
> alongside expenses) MUST NOT regress PR #36's behaviour.
>
> Verification: the existing `on-expense-write.integration.test.ts`,
> `simplified-debts.integration.test.ts`, and the boundary tests in
> `functions/test/triggers/on-expense-write/function.test.ts` and
> `functions/test/simplified-debts/function.test.ts` ALL pass without
> modification.

---

## Telemetry Events

Server-side structured logging via `firebase-functions/logger` (NOT client
Firebase Analytics). All events are PII-free per SRS section 5.4 and
ADR-0013. Friendship IDs (`{uidA}_{uidB}`) and settlement IDs are hashed
via `functions/src/utils/id-hash.ts` (`hashId()` — SHA-256 truncated to 16
hex chars) before logging.

| Event name | Parameters | Trigger |
|---|---|---|
| `settlement_trigger_fired` | `contextType: 'friendship' \| 'group'`, `contextIdHash: string` (16 hex), `settlementIdHash: string` (16 hex), `changeType: 'create' \| 'update' \| 'delete'`, `eventTime: string` (ISO 8601) | Top of handler, before any work. Fires for every invocation regardless of outcome. |
| `settlement_trigger_stale_event_dropped` | `contextType`, `contextIdHash`, `settlementIdHash`, `eventTime`, `ageMs: number` | Stale-event guard (AC-13). |
| `simplified_debts_compute_started` | `contextType`, `contextIdHash` | Emitted by the trigger wrapper around the shared `recomputeAndWrite` core. |
| `simplified_debts_compute_completed` | `contextType`, `contextIdHash`, `elapsedMs: number`, `transferCount: number` | Emitted by the trigger wrapper on successful core completion. |
| `simplified_debts_compute_failed` | `contextType`, `contextIdHash`, `errorCode: 'CONTEXT_NOT_FOUND' \| 'BALANCE_INVARIANT_VIOLATED' \| 'INTERNAL'`, `elapsedMs: number` | Emitted by the trigger wrapper on every failure path. |

**Strict PII guard:** the structured logger NEVER receives `fromUserId`,
`toUserId`, `amountPaise`, `date`, `note`, or any raw UID-containing
identifier (including the unhashed `friendshipId`). Only opaque
`settlementIdHash`/`contextIdHash` values and contextType discriminators
are loggable. A `function.test.ts` PII guard explicitly asserts this
contract using a realistic `{uidA}_{uidB}` friendship-id value AND a
realistic settlement ID.

---

## Invariant Applicability Assessment

| # | Invariant | Applicability |
|---|---|---|
| 1 | Money is integer paise | **Applicable.** Settlement `amountPaise` is an integer; the algorithm's settlement-credit/debit is integer arithmetic. No `double` or `float`. The new rules enforce `amountPaise is int && amountPaise > 0`. |
| 2 | `simplifiedBalances` server-maintained | **Applicable.** The write site remains the single `tx.update(contextRef, {...guardedAlsoSet, simplifiedBalances})` inside `recomputeAndWrite`. The new settlement read is INPUT to the algorithm, not a second writer of `simplifiedBalances`. The DoD grep expectation is unchanged: exactly 1 write site in `functions/src/**`. |
| 2-parallel | `verificationStatus` on settlements (per ARCH-EXT-06) | **Applicable.** The new rules enforce this. There is currently no server-side writer of `verificationStatus` in v1.0 (the field stays at `'unverified'`); the Invariant-2-parallel is enforced by the rules alone. |
| 3 | System share sheet only | N/A. This story has no client UI and no outbound sharing surface. |
| 4 | Single Firebase project | **Applicable.** The trigger deploys to the single production project in `asia-south1`. Integration tests run against the Firebase Emulator Suite. |

PII / ADR-0013 compliance: friendship document IDs follow the
`{uidA}_{uidB}` composite-UID pattern (per the schema and PR #32
deterministic-ID rule). Settlement IDs are auto-generated opaque
Firestore IDs (safe to log raw, but hashed for log-format parity with
the expense trigger). The trigger MUST hash both `friendshipId` and
`settlementId` before any structured log call. `functions/src/utils/id-hash.ts`
(`hashId()` — SHA-256 truncated to 16 hex chars / 64 bits) is the shared
utility introduced in PR #36 and reused here. Affirmative test:
`function.test.ts` "never logs PII (raw UIDs in friendshipId,
fromUserId/toUserId, amounts, note)" exercises the contract with a
realistic `{uidA}_{uidB}` friendship-id value.

---

## Definition of Done

Reference: `docs/design/08-plan/definition-of-ready-and-done.md`

- [ ] Code merged to `main` via approved PR.
- [ ] New trigger module deployed to `asia-south1` (Mumbai) — verified via
      the manual smoke matrix in the PR body.
- [ ] Function-boundary unit tests passing (mocked Firestore, no emulator
      needed). Per-module coverage ≥ 70% for
      `functions/src/triggers/on-settlement-write/`.
- [ ] Security-rules unit tests passing against the Firestore emulator on
      port 8181 (`npm run test:rules`). New file
      `functions/test/firestore-rules/settlements.test.ts` covers AC-1
      through AC-6 exhaustively.
- [ ] Integration tests passing against the Firebase Emulator Suite
      (`npm run test:integration` inside `firebase emulators:exec`). The
      canonical settlement matrix (AC-15) and the atomicity assertion
      (AC-9) are exercised through the actual registered trigger.
- [ ] Existing `on-expense-write.integration.test.ts` and
      `simplified-debts.integration.test.ts` continue to pass without
      modification (AC-17 regression).
- [ ] QA manual smoke matrix completed and signed off (Phase 5 step 7 of
      `docs/copilot_prompts/sprint_2/6.md`).
- [ ] Telemetry events in place and PII-free (verified by the PII guard
      test).
- [ ] Invariant compliance confirmed (Invariants 1, 2, 2-parallel for
      `verificationStatus`, 4 — see assessment above).
- [ ] Coverage gate green (Functions overall ≥ 50%; new module ≥ 70%;
      existing `simplified-debts/` not regressed below the PR #36
      baseline of 86.44% branch).
- [ ] Documentation updated: `cloud-functions-catalogue.md` Appendix A
      status flip (`onSettlementWrite` planned → shipped); section 1
      READ TABLE now truthful for the settlements row;
      `firestore-security-rules.md` settlements section reconciled with
      the implementation; `firestore-schema.md` settlements schema
      reconciled with the implementation (adds `deleted` and
      `createdAt` fields to the table); `sprint-2-plan.md`,
      `next-three-prs.md` rolled.
- [ ] Composite index for settlements declared in
      `firestore.indexes.json`.
- [ ] No open S1 or S2 bugs.

---

## Invariant Compliance

- [ ] Invariant 1 (paise): settlement compute is pure integer arithmetic;
      rules `is int` checks reject any `double`/`float` inputs.
- [ ] Invariant 2 (`simplifiedBalances` server-only): the trigger does
      NOT introduce a second writer; the field-level diff rule on
      `friendships/{id}` and `groups/{id}` continues to reject client
      writes (AC-16 regression).
- [ ] Invariant 2-parallel (`verificationStatus` server-only): the new
      settlements rules reject any client mutation of the field
      (AC-3).
- [ ] Invariant 3 (system share sheet only): N/A in this story.
- [ ] Invariant 4 (single Firebase project): compliant — production only,
      with emulator-backed pre-merge verification.

---

## Design Artefact References

| Artefact | Path |
|---|---|
| Cloud Functions catalogue (Section 3 — `onSettlementWrite`) | `docs/design/07-technical/cloud-functions-catalogue.md` |
| Firestore schema (`settlements/{settlementId}`) | `docs/design/07-technical/firestore-schema.md` |
| Firestore security rules (settlements section) | `docs/design/07-technical/firestore-security-rules.md` |
| Simplified-debts algorithm (settlement semantics) | `docs/design/07-technical/simplified-debts-algorithm.md` |
| Cloud Functions error codes | `docs/design/07-technical/cloud-functions-error-codes.md` |
| Extension-points register (ARCH-EXT-01, -02, -06) | `docs/design/07-technical/extension-points-register.md` |
| PR #12 callable story | `docs/sprint-zero/stories/FUNC-01-simplified-debts-stub.md` |
| PR #36 expense trigger story (precedent for this PR) | `docs/sprint-zero/stories/FR-SE-03-04-expense-trigger-friendship.md` |
| Feature-PR conventions | `docs/patterns/feature-pr-conventions.md` |

---

## Responsible Agents

| Agent | Responsibility |
|---|---|
| PM | Story authorship, AC clarity, scope discipline (no widening to activity-feed/FCM/verification-state-machine/groups-expense-binding in this PR). |
| Architect | Source-layout decision, algorithm-extension semantics, settlements rules layout, in-code filter for soft-deleted settlements, composite-index requirement, retry semantics. |
| Cloud Functions Dev | Trigger module implementation, `recomputeAndWrite` settlement-read extension, security-rules block, function-boundary tests, integration tests. |
| DevOps | No CI workflow changes needed (PR #36 already added `npm run test:integration` inside `firebase emulators:exec`). The new trigger and integration test plug into the same step. |
| QA | Manual smoke matrix sign-off (Phase 5 step 7), DoD §3 sign-off with screenshots of friends-list real-time updates reflecting settlement-adjusted balances and emulator logs showing trigger fires. |

---

## Technical Notes

- **Trigger path:** `settlements/{settlementId}` (top-level collection).
  First trigger on a top-level collection in the application's history;
  PR #36 covered the subcollection-scoped case.
- **Region:** `asia-south1` (Mumbai) per SRS section 7.1.
- **Retry:** v2 trigger options `{retry: true}`. Transient errors throw
  and Cloud Functions retries. CONTEXT_NOT_FOUND returns successfully
  (no retry); stale events drop.
- **Shared core:** `recomputeAndWrite` from PR #36 — **public signature
  unchanged**. Settlements are an internal implementation detail of the
  algorithm reading shape; callers all invoke with
  `{contextType, contextId, alsoSet}`. The fact that settlements now
  feed in is transparent to them.
- **Algorithm semantics:** the pure `simplifyDebts()` in
  `algorithm.ts` is **LOCKED** — settlements semantics enter via
  `computeNetBalances()` in `function.ts` which now accepts both
  expenses and settlements and folds them into the net-balance map.
- **Atomicity:** `simplifiedBalances` and `lastActivityAt` are written
  in the SAME `tx.update(contextRef, ...)`. The settlement trigger
  passes `alsoSet: { lastActivityAt: max(existing, eventTimestamp) }`
  to the core, identical to the expense trigger pattern.
- **Test paths:**
  - `functions/test/triggers/on-settlement-write/function.test.ts` —
    boundary unit tests (mocked Firestore + logger).
  - `functions/test/firestore-rules/settlements.test.ts` —
    `@firebase/rules-unit-testing` against emulator.
  - `functions/test/integration/on-settlement-write.integration.test.ts` —
    end-to-end via the registered trigger inside
    `firebase emulators:exec --only auth,firestore,functions,storage`.
  - `functions/test/simplified-debts/function.test.ts` — extended with
    settlement-input mock cases.
  - `functions/test/simplified-debts/algorithm.property.test.ts` —
    extended to assert zero-sum preservation under mixed
    expense+settlement sequences.

---

## Out of Scope (explicitly deferred — hand-off seams documented in code)

- **`onExpenseWriteGroup` trigger binding.** Sprint 3 (groups epic). The
  shared `recomputeAndWrite` core already supports the groups context as
  a one-line addition; the binding is deferred until groups exist in
  production.
- **Activity-feed item writes
  (`activity/{userId}/items/{itemId}`).** FR-AC-01 in a later sprint.
  Hand-off seam: `// TODO(FR-AC-01)` comment in the trigger source.
- **FCM push notifications to the recipient.** FR-AC-03 in a later
  sprint. Requires the notification permission flow, per-user
  `fcmTokens` plumbing, and the `notificationPrefs.settlement` toggle.
  Hand-off seam: `// TODO(FR-AC-03)` comment.
- **Flutter settlement-creation UI (FR-SE-08 / settle-up flow).**
  Later PR. The trigger ships BEFORE its first client producer so
  balances "just work" when the UI lands.
- **`verificationStatus` state machine** (transitions from
  `'unverified'` to `'pending'`, `'verified'`, `'failed'`). Post-v1.0
  (UPI integration per ARCH-EXT-06). v1.0 leaves the field at the
  literal `'unverified'` default; the rules enforce server-only;
  that's all this PR ships.
- **Any modification to `functions/src/simplified-debts/algorithm.ts`.**
  The pure `simplifyDebts()` is LOCKED (PR #12 covered the canonical
  6-case matrix to 100%). Only `computeNetBalances` in `function.ts`
  is extended to fold settlement data into the net-balance map.
- **Any change to the Flutter codebase.** The friends-list reader will
  pick up the new balances via the existing snapshot stream from
  PR #35 — no client diff is necessary or appropriate.
- **Fix for the pre-existing `lookup-user-by-phone-number` rate-limit
  doc-path bug** (5 `describe.skip`'d integration tests surfaced by
  PR #36). Out of scope; separate follow-up PR.
- **Changes to `recomputeAndWrite`'s public signature.** Settlements
  are an internal read concern; callers (callable + expense trigger +
  new settlement trigger) all invoke unchanged.

---

## Architect Notes

> Appended for PR #37. These notes ratify the design decisions taken
> before implementation begins. References:
> `docs/copilot_prompts/sprint_2/6.md`,
> `.github/shared/invariants.md`, `.github/shared/decision-log.md`
> (ADR-0001 simplified debts; ADR-0002 paise integers; ADR-0011 Cloud
> Functions test-pyramid layers; ADR-0013 PII / telemetry hashing).

### 1. Source layout — new module under `functions/src/triggers/`

- **Folder:** `functions/src/triggers/on-settlement-write/` (kebab-case,
  matching PR #36's `on-expense-write/`).
- **Files:**
  - `function.ts` — exports `createTriggerHandler(deps)` mirroring the
    PR #36 boundary. Reads `contextType` and `contextId` from
    `change.after?.data() ?? change.before?.data()` (after takes
    precedence; before is the source on hard delete). Delegates to
    `recomputeAndWrite` with `alsoSet: {lastActivityAt: eventTimestamp}`.
  - `index.ts` — registers the trigger using `onDocumentWritten` from
    `firebase-functions/v2/firestore` with
    `{region: 'asia-south1', document: 'settlements/{settlementId}', retry: true}`.
    Re-exported from `functions/src/index.ts` as `onSettlementWrite`.
- **Test mirror:**
  - `functions/test/triggers/on-settlement-write/function.test.ts`
    (boundary unit tests, mocked Firestore).
  - `functions/test/integration/on-settlement-write.integration.test.ts`
    (end-to-end via registered trigger inside `firebase emulators:exec`).
- The trigger handler MUST NOT bake in friendship/group discrimination.
  It passes `{contextType, contextId}` through to `recomputeAndWrite`
  and lets the shared core resolve the path. This keeps the trigger
  context-agnostic and ready for groups (Sprint 3) without
  modification.

### 2. Extend `recomputeAndWrite` to read settlements in the same transaction

- Inside the existing `db.runTransaction(async tx => { ... })`, add a
  second `tx.get` for settlements:
  ```typescript
  const settlementsRef = db
    .collection("settlements")
    .where("contextType", "==", contextType)
    .where("contextId", "==", contextId);
  const settlementsSnap = await tx.get(settlementsRef);
  ```
- **In-code filter for soft-deleted settlements** rather than chaining a
  third `.where("deleted", "!=", true)`. Reason: Firestore composite
  indexes for `==`, `==`, `!=` over three different fields are tedious
  to maintain and the inequality-prefix rule complicates ordering.
  Settlement counts per context are small (single-digit to low double
  digits in v1.0 — friendship cap is 2 members, so settlement velocity
  is bounded). In-code filter is `O(n)` over a small `n` with negligible
  cost compared to the transaction's `tx.get` round-trip.
- The expense subcollection query in PR #36 uses
  `.where("deleted", "!=", true)` because the expense subcollection is
  scoped to a single friendship (no other `==` filters present), so the
  inequality is trivially the only constraint. The settlements query
  has two equality filters first; the in-code soft-delete filter is the
  cleanest workaround.
- Update `computeNetBalances()` to accept BOTH expense snapshots AND
  settlement snapshots:
  ```typescript
  function computeNetBalances(
    expenseSnapshots: FirebaseFirestore.QueryDocumentSnapshot[],
    settlementSnapshots: FirebaseFirestore.QueryDocumentSnapshot[],
  ): Map<string, number> {
    const net = new Map<string, number>();
    // ...existing expense fold (unchanged)...
    for (const snap of settlementSnapshots) {
      const data = snap.data();
      if (data.deleted === true) continue; // In-code soft-delete filter.
      const fromUserId: string = data.fromUserId;
      const toUserId: string = data.toUserId;
      const amountPaise: number = data.amountPaise;
      net.set(fromUserId, (net.get(fromUserId) ?? 0) + amountPaise);
      net.set(toUserId, (net.get(toUserId) ?? 0) - amountPaise);
    }
    return net;
  }
  ```
- **Settlement semantics:** `{fromUserId: A, toUserId: B, amountPaise: N}`
  represents A paying B N paise. This CREDITS A's net balance (+N — A's
  debt is reduced) and DEBITS B's net balance (−N — B is now owed less).
  Combined with the expense fold (payer credited; split members
  debited), the zero-sum invariant is preserved: every transaction is
  internally balanced.
- The `BALANCE_INVARIANT_VIOLATED` check in `simplifyDebts()` (the
  pure algorithm asserts sum of net balances is zero) MUST still pass
  after settlements are included. Both expense splits AND settlements
  preserve the zero-sum property by construction. A property-based test
  extension (`algorithm.property.test.ts`) generates random mixed
  expense+settlement sequences and asserts the sum-zero property.

### 3. `recomputeAndWrite` public signature is UNCHANGED

- `RecomputeRequest` and `RecomputeResult` types stay the same.
  Settlements are an INTERNAL implementation detail of the algorithm
  reading shape — callers (callable + expense trigger + new settlement
  trigger) all invoke with `{contextType, contextId, alsoSet}`. The
  fact that settlements now feed in is transparent to them.
- This means the existing `createHandler(deps)` callable and the
  existing `onExpenseWriteFriendship` trigger continue to work
  unmodified (AC-17 regression).

### 4. Settlement trigger does NOT need new core API

- The trigger reads `contextType` and `contextId` from the settlement
  document data:
  ```typescript
  const data = event.data?.after?.data() ?? event.data?.before?.data();
  if (!data) { /* log and return — defensive */ }
  const {contextType, contextId} = data;
  ```
  then calls `recomputeAndWrite(deps, {contextType, contextId, alsoSet: {lastActivityAt: eventTimestamp}})`
  exactly like the expense trigger calls it for friendships.
- The only difference from the expense trigger is the SOURCE of
  `{contextType, contextId}`:
  - Expense trigger: derives from the PATH (`event.params.friendshipId`
    + literal `'friendship'`).
  - Settlement trigger: derives from the DOC DATA (because the
    settlements collection is top-level and the context discriminator
    lives in the document rather than the path).

### 5. New Firestore Security Rules — `settlements/{settlementId}` block

- Add a new top-level `match /settlements/{settlementId}` block
  alongside the existing `match /friendships/...` and
  `match /groups/...` blocks.
- **Helpers:**
  - `function contextMemberIds(contextType, contextId)` — for
    `'friendship'`, do
    `get(/databases/$(database)/documents/friendships/$(contextId)).data.memberIds`;
    for `'group'`, do the same with `groups/`. Returns the list.
  - `function isContextMember(contextType, contextId, uid)` — returns
    `uid in contextMemberIds(contextType, contextId)`.
  - `function hasOnlyKnownKeys(data)` — whitelisted field set:
    `['fromUserId', 'toUserId', 'amountPaise', 'contextType', 'contextId', 'date', 'note', 'method', 'verificationStatus', 'currency', 'createdAt', 'deleted']`.
    (Adds `deleted` and `createdAt` to the schema field set per §5.1
    below.)
  - `function isValidShape(data)` — type and value checks for each
    field (see Create rule below).
  - `function isValidContextDiscriminator(data)` —
    `contextType in ['friendship', 'group']`, `contextId is string`,
    `contextId.size() > 0`.
- **Create rule:**
  ```
  allow create: if request.auth != null
    && request.resource.data.fromUserId == request.auth.uid
    && hasOnlyKnownKeys(request.resource.data)
    && hasAllRequiredKeys(request.resource.data)
    && isValidShape(request.resource.data)
    && isValidContextDiscriminator(request.resource.data)
    && isContextMember(request.resource.data.contextType,
                       request.resource.data.contextId,
                       request.resource.data.fromUserId)
    && isContextMember(request.resource.data.contextType,
                       request.resource.data.contextId,
                       request.resource.data.toUserId)
    && request.resource.data.fromUserId != request.resource.data.toUserId
    && request.resource.data.amountPaise is int
    && request.resource.data.amountPaise > 0
    && request.resource.data.method == 'manual'           // ARCH-EXT-01
    && request.resource.data.currency == 'INR'            // ARCH-EXT-02
    && request.resource.data.verificationStatus == 'unverified' // ARCH-EXT-06
    && request.resource.data.deleted == false
    && request.resource.data.createdAt == request.time;
  ```
- **Update rule** (ONLY soft-delete; every other field is immutable):
  ```
  allow update: if request.auth != null
    && (request.auth.uid == resource.data.fromUserId
        || request.auth.uid == resource.data.toUserId)
    && immutableFieldsPreserved()
    && verificationStatusUnchanged()
    && onlyDeletedFlagChanged();
  ```
  - `immutableFieldsPreserved()` checks `fromUserId`, `toUserId`,
    `amountPaise`, `contextType`, `contextId`, `date`, `method`,
    `currency`, `createdAt`, `note` are unchanged.
  - `verificationStatusUnchanged()` checks
    `request.resource.data.verificationStatus == resource.data.verificationStatus`.
    This is the Invariant-2-parallel field-level diff rule for
    settlements per ARCH-EXT-06.
  - `onlyDeletedFlagChanged()` checks the affected-keys set is exactly
    `{deleted}` AND `request.resource.data.deleted == true` (clients
    cannot un-delete; restoration is admin-SDK only). This gives the
    classic monotonic soft-delete contract.
- **Read rule:**
  ```
  allow read: if request.auth != null
    && (request.auth.uid == resource.data.fromUserId
        || request.auth.uid == resource.data.toUserId);
  ```
- **Delete rule:** `allow delete: if false;` — hard delete is
  admin-only.

#### 5.1 Schema reconciliation — adds `deleted` and `createdAt`

- The current `firestore-schema.md` settlements table lists 10 fields
  but does NOT include `deleted` or `createdAt`. The implementation
  REQUIRES both:
  - `deleted: bool` (default `false`) — supports soft-delete via
    update; the algorithm filters `deleted === true` settlements out
    of the net-balance fold.
  - `createdAt: timestamp` (immutable; `== request.time` on create) —
    audit field consistent with every other write-rule-enforced
    immutable timestamp in the codebase (users, friendships, groups,
    expenses all have one).
- The settlements section of `firestore-schema.md` and
  `firestore-security-rules.md` are updated in this PR to reflect the
  new field set. The change is additive (no existing settlement docs
  exist in production), and the schema-doc update is documented in
  the PR body.

### 6. Idempotency, retry policy, stale-event guard — inherit PR #36

- Trigger uses `{retry: true}`. CONTEXT_NOT_FOUND log+return.
  BALANCE_INVARIANT_VIOLATED and INTERNAL throw (CF retries). Stale
  event > 7 days drops with a structured log.
- The shared `recomputeAndWrite` handles `lastActivityAt` monotonicity
  for all callers including the new settlement trigger. No new code
  needed.

### 7. No new ADR required

- Settlements rules + algorithm extension + trigger all fall within
  existing ADR-0001 (simplified debts is the sole debt mechanism),
  ADR-0002 (paise integers), ADR-0011 (Cloud Functions test-pyramid
  layers), and ADR-0013 (PII / telemetry hashing) precedent.
- The Invariant-2-parallel for `verificationStatus` is captured by
  ARCH-EXT-06 in the extension-points register — already an
  architectural decision document.
- The schema additions (`deleted`, `createdAt`) are
  field-level additions consistent with the expense pattern;
  documenting them in the schema/rules docs is sufficient.

### 8. Coverage gate posture

- `functions/src/triggers/on-settlement-write/**` is a NEW module
  folder. Per-module ≥70% gate applies.
- `functions/src/simplified-debts/**` sees modest edits (the
  settlements read + `computeNetBalances` extension). Branch coverage
  MUST NOT regress below the PR #36 baseline of 86.44% — new tests
  for the settlements-read branches maintain the gate.
- Property tests in `algorithm.property.test.ts` are extended to
  cover mixed expense + settlement sequences.

### 9. Composite index for the settlements query

- The transaction reads `where('contextType', '==', X).where('contextId', '==', Y)`.
  Firestore composite indexes are required for cross-field `where`
  combinations. Declared in `firestore.indexes.json`:
  ```json
  {
    "collectionGroup": "settlements",
    "queryScope": "COLLECTION",
    "fields": [
      {"fieldPath": "contextType", "order": "ASCENDING"},
      {"fieldPath": "contextId", "order": "ASCENDING"}
    ]
  }
  ```
- The schema doc already lists a (`contextType`, `contextId`, `date`)
  index for the client settlement-history view, but ours can omit
  `date` because the algorithm doesn't order — it scans all matching
  settlements within the transaction. We declare the minimal
  two-field index needed by the trigger's transaction.
- Verified against emulator output: the in-emulator Firestore
  successfully runs the query with this index declared in
  `firestore.indexes.json`.
