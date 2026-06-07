# FR-EX-07: Activity Feed Write-Side Emission (Friendship Expenses)

> Implementation-ready user story for the **first writer of the
> `activity/{userId}/items/{itemId}` collection** in the OneByTwo
> application. Extends the existing `onExpenseWriteFriendship` Firestore
> trigger (the friendship expense trigger) so that every successful
> recompute fans out **two activity-feed documents** — one into each
> friendship member's per-user activity subcollection — with a typed
> payload that captures the user-visible change (`expense_added`,
> `expense_edited`, or `expense_deleted`). Ships the canonical
> `activity/{userId}/items/{itemId}` Firestore Security Rules block
> (member-read, server-only-write) for the first time, mirroring the
> `simplifiedBalances` server-only enforcement pattern. The client
> read-side (SCR-25 — Activity tab) is the natural follow-on story
> (FR-AC-01) and is explicitly out of scope; this story is server-only,
> expense-trigger only, friendship-only. Closes the long-standing
> `// TODO(FR-AC-01): write activity-feed item` hand-off seam at
> `functions/src/triggers/on-expense-write/function.ts` and makes the
> schema doc's `activity/{userId}/items` row enforceable for the first
> time.

---

## SRS Requirement ID(s)

FR-EX-07 (SRS section 4.5 line 212 — "Each edit or delete shall be
recorded in the activity feed with author and timestamp"; this story
extends to creates for symmetry with SCR-25 Event Type Mapping),
FR-AC-01 (SRS section 4.7 lines 236-240 — write-side prerequisite for
the Activity tab; the client read-side is the FR-AC-01 P0 story
shipping in a follow-on PR).

## Relevant SRS Sections

- Section 4.5 — Expenses (FR-EX-07 audit trail of edits and deletes)
- Section 4.7 — Activity Feed (FR-AC-01 schema dependency)
- Section 5.4 — Privacy and PII handling
- Section 5.10 — Observability (new structured-log event names)
- Section 7.1 — Cloud Functions runtime (region pinning, retry semantics)
- Section 7.2 — Firestore schema (`activity/{userId}/items/{itemId}`)
- Section 7.3 — Key architectural decisions (Invariants 1 + 2)
- Section 7.5 — Security rules (new `activity/**` predicates)

## Priority

**P0 — Must have.** The activity feed is a Core Screen (SRS section
6.3 item 10). The client read-side (SCR-25 — Activity tab) is a P0
follow-on story; shipping the write-side first means the moment the
client read-side lands, every existing friendship-expense write
already has activity items to render. Shipping in reverse order
(read-side first) would force the client to display an empty feed
for every historical expense.

## Story Points

**5.** Trigger extension + new activity-writer module + new payload-
builder module + 12-test rules suite + 8-test trigger unit suite + 3-test
functions integration extension + new rules predicate + schema
validator + structured logging + boundary-contract grep extension.
Patterns from the existing expense-trigger module (PR-#36-shipped
shared core + structured-log + PII guard) are ratified; this story
reuses, does not re-derive.

## User Story

