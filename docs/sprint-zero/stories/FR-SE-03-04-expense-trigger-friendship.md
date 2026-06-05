# FR-SE-03/04: `onExpenseWriteFriendship` Cloud Function Trigger

> Implementation-ready user story for the first automatic Firestore trigger in
> the application. Wraps the existing `recomputeSimplifiedBalances` algorithm in
> a Firestore `onDocumentWritten` trigger at
> `friendships/{friendshipId}/expenses/{expenseId}` and maintains
> `lastActivityAt` so the friends-list ordering moves on every expense write.

---

## SRS Requirement ID(s)

FR-SE-03 (SRS section 4.6 — algorithm runs as a Cloud Function),
FR-SE-04 (SRS section 4.6 — recompute atomically on every expense write),
FR-EX-04 (SRS section 4.5 — split shares must sum to the total amount in paise),
FR-EX-06 (SRS section 4.5 — soft-delete excludes expense from balance computation).

## Relevant SRS Sections

- Section 4.5 — Expenses
- Section 4.6 — Simplify & Settle
- Section 5.4 — Privacy and PII handling
- Section 5.10 — Observability
- Section 7.1 — Cloud Functions runtime (region pinning)
- Section 7.2 — Firestore schema
- Section 7.3 — Key architectural decisions (Invariants 1 and 2)
- Section 7.5 — Security rules

## Priority

**P0 — Must have.** This trigger is the first non-callable producer of
`simplifiedBalances`. Without it, the read path shipped in PR #35
(`friendsListProvider`) only sees data on documents that admin SDK paths or
tests seed directly. Every expense the app eventually writes (FR-EX-01) depends
on this trigger running before its first client producer ships so that balances
"just work" the moment expense creation lands.

## Story Points

**3.** Focused trigger module that reuses an existing callable's algorithm.
No UI. The work is concentrated in three files (trigger handler, shared
core refactor, new security rules block) and four test files (boundary,
rules, integration end-to-end, callable smoke regression).

## User Story

As a **member of a friendship**,
I want **the app to recompute the simplified balance and bump the activity
timestamp automatically whenever any expense in that friendship changes**,
so that **the friends list and per-friend net-balance pill always show the
truthful current state without any client-side orchestration**.

## Preconditions

1. A friendship document exists at `friendships/{fid}` with valid `memberIds`
   (two sorted UIDs) and a server-managed `simplifiedBalances` field
   (initialised to `{}` by Cloud Functions per Invariant 2).
2. The trigger is deployed to `asia-south1` (Mumbai) per SRS section 7.1.
3. The Firebase Emulator Suite is available for pre-merge integration testing
   (Firestore on port 8181, Functions on port 5001, per `firebase.json`).
4. The expense write originates from a member authenticated by the client
   under the new `friendships/{fid}/expenses/{eid}` security rules.

---

## Acceptance Criteria

### AC-1 — Trigger fires on expense create

> Given a friendship doc exists at `friendships/{fid}`
> When an authenticated member writes a non-deleted expense to
> `friendships/{fid}/expenses/{eid}` with `splits` that sum to `amountPaise`
> Then within the trigger's invocation window the `friendships/{fid}` document
> has `simplifiedBalances` recomputed from the new expense set
> And `lastActivityAt` is updated to the trigger's `event.time` (or kept at
> its existing value if `event.time` is older, per the monotonicity guard)
> And both writes happen in the same Firestore transaction (AC-6).

### AC-2 — Trigger fires on expense update

> Given an existing expense at `friendships/{fid}/expenses/{eid}`
> When a member edits any field (e.g. `amountPaise`, `splits`, `payerId`,
> `description`)
> Then the same recomputation runs and the result reflects the post-edit
> expense set.

### AC-3 — Trigger fires on expense soft-delete

> Given an existing expense with `deleted: false`
> When a member sets `deleted: true`
> Then the recomputation runs and the resulting `simplifiedBalances` excludes
> the deleted expense (the algorithm's `where('deleted', '!=', true)` filter)
> And the expense document remains in Firestore for audit history
> (SRS section 7.3).

### AC-4 — Trigger fires on hard delete

> Given an existing expense
> When the document is hard-deleted (admin SDK only — client soft-deletes per
> security rules)
> Then the recomputation runs and the resulting `simplifiedBalances` reflects
> the remaining expense set.

### AC-5 — Idempotent across retries

> Given the same expense write event is delivered twice (Cloud Functions
> at-least-once delivery semantics)
> Then the second invocation produces identical `simplifiedBalances` to the
> first
> And `lastActivityAt` is at worst overwritten with an event timestamp equal
> to or later than the first invocation's (monotonic, never regresses).

### AC-6 — Atomicity

> Given the trigger runs
> Then `simplifiedBalances` and `lastActivityAt` are written in the same
> Firestore transaction
> And a partial write (one field updated, the other not) is impossible
> And no client read can observe a state in which only one of the two fields
> reflects the latest event.

### AC-7 (Regression — Invariant 2) — Client write rejection

> Given an authenticated member of a friendship
> When the client attempts to write `simplifiedBalances` directly on the
> friendship document
> Then the existing field-level diff rule in `firestore.rules` rejects the
> write
> And the trigger remains the sole writer of the field
> (re-verifies the rule established in PR #12 and re-verified in PR #35).

### AC-8 — Expense subcollection rules (new in this PR)

> Given an authenticated user attempts to write to
> `friendships/{fid}/expenses/{eid}`:
>
> **Create — allowed**
> > Given the caller is a member of the friendship and the document satisfies
> > the schema (valid `amountPaise > 0`, `splits.size() in 1..2`, each
> > `sharePaise >= 0`, sum of `sharePaise` equals `amountPaise` exactly,
> > `payerId in memberIds`, every `splits[i].userId in memberIds`,
> > `splitMethod in {equal, unequal, percentage, shares, exact}`,
> > `currency == 'INR'`, `source == 'manual'`, `recurringRule == null`,
> > `deleted == false`, `createdBy == request.auth.uid`,
> > `createdAt == request.time`, `updatedAt == request.time`)
> > Then the write succeeds.
>
> **Create — rejected**
> > Given any of the above conditions fails (sum mismatch, non-member payer,
> > non-member split user, extension-point lock violation, missing required
> > field, `deleted: true` on create, immutable field mismatch, non-member
> > caller, unauthenticated caller)
> > Then the write is rejected by the security rules.
>
> **Update — allowed**
> > Given the caller is a member, the immutable fields `createdBy` and
> > `createdAt` are preserved, the post-update document still satisfies all
> > schema invariants (including the sum check),
> > And `updatedAt == request.time`
> > Then the update succeeds. Soft-delete (`deleted: true`) follows this path.
>
> **Update — rejected**
> > Given any immutable field changes, the sum check fails after edit, or the
> > caller is not a member,
> > Then the update is rejected.
>
> **Delete — rejected**
> > Hard delete is denied for all clients. Soft-delete via update is the
> > supported path.

### AC-9 — `simplifiedBalances` is correct for the canonical 6-case matrix

> Given each of the six canonical algorithm cases from
> `docs/design/07-technical/simplified-debts-algorithm.md` (empty; single
> member; perfectly balanced; cyclic to zero; three-person trip; five-person
> flat-share)
> When the expenses are seeded under a friendship and the trigger fires
> Then the resulting `simplifiedBalances` map exactly matches the canonical
> expected output documented for that case
> And the trigger path proves the wiring is correct end-to-end, not just the
> pure algorithm (which PR #12 covered via the callable).

### AC-10 (Negative) — Context not found does not retry-storm

> Given an expense write to `friendships/{fid}/expenses/{eid}` where the
> friendship document has been deleted (race with friendship deletion)
> When the trigger fires
> Then the handler logs
> `simplified_debts_compute_failed { errorCode: 'CONTEXT_NOT_FOUND' }` via
> structured logging
> And the handler returns successfully (no throw) so Cloud Functions does
> NOT retry
> And no orphaned writes are produced.

### AC-11 (Negative) — Stale event guard

> Given an expense write event whose `event.time` is older than 7 days (the
> Cloud Functions event-delivery retention window)
> When the trigger receives the event
> Then the handler logs `expense_trigger_stale_event_dropped` and returns
> successfully without writing
> And `simplifiedBalances` is not rewritten based on potentially obsolete
> intermediate state.

### AC-12 (Negative) — `lastActivityAt` monotonicity

> Given two trigger invocations for the same friendship arrive out of order
> (Cloud Functions delivery is at-least-once and not strictly ordered)
> When the later invocation by wall-clock arrival has an earlier `event.time`
> Then the trigger writes
> `max(existingLastActivityAt, eventTimestamp)` so the field never regresses
> And the friends list ordering (AC-6 of FR-FR-03) remains correct.

---

## Telemetry Events

Server-side structured logging via `firebase-functions/logger` (NOT client
Firebase Analytics). All events are PII-free per SRS section 5.4 and ADR-0013.
Friendship IDs (`{uidA}_{uidB}`) and expense IDs are hashed via
`functions/src/utils/id-hash.ts` (`hashId()` — SHA-256 truncated to 16 hex
chars) before logging.

| Event name | Parameters | Trigger |
|---|---|---|
| `expense_trigger_fired` | `contextType: 'friendship'`, `contextIdHash: string` (16 hex), `expenseIdHash: string` (16 hex), `changeType: 'create' \| 'update' \| 'delete'`, `eventTime: string` (ISO 8601) | Top of handler, before any work. Fires for every invocation regardless of outcome. |
| `expense_trigger_stale_event_dropped` | `contextType`, `contextIdHash`, `expenseIdHash`, `eventTime`, `ageMs: number` | Stale-event guard (AC-11). |
| `simplified_debts_compute_started` | `contextType`, `contextIdHash` | Emitted by the trigger wrapper around the shared `recomputeAndWrite` core. |
| `simplified_debts_compute_completed` | `contextType`, `contextIdHash`, `elapsedMs: number`, `transferCount: number` | Emitted by the trigger wrapper on successful core completion. |
| `simplified_debts_compute_failed` | `contextType`, `contextIdHash`, `errorCode: 'CONTEXT_NOT_FOUND' \| 'BALANCE_INVARIANT_VIOLATED' \| 'INTERNAL'`, `elapsedMs: number` | Emitted by the trigger wrapper on every failure path. |

Note: the callable wrapper (`createHandler` in
`functions/src/simplified-debts/function.ts`) is a separate logging path; its
`contextId` field is preserved unchanged because callable invocations are
typically for the `group` context (group IDs are opaque auto-generated
Firestore IDs, not composite UIDs). Future work may unify the callable's
logging to the hashed form if/when groups membership context creates
similar PII concerns.

**Strict PII guard:** the structured logger NEVER receives `payerId`,
`splits[].userId`, `amountPaise`, `sharePaise`, `description`, or any raw
UID-containing identifier (including the unhashed `friendshipId`). Only
opaque `expenseIdHash`/`contextIdHash` values and contextType
discriminators are loggable. A `function.test.ts` PII guard explicitly
asserts this contract using a realistic `{uidA}_{uidB}` friendship-id
value.

---

## Invariant Applicability Assessment

| # | Invariant | Applicability |
|---|---|---|
| 1 | Money is integer paise | **Applicable.** Every value read from the expense doc (`amountPaise`, `splits[i].sharePaise`) and written back (`simplifiedBalances` paise) is an integer. No `double` or `float` arithmetic. The new rules enforce `amountPaise is int`, `sharePaise is int`, and `sum(sharePaise) == amountPaise` exactly (no rounding tolerance). |
| 2 | `simplifiedBalances` server-maintained | **Applicable — first non-callable production producer.** The trigger writes the field via the admin SDK (server-side). Clients still cannot write it (AC-7 regression test re-verifies). This PR transitions Invariant 2 from a read-side abstraction to a live server-side production-data writer. |
| 3 | System share sheet only | N/A. This story has no client UI and no outbound sharing surface. |
| 4 | Single Firebase project | **Applicable.** The trigger deploys to the single production project in `asia-south1`. Integration tests run against the Firebase Emulator Suite via `scripts/dev/start-emulators.sh` and `firebase emulators:exec`. |

PII / ADR-0013 compliance: friendship document IDs follow the
`{uidA}_{uidB}` composite-UID pattern (per the schema and PR #32
deterministic-ID rule), so logging the raw `friendshipId` would leak
user identifiers into Cloud Logging. The trigger MUST hash the
friendshipId before any structured log call. PR #36 introduces
`functions/src/utils/id-hash.ts` (`hashId()` — SHA-256 truncated to
16 hex chars / 64 bits) and threads it through every log line in
`functions/src/triggers/on-expense-write/function.ts`. Affirmative
test: `function.test.ts` "never logs PII (raw UIDs in friendshipId,
payer/split userIds, amounts, description)" exercises the contract
with a realistic `{uidA}_{uidB}` friendship-id value. The shared
client-side helper is `lib/core/telemetry/event_id_hash.dart`
(PR #35) — both implementations use the same hash format for
correlation parity between server logs and client telemetry.

---

## Definition of Done

Reference: `docs/design/08-plan/definition-of-ready-and-done.md`

- [ ] Code merged to `main` via approved PR.
- [ ] New trigger module deployed to `asia-south1` (Mumbai) — verified via
      the manual smoke matrix in the PR body.
- [ ] Function-boundary unit tests passing (mocked Firestore, no emulator
      needed). Per-module coverage ≥ 70% for
      `functions/src/triggers/on-expense-write/`.
- [ ] Security-rules unit tests passing against the Firestore emulator on
      port 8181 (`npm run test:rules`).
- [ ] Integration tests passing against the Firebase Emulator Suite
      (`npm run test:integration` inside `firebase emulators:exec`). The
      canonical 6-case matrix (AC-9) and the atomicity assertion (AC-6) are
      exercised through the actual registered trigger, not via direct DI.
- [ ] QA manual smoke matrix completed and signed off (Phase 5 step 8 of
      `docs/copilot_prompts/sprint_2/5.md`).
- [ ] Telemetry events in place and PII-free (verified by the PII guard test).
- [ ] Invariant compliance confirmed (Invariants 1, 2, 4 — see assessment
      above).
- [ ] Coverage gate green (Functions overall ≥ 50%; new module ≥ 70%;
      existing `simplified-debts/` not regressed).
- [ ] Documentation updated: `cloud-functions-catalogue.md` Appendix A status
      flip; `sprint-2-plan.md`, `next-three-prs.md`,
      `07-bucket-b-burndown.md` rolled.
- [ ] No open S1 or S2 bugs.

---

## Invariant Compliance

- [ ] Invariant 1 (paise): server-side compute and write are pure integer
      arithmetic; rules `is int` checks reject any `double`/`float` inputs.
- [ ] Invariant 2 (`simplifiedBalances` server-only): the trigger is the sole
      new writer; the field-level diff rule on `friendships/{id}` continues
      to reject client writes (AC-7 regression test).
- [ ] Invariant 3 (system share sheet only): N/A in this story.
- [ ] Invariant 4 (single Firebase project): compliant — production only,
      with emulator-backed pre-merge verification.

---

## Design Artefact References

| Artefact | Path |
|---|---|
| Cloud Functions catalogue (Section 2 — `onExpenseWrite`) | `docs/design/07-technical/cloud-functions-catalogue.md` |
| Firestore schema (`friendships/{id}/expenses/{id}`) | `docs/design/07-technical/firestore-schema.md` |
| Firestore security rules (expenses subcollection outline) | `docs/design/07-technical/firestore-security-rules.md` |
| Simplified-debts algorithm (canonical 6-case matrix) | `docs/design/07-technical/simplified-debts-algorithm.md` |
| Cloud Functions error codes | `docs/design/07-technical/cloud-functions-error-codes.md` |
| Existing callable (PR #12, FUNC-01 story) | `docs/sprint-zero/stories/FUNC-01-simplified-debts-stub.md` |
| Friends list reader (PR #35, FR-FR-03 story) | `docs/sprint-zero/stories/FR-FR-03-friends-list.md` |
| Feature-PR conventions | `docs/patterns/feature-pr-conventions.md` |

---

## Responsible Agents

| Agent | Responsibility |
|---|---|
| PM | Story authorship, AC clarity, scope discipline (no widening to settlements/groups/activity-feed/FCM in this PR). |
| Architect | Source-layout decision (binding option, recompute-handler extraction variant), `lastActivityAt` monotonicity guard, retry semantics, sum-check feasibility in security rules. |
| Cloud Functions Dev | Trigger module implementation, shared core refactor, security-rules block, function-boundary tests, integration tests. |
| DevOps | CI workflow update — `npm run build` before `emulators:exec`, `npm run test:integration` inside `emulators:exec` so the trigger is actually registered and end-to-end tested. |
| QA | Manual smoke matrix sign-off (Phase 5 step 8), DoD §3 sign-off with screenshots of friends-list real-time updates and emulator logs showing trigger fires. |

---

## Technical Notes

- **Trigger path:** `friendships/{friendshipId}/expenses/{expenseId}` (single
  binding for this PR). The groups expense binding
  (`groups/{groupId}/expenses/{expenseId}`) is deferred to Sprint 3 when the
  groups epic begins — see architect notes §2 below.
- **Region:** `asia-south1` (Mumbai). Region-pin per SRS section 7.1.
- **Retry:** v2 trigger options `{retry: true}`. Transient errors
  (INTERNAL, BALANCE_INVARIANT_VIOLATED) throw and Cloud Functions retries.
  Permanent errors (CONTEXT_NOT_FOUND, stale-event) return successfully so
  retries are not triggered.
- **Shared core:** `recomputeAndWrite(deps, {contextType, contextId, alsoSet})`
  in `functions/src/simplified-debts/function.ts`. Returns a typed
  discriminated union `{ok: true, transfers, simplifiedBalances} | {ok: false, code}`.
  The callable (`recomputeSimplifiedBalances`) and the trigger
  (`onExpenseWriteFriendship`) both consume it — algorithm logic stays in
  exactly one place (no fork).
- **Atomicity:** `simplifiedBalances` and `lastActivityAt` are written in the
  SAME `tx.update(contextRef, ...)`. The trigger passes
  `alsoSet: { lastActivityAt: max(existing, eventTimestamp) }` to the core.
- **Test paths:**
  - `functions/test/triggers/on-expense-write/function.test.ts` — boundary
    unit tests (mocked Firestore + logger).
  - `functions/test/firestore-rules/expenses-friendship.test.ts` —
    `@firebase/rules-unit-testing` against emulator.
  - `functions/test/integration/on-expense-write.integration.test.ts` —
    end-to-end via the registered trigger inside
    `firebase emulators:exec --only auth,firestore,functions,storage`.
  - `functions/test/integration/simplified-debts.integration.test.ts` — one
    new smoke test confirming the callable still works post-refactor.

---

## Out of Scope (explicitly deferred — hand-off seams documented in code)

- **Settlements trigger (`onSettlementWrite`).** PR #37 candidate. Different
  document path (`settlements/{settlementId}`), different write semantics
  (settlements affect both `simplifiedBalances` and `verificationStatus`),
  different FCM target. Independent PR.
- **Groups expense trigger binding (`onExpenseWriteGroup`).** Sprint 3 when
  groups exist. The shared `recomputeAndWrite` core supports the groups
  context as a one-line addition, but the deployment binding for
  `groups/{id}/expenses/{id}` is deferred along with the corresponding
  security rules.
- **Activity-feed item writes (`activity/{userId}/items/{itemId}`).** FR-AC-01
  in a later sprint. Hand-off seam: `// TODO(FR-AC-01): write activity item
  here` placed inside the trigger handler immediately after the recompute
  call.
- **FCM push notifications.** FR-AC-03 in a later sprint. Requires the
  notification permission flow, per-user `fcmTokens` plumbing, and the
  `notificationPrefs.newExpense` toggle. Hand-off seam:
  `// TODO(FR-AC-03): send FCM notification here`.
- **Flutter expense-creation UI (FR-EX-01).** Later PR. The trigger ships
  before its first client producer so that when FR-EX-01 lands, balances
  "just work" without any further trigger changes.
- **Any modification to `functions/src/simplified-debts/algorithm.ts`.** The
  pure algorithm is locked (PR #12 covered the canonical 6-case matrix to
  100%). Only `function.ts` may be touched, and only to extract the shared
  `recomputeAndWrite` core (variant 2.3(b)).
- **Any change to the Flutter codebase.** PR #35's `friendsListProvider`
  already reads `simplifiedBalances` and `lastActivityAt`; PR #36 simply makes
  them appear with production-correct values. No Flutter diff is necessary
  or appropriate.

---

## Architect Notes

> Appended for PR #36. These notes ratify the design decisions taken before
> implementation begins. References: `docs/copilot_prompts/sprint_2/5.md`,
> `.github/shared/invariants.md`, `.github/shared/decision-log.md`
> (ADR-0001 simplified debts; ADR-0002 paise integers; ADR-0011 Cloud Functions
> test-pyramid layers).

### 1. Source layout — new module under `functions/src/triggers/`

- **Folder:** `functions/src/triggers/on-expense-write/` (kebab-case, matching
  the existing `lookup-user-by-phone-number/` module precedent — NOT the
  catalogue's Appendix B "Source File Layout" suggestion of
  `triggers/onExpenseWrite.ts` which is from the original v1 design before the
  modular layout was ratified).
- **Files:**
  - `function.ts` — exports `createTriggerHandler(deps)` returning an async
    function that accepts a `FirestoreEvent<Change<DocumentSnapshot> | undefined, {friendshipId: string; expenseId: string}>`. Delegates compute+write to the
    extracted `recomputeAndWrite` shared core (variant 2.3(b); see §3 below).
    The trigger module does NOT own any algorithm logic — only orchestration
    (event-shape parsing, stale-event guard, error-policy mapping, telemetry).
  - `index.ts` — registers the trigger using
    `onDocumentWritten` from `firebase-functions/v2/firestore` with
    `{region: 'asia-south1', document: 'friendships/{friendshipId}/expenses/{expenseId}', retry: true}`.
    Re-exported from `functions/src/index.ts` as `onExpenseWriteFriendship`.
- **Test mirror:**
  - `functions/test/triggers/on-expense-write/function.test.ts` (boundary
    unit tests, mocked Firestore).
  - `functions/test/integration/on-expense-write.integration.test.ts`
    (end-to-end via registered trigger inside `firebase emulators:exec`).
- **`jest.config.js` adjustment:** the existing unit-test roots are
  `<rootDir>/src` and `<rootDir>/test/simplified-debts` and
  `<rootDir>/test/lookup-user-by-phone-number`. PR #36 adds
  `<rootDir>/test/triggers` so the new function.test.ts is discovered.

### 2. Single binding (Option A) — groups binding deferred to Sprint 3

- **Decision:** ship only the friendship binding
  (`friendships/{friendshipId}/expenses/{expenseId}`) in this PR.
- **Rationale:** groups don't exist yet — there are no `groups/{id}` documents
  in production, and `firestore.rules` has no
  `match /groups/{groupId}/expenses/{expenseId}` block. Binding the trigger
  to a non-existent path doesn't break anything but adds a deployment artefact
  and CI test surface for code that has no live producer. When the groups epic
  begins in Sprint 3, PR #38-or-later adds the parallel binding and the
  groups expense security rules.
- **Seam:** the shared `recomputeAndWrite` core already accepts
  `contextType: 'friendship' | 'group'` (inherited from PR #12 — the callable
  always supported both). When the groups binding ships, it's a one-line
  `export const onExpenseWriteGroup = onDocumentWritten({document: 'groups/{groupId}/expenses/{expenseId}', ...}, ...)`
  in a new `triggers/on-expense-write/groups.ts` or as a second export from
  the existing `index.ts`. No refactor needed at PR #38 time.

### 3. Shared core extraction (Variant 2.3(b)) — `recomputeAndWrite` returns a typed result

- The existing `createHandler(deps)` in
  `functions/src/simplified-debts/function.ts` couples three concerns:
  (a) callable input validation, (b) the read-compute-write transaction body,
  and (c) `HttpsError`-shaped failure mapping. PR #36 extracts (b) into a
  reusable function so the trigger and callable both consume it.
- **New shared export:**

  ```typescript
  export interface RecomputeRequest {
    contextType: ContextType;
    contextId: string;
    /**
     * Additional fields to set on the context document in the same
     * tx.update(...) call as `simplifiedBalances`. Used by the trigger to
     * write `lastActivityAt` atomically. The callable passes an empty object
     * (or omits the field) so its behaviour does not change.
     */
    alsoSet?: Record<string, unknown>;
  }

  export type RecomputeResult =
    | {
        ok: true;
        transfers: Transfer[];
        simplifiedBalances: SimplifiedBalancesMap;
      }
    | {
        ok: false;
        code: 'CONTEXT_NOT_FOUND' | 'BALANCE_INVARIANT_VIOLATED';
      };

  export async function recomputeAndWrite(
    deps: Dependencies,
    request: RecomputeRequest,
  ): Promise<RecomputeResult>;
  ```

  - On success, returns the computed transfers and balances. The caller
    (callable wrapper or trigger wrapper) decides what response shape to
    emit and what additional logging to attach.
  - On documented failures (context missing; algorithm detects non-zero
    residual), returns `{ok: false, code}`. The caller decides whether to
    throw (callable: `HttpsError`; trigger BALANCE_INVARIANT_VIOLATED: throw
    a plain `Error` to trigger Cloud Functions retry) or log+return (trigger
    CONTEXT_NOT_FOUND).
  - Unknown errors are NOT caught inside the core — they bubble up so the
    callable can map them to `HttpsError('internal', ..., {errorCode: 'INTERNAL'})`
    and the trigger can let them throw for retry.
- **Why a discriminated union and not exception throw from the core?** The
  trigger and callable have FUNDAMENTALLY different error policies:
  - Callable: every failure becomes an HttpsError so the client SDK receives
    a typed response.
  - Trigger: CONTEXT_NOT_FOUND must NOT throw (retry-storm avoidance);
    BALANCE_INVARIANT_VIOLATED and INTERNAL must throw (Cloud Functions
    retries are the recovery mechanism); transient delivery failures must
    throw (CF retries).
  - A typed union lets each wrapper apply its own error policy without the
    core knowing about CloudEvents or HttpsError.
- **Callable behaviour preservation:** the integration tests at
  `functions/test/integration/simplified-debts.integration.test.ts` continue
  to pass without modification:
  - INVALID_INPUT still thrown by `validateInput` in the callable wrapper.
  - CONTEXT_NOT_FOUND now flows through `recomputeAndWrite` returning
    `{ok: false, code: 'CONTEXT_NOT_FOUND'}`, the wrapper maps it to
    `HttpsError('not-found', ..., {errorCode: 'CONTEXT_NOT_FOUND'})`.
  - BALANCE_INVARIANT_VIOLATED similarly mapped to
    `HttpsError('internal', ..., {errorCode: 'BALANCE_INVARIANT_VIOLATED'})`.
  - INTERNAL (catch-all) still mapped by the wrapper's try/catch around the
    `recomputeAndWrite` call.
  - Logging events (`simplified_debts_compute_started`,
    `simplified_debts_compute_completed`, `simplified_debts_compute_failed`)
    stay in the callable wrapper. The trigger wrapper inherits the same
    logging by also calling them (since the trigger wraps the same core).

### 4. `lastActivityAt` — convert ISO string and apply monotonicity guard

- The CloudEvent's `event.time` is an ISO 8601 string per the
  `firebase-functions/v2/core.d.ts` interface
  (`functions/node_modules/firebase-functions/lib/v2/core.d.ts`).
  Firestore stores it as a string if written directly. The trigger MUST
  convert: `const eventTimestamp = Timestamp.fromDate(new Date(event.time));`.
- **Monotonicity guard.** Cloud Functions delivery is at-least-once AND not
  strictly ordered. If a delayed older event arrives after a newer one,
  blindly overwriting `lastActivityAt` would regress and break the
  PR #35 `friendsListProvider` ordering
  (`lib/features/friends/data/friendship_repository.dart:103` —
  `orderBy('lastActivityAt', descending: true)`).
  - Inside `recomputeAndWrite`, when `alsoSet.lastActivityAt` is present
    and the read snapshot has an existing `lastActivityAt`, the value
    actually written is
    `max(existingLastActivityAt, alsoSetLastActivityAt)`. The trigger
    passes its `eventTimestamp` and the core handles the max.
  - This logic lives in the SHARED core, not the trigger, because:
    (a) the callable could in principle pass `alsoSet.lastActivityAt` too
    in future, and (b) the comparison MUST happen inside the same
    transaction that reads `existingLastActivityAt` to avoid TOCTOU.
  - The core MUST NOT clobber other `alsoSet.*` fields — only
    `lastActivityAt` gets the max treatment. Other fields are passed
    through unchanged (no `alsoSet.*` fields exist today besides
    `lastActivityAt`, but the guard is documented for future maintainers).

### 5. Idempotency — leverages the existing pure-function semantics

- The simplified-debts algorithm is deterministic and idempotent — re-running
  with the same expense state produces the same `simplifiedBalances`. The
  trigger inherits this for free.
- The ONLY new idempotency concern is `lastActivityAt`. Two scenarios:
  - **Same event re-delivered:** the trigger writes
    `max(existing, eventTimestamp)`. If existing already equals or exceeds
    the event's timestamp (because the first delivery already wrote it),
    the second delivery is a no-op for that field. `simplifiedBalances`
    is also re-written with the same value. The Firestore snapshot stream
    may or may not re-fire depending on whether anything in the document
    actually changed (the parent friendship doc is unchanged), but no
    user-visible state regresses.
  - **Different events out of order:** the older event's
    `simplifiedBalances` may overwrite the newer event's. This is BENIGN
    because the algorithm is a pure function of the entire CURRENT expense
    set (read inside the transaction). Both invocations read the same
    expense state and compute the same balances. Only `lastActivityAt`
    needs the monotonicity guard (§4); the rest is naturally idempotent.

### 6. Error semantics and retry policy

- **Re-use existing error codes** from
  `docs/design/07-technical/cloud-functions-error-codes.md` — do NOT invent
  new ones. Specifically:
  - `INVALID_INPUT` — does NOT apply to the trigger (no client input shape
    to validate). The trigger never throws this.
  - `CONTEXT_NOT_FOUND` — the trigger logs
    `simplified_debts_compute_failed { errorCode: 'CONTEXT_NOT_FOUND' }`
    and returns successfully. NO throw, so Cloud Functions does NOT retry.
    Rationale: the friendship doc has been deleted; retries cannot help.
  - `BALANCE_INVARIANT_VIOLATED` — the algorithm detected non-zero residual,
    indicating data corruption (e.g., an expense was written with splits
    that don't sum to the amount — the new security rules forbid this,
    but historical data or admin-SDK paths could exist). The trigger
    logs and THROWS (per `docs/copilot_prompts/sprint_2/5.md` Phase 4
    line 231 and the error catalogue's "Retryable: Yes (after data
    investigation)"). Cloud Functions retries the event; the retries fail
    until on-call investigates and fixes the corrupt source data.
    Alerting on repeated `BALANCE_INVARIANT_VIOLATED` logs is the
    operational signal.
  - `INTERNAL` — any unexpected error (transient Firestore contention,
    deadline exceeded). The trigger throws so Cloud Functions retries
    per the standard transient-error pattern.
- **v2 retry option:** `onDocumentWritten({..., retry: true}, handler)`.
  The catalogue's section 2 mentions "Enabled. The function is deployed
  with `failurePolicy: { retry: {} }`" — that is v1 phrasing. v2 uses
  `retry: true` (see `functions/node_modules/firebase-functions/lib/v2/options.d.ts`).
  Both have the same semantics: failed invocations retry until success
  or the 7-day event-delivery window expires.
- **Stale-event guard:** if `event.time` is older than 7 days, the handler
  returns immediately without writing. This prevents the pathological case
  where a stuck retry queue rewrites balances using a long-stale expense
  delta. Implementation: `if (Date.now() - new Date(event.time).getTime() > 7 * 24 * 60 * 60 * 1000) { logger.warn('expense_trigger_stale_event_dropped', {...}); return; }`.

### 7. New Firestore Security Rules — expenses subcollection sum check

- Rules added under
  `match /friendships/{friendshipId}/expenses/{expenseId}` inside
  `firestore.rules`. Helper functions follow the existing
  `isValidFriendshipCreate()` / `isValidFriendshipUpdate()` precedent.
- **Sum-check approach: bounded enumeration.** Firestore Security Rules
  has no native `fold` or `sum` for arrays. The rule language DOES
  support per-element access (`data.splits[i].sharePaise`) and `size()`.
  The helper enumerates split positions, taking the value only when the
  index is in bounds.
  - **Cap N = 2 for the friendship subcollection.** A friendship has
    exactly 2 members (per the schema `memberIds.size() == 2`); every
    `splits[i].userId` must be in `memberIds`; so splits beyond 2 either
    repeat memberIds (functionally redundant) or fail the member check.
    Capping at 2 keeps the rules evaluator well below the 1000-expression
    limit imposed by the runtime. (An initial draft used N=20 and tripped
    the limit — the test
    `expenses-friendship.test.ts > rejects creation when splits.size() exceeds 2`
    documents the cap.)
  - **Index-out-of-bounds caution:** Firestore rules evaluation throws
    (denies the request) when you access `splits[i]` and `i >= splits.size()`.
    The helper gates each access on `splits.size() > i`:
    ```
    function shareAt(splits, i) {
      return splits.size() > i ? splits[i].sharePaise : 0;
    }
    function sumOfSharesEquals(splits, amount) {
      return shareAt(splits, 0) + shareAt(splits, 1) == amount;
    }
    ```
  - **Pre-condition checks:** `splits is list && splits.size() in 1..2 &&
    each splits[i] is map with userId is string and sharePaise is int and
    sharePaise >= 0`.
  - **Groups subcollection (Sprint 3 — DEFERRED):** when the groups
    binding ships, that rules block will independently choose its
    enumeration depth (likely N=10-20 for group expense splits across
    multiple members). The friendship cap stays at N=2 — it is a tight
    invariant of the friendship schema.
- **Other validations enforced in rules** (matches AC-8 and the schema):
  - `data.keys().hasOnly([...])` and `hasAll([...])` whitelist the exact
    permitted field set (mirrors `isValidUserCreate()`).
  - `amountPaise is int && amountPaise > 0`.
  - `description is string && description.size() <= 200`.
  - `category is string && category in ['food', 'transport', 'utilities', 'entertainment', 'general', 'other']` (covers the SRS category enum + 'general' used by the existing simplified-debts integration test seed).
  - `date is timestamp`.
  - `payerId is string && payerId in parent.memberIds` where parent is
    `get(/databases/$(database)/documents/friendships/$(friendshipId)).data`.
  - `splitMethod in ['equal', 'unequal', 'percentage', 'shares', 'exact']`.
  - `receiptUrl == null || receiptUrl is string` (v1.0: usually `null`).
  - `createdBy == request.auth.uid && createdAt == request.time && updatedAt == request.time`.
  - `deleted == false` on create.
  - **Extension-point locks (per `extension-points-register.md`):**
    `currency == 'INR'`, `source == 'manual'`, `recurringRule == null`.
- **Update rules:** immutable `createdBy`, `createdAt`. Every other field
  may change but the post-update doc must still satisfy ALL invariants
  (sum check, member checks, extension-point locks). Soft-delete is an
  update with `deleted: true`; the sum check still runs after the update,
  so the updated `splits`/`amountPaise` must still be consistent.
- **Delete rule:** `allow delete: if false` — hard delete is admin-only
  (same posture as friendships per PR #32). Soft-delete via update is the
  supported client path.
- **Defence-in-depth in the trigger.** Even with the rules sum check, the
  trigger MUST still detect a `BALANCE_INVARIANT_VIOLATED` result from the
  algorithm (which sums net balances post-computation and asserts zero
  residual). If somehow corrupt data sneaks past the rules (admin SDK seed,
  historical pre-rule data), the trigger throws and Cloud Functions retries
  — alerting reaches on-call. This is BEYOND the rules check, not a
  substitute for it.

### 8. No new ADR required

- Both Option A (single binding) and variant 2.3(b) (extracted core function)
  fall within existing precedent — ADR-0001 (simplified debts as the sole
  debt mechanism), ADR-0002 (paise integers), ADR-0011 (Cloud Functions
  test-pyramid layers). The shared core extraction is a code-organisation
  refactor, not an architectural change.
- The trigger's `{retry: true}` deployment option is a Cloud Functions
  configuration detail, not architectural. The 7-day stale-event guard is
  documented in this story.

### 9. Coverage gate posture

- `functions/src/triggers/on-expense-write/**` is a NEW module folder under
  the per-module 70% gate. Function-boundary tests must cover create/update/
  soft-delete/hard-delete/idempotency/stale-event/CONTEXT_NOT_FOUND/
  BALANCE_INVARIANT_VIOLATED/PII-guard branches to clear it.
- `functions/src/simplified-debts/**` may regress slightly due to the
  refactor (the existing handler now delegates to `recomputeAndWrite`).
  Branch coverage is advisory but must not regress in a way that hides
  uncovered paths. The existing function.test.ts must continue to pass
  unmodified (the wrapper's input validation, logging order, error
  mapping, and persistence are unchanged); new branch coverage from the
  trigger's exercise of the shared core may close the bucket-B CV3 item
  ("Functions `function.ts` branch coverage at 76% when expense triggers
  wired").
- The Flutter side has no diff in this PR. The Flutter per-feature gate is
  unaffected.

### 10. DevOps — CI workflow update

- The PR pipeline currently runs (from `.github/workflows/pr.yml`):
  ```
  firebase emulators:exec --only auth,firestore,functions,storage \
    "flutter test test/integration/ --timeout 300s && cd functions && npm run test:rules"
  ```
- The Functions emulator is started, but `npm run test:integration` is NOT
  invoked. For PR #36 the trigger registration MUST be proven
  end-to-end — the trigger must actually fire from the registered handler,
  not just be invoked via dependency injection.
- **Workflow change required:**
  - Build the Functions package BEFORE `emulators:exec` so the emulator
    loads the compiled JS from `functions/lib/`. Add a step:
    ```
    - name: Build Cloud Functions
      run: cd functions && npm run build
    ```
  - Append `npm run test:integration` to the `emulators:exec` command:
    ```
    firebase emulators:exec --only auth,firestore,functions,storage \
      "flutter test test/integration/ --timeout 300s \
       && cd functions \
       && npm run test:rules \
       && npm run test:integration" \
      --project demo-onebytwo
    ```
- The existing simplified-debts integration test at
  `functions/test/integration/simplified-debts.integration.test.ts` will
  run unchanged inside this new step. The new trigger integration test
  joins it under the same `jest.integration.config.js`.