As a **member of a friendship**,
I want **every expense create, edit, and soft-delete in our friendship to
automatically produce a feed item under my user's activity subcollection
(and under my friend's)**,
so that **the future Activity tab can render a chronological feed of
everything that touched our shared finances without any client-side
orchestration, and so that the audit history requirement (FR-EX-07) is
satisfied with author and timestamp on every change**.

## Preconditions

1. A friendship document exists at `friendships/{fid}` with valid
   `memberIds` (two sorted UIDs).
2. The `onExpenseWriteFriendship` trigger is deployed to `asia-south1`
   (Mumbai) per SRS section 7.1 and is the sole producer of
   `simplifiedBalances` for friendships (FR-SE-03/04).
3. The Firebase Emulator Suite is available for pre-merge integration
   testing (Firestore on port 8181, Functions on port 5001 per
   `firebase.json`).
4. The expense write originates from a member authenticated by the
   client under the existing `friendships/{fid}/expenses/{eid}`
   security rules.
5. The `activity/{userId}/items` Firestore Security Rules block does
   NOT yet exist; the default-deny at `match /{document=**}` is the
   only guard. This story is the first writer (server-side) of this
   path tree.

---

## Acceptance Criteria

### Trigger emission — positive ACs

#### AC-1 — Create writes an `expense_added` activity item to BOTH members

> Given a friendship `friendships/{fid}` with
> `memberIds: ['uidA', 'uidB']`
> And the `onExpenseWriteFriendship` trigger is live
> When a new expense is created at `friendships/{fid}/expenses/{eid}`
> (via the client repository in production, or via admin SDK in the
> trigger integration test)
> Then TWO activity items are written:
> - one at `activity/{uidA}/items/{auto-id}`
> - one at `activity/{uidB}/items/{auto-id}`
> And each has `type: 'expense_added'`
> And each has `payload: { expenseId, friendshipId, description, amountPaise, payerId, splits, category, splitMethod, hasReceipt, authorUid }`
> And each has `createdAt: <server timestamp>` (Firestore-side
> `FieldValue.serverTimestamp()`, NOT the trigger's `event.time` —
> Architect Notes §2.6 rationale)
> And both writes happen AFTER the `recomputeAndWrite` success branch.

#### AC-2 — Edit writes an `expense_edited` activity item to BOTH members

> Given an existing non-deleted expense
> When the expense is updated (any field — amount, description,
> category, date, payer, splits, splitMethod, OR `receiptUrl`)
> Then TWO `expense_edited` activity items are written
> And each has `payload` including the `changedFields` array (field
> names that differ between `change.before` and `change.after`) PLUS
> the same base fields as `expense_added`
> And the receipt-only update path (PR-#48-shipped) DOES fire an
> `expense_edited` activity item — per the SCR-25 spec at lines
> 305-307 which explicitly enumerates `expenseEdited` for "any field
> change"; a receipt attach is a legitimate edit from the user's
> perspective and the deferred trigger no-op-recompute optimisation
> (issue #50) must NOT skip the activity emission.

#### AC-3 — Soft-delete writes an `expense_deleted` activity item to BOTH members

> Given an existing non-deleted expense
> When the expense is soft-deleted (`deleted: false → true` per
> FR-EX-06)
> Then TWO `expense_deleted` activity items are written
> And each has `payload: { expenseId, friendshipId, description, amountPaise, category, authorUid, deletedAt }`
> And the snapshot of `{ description, amountPaise, category }` is
> captured from `change.before.data()` so the future SCR-25 row can
> render the description even if the expense document is hard-deleted
> in some future cleanup.

#### AC-4 — Author UID is captured in the payload

> Given any of the three trigger events (create, edit, soft-delete)
> When the activity item is written
> Then `payload.authorUid` equals the `createdBy` field of the source
> expense (for create and edit) OR the `createdBy` of the
> pre-delete snapshot (for soft-delete; symmetric because soft-delete
> is rules-gated to the creator under the existing expense-update
> predicates).

#### AC-5 — Activity write happens AFTER the recomputeAndWrite success branch

> Given a transient `recomputeAndWrite` failure (network error,
> transaction abort, BALANCE_INVARIANT_VIOLATED, or INTERNAL)
> When the trigger handler runs
> Then NO activity items are written for the failed branch
> And the retry on the next trigger invocation handles both the
> recompute AND the activity emission together
> And on `CONTEXT_NOT_FOUND` (friendship deleted), NO activity items
> are written either (the friendship is gone — there is no member to
> notify).

### Rules ACs — negative-guard load-bearing

#### AC-6 — Authenticated owner can read their own activity items

> Given the new `activity/{userId}/items/{itemId}` predicate block
> in `firestore.rules`
> When `uidA` (authenticated) reads
> `activity/{uidA}/items/{seeded-item-id}`
> Then the read succeeds.

#### AC-7 — Non-owner cannot read another user's activity items

> Given the new predicate block
> When `uidB` (authenticated) attempts to read
> `activity/{uidA}/items/{seeded-item-id}`
> Then the read fails with `permission-denied`.

#### AC-8 — Unauthenticated read is rejected

> Given the new predicate block
> When an anonymous (unauthenticated) client reads
> `activity/{uidA}/items/{seeded-item-id}`
> Then the read fails with `permission-denied`.

#### AC-9 — Client cannot create an activity item

> Given the new predicate block
> When `uidA` (authenticated) attempts to create
> `activity/{uidA}/items/{client-chosen-id}` with a valid-looking
> payload
> Then the write fails with `permission-denied`
> And only the Cloud Functions service account (admin SDK,
> rules-bypassing) may write.

#### AC-10 — Client cannot update an activity item

> Given an existing seeded activity item at
> `activity/{uidA}/items/{seeded-id}`
> When `uidA` attempts an `update()` on the item
> Then the write fails with `permission-denied`.

#### AC-11 — Client cannot delete an activity item

> Given an existing seeded activity item at
> `activity/{uidA}/items/{seeded-id}`
> When `uidA` attempts a `delete()` on the item
> Then the write fails with `permission-denied`.

#### AC-12 — Reading the parent `activity/{userId}` document is rejected

> Given the parent activity document at `activity/{uidA}` has no
> semantic content (only the subcollection is the read surface)
> When `uidA` attempts to read `activity/{uidA}` directly
> Then the read fails with `permission-denied` (defence-in-depth —
> the parent doc has its own explicit `allow read, write: if false`
> rather than relying solely on the default-deny match).

### Idempotency and retry — positive ACs

#### AC-13 — Duplicate trigger invocations do NOT duplicate activity items beyond the stale-event window

> Given the trigger has already written activity items for the
> `expense_added` of `eid-1`
> When the trigger fires a SECOND time for the same `eid-1` event
> with the same `event.time` (e.g. Cloud Functions at-least-once
> redelivery within the 7-day window)
> Then idempotency is INHERITED from the existing stale-event drop
> at `function.ts:140-157` for events older than 7 days, and from
> the natural pure-function semantics of `recomputeAndWrite` for
> in-window redeliveries (the activity-writer is gated by the same
> success branch — a redelivery that succeeds at the recompute layer
> will also re-emit activity items)
> And full deduplication (deterministic activity-item IDs) is
> deferred to FUTURE work — per Architect Notes §2.5, the architect-
> ratified posture is "if the trigger fires for an event the handler
> has already processed within the stale-event window, the activity-
> write fires too; full dedup is FUTURE work and is acceptable v1.0
> behaviour symmetric with the rest of the trigger's posture".

### Cross-cutting and negative ACs

#### AC-14 — Telemetry / structured-log PII guard

> Given any of the new structured-log events fires
> (`activity_item_written`, `activity_item_write_failed`,
> `activity_emission_completed`)
> When the log line is emitted
> Then every UID-derived parameter is the SHA-256-truncated hash via
> `hashId()` from `functions/src/utils/id-hash.ts` (16 hex chars)
> And NEITHER the raw `friendshipId` composite NOR raw member UIDs
> NOR the raw expense ID appear in any log line
> And the activity-writer unit test asserts this contract using a
> realistic `{uidA}_{uidB}` friendship-id value (mirrors the
> `function.test.ts` PII guard ratified in PR #36).

#### AC-15 — Invariant 2 negative guard

> Given the PR diff
> When scanned for new writes to `simplifiedBalances`
> Then ZERO new writes exist anywhere outside the existing
> `recomputeAndWrite` path
> And the activity-writer writes ONLY to
> `activity/{userId}/items/{auto-id}`
> And the existing `simplifiedBalances` server-only enforcement
> (Invariant 2) is unaffected.

#### AC-16 — Invariant 1 boundary contract (Functions-side)

> Given the PR diff
> When scanned for `.toDouble()`, `parseFloat`, `parseFloat(...)`,
> `Number.parseFloat`, `.toFixed`, `/ 100`, `/ 100.0`, or
> floating-point arithmetic on any monetary field
> Then ZERO violations exist on the activity-payload path
> And the new Functions-side boundary-contract grep at
> `functions/test/boundary-contracts/no-double-on-money-fields.test.ts`
> (architect-ratified at §2.x; recommended; parallel to the Flutter-
> side grep at `test/features/expenses/expense_creation_boundary_contract_test.dart`)
> returns 0 violations across `functions/src/**/*.ts`.

#### AC-17 — Integration test extension

> Given the PR diff
> When `functions/test/integration/on-expense-write.integration.test.ts`
> is inspected
> Then THREE new round-trip tests exist covering the activity-write
> contract end-to-end through the registered trigger inside
> `firebase emulators:exec --only auth,firestore,functions,storage`:
> 1. create-then-read for both members
> 2. edit-then-read for both members
> 3. soft-delete-then-read for both members
> And each round-trip asserts the per-member activity-item count
> AND the `type` AND key payload fields.

#### AC-18 — Schema validator extension

> Given the PR diff
> When the schema-validators module (`functions/src/schema-validators.ts`
> if it exists, OR a new sibling module per architect's call at §2.x)
> is inspected
> Then a `validateActivityPayload(type, payload)` helper exists that
> asserts:
> - `type` is in the enumeration
>   `{ 'expense_added', 'expense_edited', 'expense_deleted' }`
> - `payload` is a plain object
> - per-type required fields are present (e.g. `expense_added` requires
>   `expenseId`, `friendshipId`, `description`, `amountPaise`, `payerId`,
>   `splits`, `category`, `splitMethod`, `hasReceipt`, `authorUid`;
>   `expense_edited` additionally requires `changedFields`;
>   `expense_deleted` additionally requires `deletedAt`)
> And the activity-writer calls the validator before the Firestore
> write to catch programmer errors at runtime that the TypeScript
> compiler cannot (e.g. a hand-constructed payload missing
> `payerId`).

---

## Telemetry Events

Server-side structured logging via `firebase-functions/logger` (NOT
client Firebase Analytics). All events are PII-free per SRS section
5.4 and ADR-0013. Friendship IDs (`{uidA}_{uidB}` composite), expense
IDs, and recipient UIDs are hashed via `functions/src/utils/id-hash.ts`
(`hashId()` — SHA-256 truncated to 16 hex chars) before logging.

| Event name | Parameters | Trigger |
|---|---|---|
| `activity_item_written` | `contextType: 'friendship'`, `contextIdHash: string` (16 hex), `expenseIdHash: string` (16 hex), `authorUidHash: string` (16 hex), `recipientUidHash: string` (16 hex), `eventType: 'expense_added' \| 'expense_edited' \| 'expense_deleted'`, `payloadSizeBytes: number` | Emitted per successful per-member activity-item write. Two emissions per trigger invocation in the success path (one per member). The `payloadSizeBytes` is a defence-in-depth log of the document size; an unexpectedly large payload indicates a programmer error. |
| `activity_item_write_failed` | Same as above PLUS `errorCode: 'permission-denied' \| 'unavailable' \| 'unknown'` | Emitted per failed per-member activity-item write. The writer does NOT rethrow the failure; the trigger's success branch is preserved (the failure is contained per architect §2.9 item 2). |
| `activity_emission_completed` | `contextType: 'friendship'`, `contextIdHash: string`, `expenseIdHash: string`, `eventType: 'expense_added' \| 'expense_edited' \| 'expense_deleted'`, `membersSucceeded: number`, `membersFailed: number` | Emitted ONCE per trigger invocation summarising the per-member write outcomes. Useful for the dashboards to compute the activity-emission success rate without re-aggregating the per-write events. |

Note: the existing trigger-pathway events (`expense_trigger_fired`,
`expense_trigger_stale_event_dropped`, `simplified_debts_compute_started`,
`simplified_debts_compute_completed`, `simplified_debts_compute_failed`)
are UNCHANGED in name, parameter set, and placement; the new
activity-emission events are additive only.

**Strict PII guard:** the structured logger NEVER receives `payerId`,
`splits[].userId`, `amountPaise`, `sharePaise`, `description`, or any
raw UID-containing identifier (including the unhashed `friendshipId`,
unhashed `expenseId`, or unhashed `authorUid` / `recipientUid`).
Only opaque hash values and `eventType` discriminators are loggable.
A new `activity-writer.test.ts` PII guard explicitly asserts this
contract using a realistic `{uidA}_{uidB}` friendship-id value.

---

## Invariant Applicability Assessment

| # | Invariant | Applicability |
|---|---|---|
| 1 | Money is integer paise | **N/A on the activity-write path itself.** The `payload.amountPaise` (and `payload.splits[].sharePaise`) values are read straight from the source expense document without arithmetic; the integer invariant is preserved by construction. The new Functions-side boundary-contract grep at `functions/test/boundary-contracts/no-double-on-money-fields.test.ts` (architect-ratified at §2.x) is defence-in-depth — it greps `functions/src/**/*.ts` for `.toDouble()`, `parseFloat`, `/100`, and float-typed monetary field declarations, ensuring future maintainers cannot accidentally introduce float arithmetic on the activity-payload path. |
| 2 | `simplifiedBalances` server-maintained | **Applicable — defence-in-depth.** The activity-writer writes ONLY to `activity/{userId}/items/{auto-id}`; ZERO new writes to `simplifiedBalances` anywhere. The existing `recomputeAndWrite` is unchanged in this PR. AC-15 is the explicit negative-guard test. |
| 3 | System share sheet only | N/A. This story has no client UI and no outbound sharing surface. |
| 4 | Single Firebase project | **Applicable.** The new Firestore rules block targets the single production project. Integration tests run against the single Firebase Emulator Suite via `scripts/dev/start-emulators.sh` and `firebase emulators:exec`. `.firebaserc` is unchanged. |

PII / ADR-0013 compliance: the activity-writer module emits THREE new
structured-log events (`activity_item_written`,
`activity_item_write_failed`, `activity_emission_completed`); every
UID-derived parameter (`contextIdHash` from `friendshipId`,
`expenseIdHash`, `authorUidHash`, `recipientUidHash`) is
SHA-256-truncated via the existing `hashId()` helper. The activity
**payload** itself is NOT subject to ADR-0013 because the payload
ships inside Firestore where the user has read access to their own
activity items (per AC-6); the rules block in this PR enforces the
"own items only" read predicate.

---

## Definition of Done

Reference: `docs/design/08-plan/definition-of-ready-and-done.md`

- [ ] Code merged to `main` via approved PR.
- [ ] Cloud Functions trigger extension deployed in-place to
      `asia-south1` (Mumbai) — verified via the manual smoke matrix
      in the PR body.
- [ ] New Firestore rules block deployed via
      `firebase deploy --only firestore:rules`.
- [ ] Function-boundary unit tests passing (mocked Firestore, no
      emulator needed) — at least 8 new tests in
      `functions/test/triggers/on-expense-write/activity-writer.test.ts`
      and at least 3 new assertions in the existing
      `functions/test/triggers/on-expense-write/function.test.ts`
      (activity-writer called from the trigger; activity-writer NOT
      called on the stale-event-drop branch; activity-writer NOT
      called on the CONTEXT_NOT_FOUND branch).
- [ ] Payload-builder unit tests passing — at least one per event
      type covering the `(changeType, before, after)` → payload
      mapping.
- [ ] Security-rules unit tests passing against the Firestore
      emulator on port 8181 (`npm run test:rules`) — 12+ new tests
      in `functions/test/firestore-rules/activity.test.ts` covering
      AC-6 through AC-12.
- [ ] Integration tests passing against the Firebase Emulator Suite
      (`npm run test:integration` inside
      `firebase emulators:exec --only auth,firestore,functions,storage`)
      — 3 new round-trip assertions per AC-17.
- [ ] Functions-side boundary-contract grep (architect-ratified per
      §2.x) returns 0 violations.
- [ ] QA manual smoke matrix completed and signed off (Phase 5 step
      10 of `docs/copilot_prompts/sprint_2/14.md`).
- [ ] Telemetry events in place and PII-free (verified by the new
      `activity-writer.test.ts` PII guard).
- [ ] Invariant compliance confirmed (Invariants 2 + 4 applicable;
      Invariant 1 N/A on the activity payload; boundary-contract
      grep is defence-in-depth).
- [ ] Coverage gate green (Functions overall ≥ 50%; new
      activity-writer module ≥ 70%; existing
      `simplified-debts/` and `triggers/on-expense-write/function.ts`
      not regressed).
- [ ] Documentation updated: `sprint-2-plan.md` (PR #51 row, 5 SP,
      cumulative 55 SP / 15 PRs); `next-three-prs.md` (PR #52 / #53 /
      #54 candidates); `07-bucket-b-burndown.md` (R5a closed).
- [ ] No open S1 or S2 bugs.

---

## Invariant Compliance

- [ ] Invariant 1 (paise): N/A on the activity-write path itself
      (no monetary arithmetic; values are passed through from the
      source expense document). The new Functions-side
      boundary-contract grep is defence-in-depth and returns 0
      violations across `functions/src/**/*.ts`.
- [ ] Invariant 2 (`simplifiedBalances` server-only): the existing
      single-writer enforcement is unchanged. ZERO new writes to
      `simplifiedBalances` in the PR diff (AC-15 is the explicit
      negative-guard test).
- [ ] Invariant 3 (system share sheet only): N/A in this story.
- [ ] Invariant 4 (single Firebase project): compliant — production
      only, with emulator-backed pre-merge verification.

---

## Design Artefact References

| Artefact | Path |
|---|---|
| Firestore schema (`activity/{userId}/items/{itemId}`) | `docs/design/07-technical/firestore-schema.md` lines 194-211 |
| Firestore security rules (canonical posture) | `docs/design/07-technical/firestore-security-rules.md` |
| Cloud Functions catalogue (`onExpenseWriteFriendship`) | `docs/design/07-technical/cloud-functions-catalogue.md` |
| Cloud Functions error codes | `docs/design/07-technical/cloud-functions-error-codes.md` |
| Screen spec — Activity Feed (SCR-25) | `docs/design/06-screen-specs/23-28-settle-activity-profile.md` lines 256-386 |
| Existing trigger handler (PR #36) | `functions/src/triggers/on-expense-write/function.ts` |
| Existing trigger story (PR #36) | `docs/sprint-zero/stories/FR-SE-03-04-expense-trigger-friendship.md` |
| Symmetric settlement trigger (PR #43-shipped, PR #52 activity-emission candidate) | `functions/src/triggers/on-settlement-write/function.ts` |
| ADR — PII / telemetry hashing | `.github/shared/decision-log.md` ADR-0013 |
| Feature-PR conventions | `docs/patterns/feature-pr-conventions.md` |

---

## Responsible Agents

| Agent | Responsibility |
|---|---|
| PM | Story authorship, AC clarity, scope discipline (no widening to SCR-25 read-side, FCM, settlement-trigger activity emission, group-trigger activity emission, or any FR-AC-XX P0 story; those are separate stories). |
| Architect | Activity-writer module extraction decision, payload schema per event type, idempotency posture, structured-log event names, scope guardrails, anticipated reconciliations. |
| Cloud Functions Dev | Activity-writer + payload-builder module implementation, trigger handler extension, security-rules block, function-boundary tests, payload-builder tests, rules tests, integration extension. |
| DevOps | No new CI workflow changes; the new rules tests run in the existing dedicated `firebase emulators:exec --only firestore,storage` session; the new trigger unit tests run inline under `npm test`; the new trigger integration tests run inline under `npm run test:integration` inside the existing full-emulator session. |
| QA | Manual smoke matrix sign-off (Phase 5 step 10), DoD §3 sign-off with emulator-log evidence for: (a) member can read own activity items; (b) non-member receives `permission-denied`; (c) client write attempt receives `permission-denied`; (d) trigger fires and writes both members' activity items end-to-end on create / edit / soft-delete. |

---

## Technical Notes

- **Trigger entry-point:** `functions/src/triggers/on-expense-write/function.ts`
  is extended in place. The new activity-write call lives AFTER the
  successful `recomputeAndWrite` branch at the bottom of the handler,
  per the existing TODO comment block (`function.ts:160-169`).
- **Region:** `asia-south1` (Mumbai). The trigger is already
  registered there; this PR is an in-place handler extension.
- **Retry:** The trigger's existing `{retry: true}` posture is
  unchanged. Activity-write failures are CONTAINED inside the
  activity-writer's own try/catch (per Architect Notes §2.9 item 2) —
  a per-member activity-write failure does NOT propagate to the
  trigger's success branch, so Cloud Functions does NOT retry the
  whole trigger on activity-write failures. Failures are logged via
  `activity_item_write_failed`.
- **Two writes per invocation:** the activity-writer writes ONE
  document per friendship member. For the two-person friendship
  context, that is exactly TWO documents per trigger invocation.
  The writes are issued in parallel via `Promise.all`. An orphan
  asymmetric state (one member's item written, the other failed) is
  acceptable v1.0 behaviour per Architect Notes §2.9 item 3.
- **Idempotency:** see Architect Notes §2.5. The activity-writer
  inherits the existing stale-event drop at `function.ts:140-157`;
  in-window redeliveries do duplicate items (acceptable v1.0
  behaviour symmetric with the rest of the trigger's posture).
- **Test paths:**
  - `functions/test/triggers/on-expense-write/activity-writer.test.ts`
    — unit tests for the writer module (mocked Firestore).
  - `functions/test/triggers/on-expense-write/payload-builder.test.ts`
    — unit tests for the pure mapping function.
  - `functions/test/triggers/on-expense-write/function.test.ts`
    — EXTEND with assertions that the activity-writer is invoked from
    the trigger on the success branch and NOT invoked on the
    stale-event-drop or CONTEXT_NOT_FOUND branches.
  - `functions/test/firestore-rules/activity.test.ts` — rules tests
    against the Firestore emulator on port 8181 covering AC-6 through
    AC-12.
  - `functions/test/integration/on-expense-write.integration.test.ts`
    — EXTEND with 3 new round-trip tests per AC-17.
  - `functions/test/boundary-contracts/no-double-on-money-fields.test.ts`
    — NEW (architect's call at §2.x; recommended). Parallel to the
    Flutter-side grep.

---

## Out of Scope (explicitly deferred — hand-off seams documented in code)

- **Client read-side SCR-25 (Activity tab).** Separate FR-AC-01 P0
  story. The read-side schema PR #51 ships is the contract a
  follow-on PR will consume.
- **Settlement-trigger activity emission.** `functions/src/triggers/on-settlement-write/function.ts:231`
  has the symmetric TODO. Paired with FR-AC-01 client read-side in a
  follow-on PR — both halves are needed for the settlement leg of
  the SCR-25 feed to render anything useful. The activity-writer
  module shipped in this PR is REUSABLE by that follow-on PR with a
  sibling settlement-payload builder.
- **Group-context expense activity emission.** Sprint 3 groups epic
  (FR-EX-02 + the `onExpenseWriteGroup` trigger).
- **FR-AC-03 FCM push notifications.** Separate P0 story; introduces
  the FCM dependency + the `notificationPrefs` schema + the
  per-user `fcmTokens` plumbing.
- **FR-AC-04 notification preferences.** Paired with FR-AC-03.
- **FR-AC-05 cold-start deep-link.** Paired with FR-AC-01 (client
  deep-link routing).
- **Activity-item pagination / cursor-based read.** Paired with
  FR-AC-01 (SCR-25 Open Question 2).
- **Read/unread markers.** FR-AC-01 Open Question 1; v1.1 candidate
  per the SCR.
- **Activity-item filter / search.** FR-AC-01 Open Question 3;
  deferred per the SCR.
- **Full activity-item deduplication (deterministic IDs).** Per
  Architect Notes §2.5, the activity-writer inherits the existing
  stale-event drop; in-window redeliveries do duplicate items.
  Acceptable v1.0 behaviour symmetric with the rest of the
  trigger's posture; full dedup is FUTURE work to file as an issue
  if observed in production.
- **Issue #47 — Firestore rules-hardening for non-creator
  update/delete.** Separate small chore PR.
- **Issue #49 — Orphan-cleanup Cloud Function for receipts.** FUTURE.
- **Issue #50 — Trigger no-op-recompute optimisation.** EXPLICITLY
  REFUSED for bundling — the optimisation would BREAK FR-EX-07 by
  skipping the activity emission on receipt-only updates (per AC-2
  the receipt-only update MUST fire an `expense_edited` activity
  item). A follow-up update to issue #50 will reflect this
  constraint.
- **Activity-orphan reconciliation function.** A member-write failure
  where the other member's write succeeded leaves an asymmetric
  activity feed. Acceptable v1.0 per architect §2.9 item 3. Future
  work would file a reconciliation function similar to the
  orphan-receipts cleanup (issue #49 precedent).
- **Concurrent-edit detection for FR-EX-06.** Still deferred per PR
  #46 §2.4.
- **Rate-limit transaction race refactor.** PR #45 §2.2 deferred.

---

## Architect Notes

> _To be appended in Phase 2 by the Architect agent. See
> `docs/copilot_prompts/sprint_2/14.md` Phase 2 (§2.1–§2.9) for the
> ratification checklist._
