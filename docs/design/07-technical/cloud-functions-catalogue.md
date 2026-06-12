# Cloud Functions Catalogue

> **Document version:** 1.1
> **Status:** Current (reconciled with deployed code under `functions/src/`)
> **Region:** All functions are deployed to `asia-south1` (Mumbai) per SRS section 5.2.
> **Runtime:** Node 22, TypeScript, strict mode enabled. (Upgraded from Node 20 in PR #44 ahead of the 2026-10-31 Cloud Functions Gen 2 decommission cutoff; `firebase-functions` SDK upgraded to `^7.0.0` in the same PR.)
> **Authoritative source:** `docs/OneByTwo_Requirements_Spec.md` v1.1, reconciled with `functions/src/index.ts`.

This catalogue documents the **six** Cloud Functions currently exported from
`functions/src/index.ts`. Functions specified in earlier drafts but not yet
implemented are listed under [Deferred Functions](#deferred-functions). Shared
server-side code that is not itself a deployed function is described under
[Shared Module: notifications](#shared-module-notifications).

---

## Table of Contents

1. [healthcheck](#1-healthcheck)
2. [recomputeSimplifiedBalances](#2-recomputesimplifiedbalances)
3. [onExpenseWriteFriendship](#3-onexpensewritefriendship)
4. [onSettlementWrite](#4-onsettlementwrite)
5. [sendReminderNotification](#5-sendremindernotification)
6. [lookupUserByPhoneNumber](#6-lookupuserbyphonenumber)

- [Deferred Functions](#deferred-functions)
- [Shared Module: notifications](#shared-module-notifications)
- [Appendix A: Deployment Summary](#appendix-a-deployment-summary)
- [Appendix B: Source File Layout](#appendix-b-source-file-layout)
- [Appendix C: Cross-References](#appendix-c-cross-references)

---

## Conventions

- All monetary values are integer **paise** (1 INR = 100 paise). Floats are never
  used for money. (SRS section 7.3; Invariant 1.)
- `simplifiedBalances` is written **exclusively** by `recomputeAndWrite` in
  `functions/src/simplified-debts/function.ts` — the shared core invoked by the
  `recomputeSimplifiedBalances` callable, the `onExpenseWriteFriendship` trigger,
  and the `onSettlementWrite` trigger. Clients may read but never write this field.
  (SRS sections 4.6, 7.3, 7.5; Invariant 2.)
- Deterministic output: when creditors or debtors tie on absolute value, ties are
  broken by ascending `userId`. (SRS section 7.4.)
- Per-function folder layout: each function lives in its own directory under
  `functions/src/<name>/` with an `index.ts` (the region-pinned trigger
  registration), a `function.ts` (the dependency-injected handler factory), and
  any `algorithm.ts` / helper modules. The healthcheck is the sole exception — it
  is defined inline in `functions/src/index.ts`.
- Region pinning uses the Cloud Functions v2 options object, e.g.
  `onCall({ region: "asia-south1" }, handler)` and
  `onDocumentWritten({ region: "asia-south1", document: "...", retry: true }, handler)`.
- PII in logs: composite identifiers (friendship IDs are `{uidA}_{uidB}`) are
  hashed via `hashId` (`functions/src/utils/id-hash.ts`, SHA-256 truncated to 16
  hex characters) before they are logged. Raw phone numbers are never logged.

---

## 1. healthcheck

### Purpose

Returns a JSON payload confirming the functions runtime is operational and reports
the deployment region. Used by CI and monitoring to verify deployment health.

### Trigger type

**HTTPS Request** (`onRequest`). Defined inline in `functions/src/index.ts` (it has
no per-function folder).

### Input contract

None. Any HTTP method reaching the endpoint produces the same response.

### Output contract

```json
{ "ok": true, "region": "asia-south1" }
```

Responds with HTTP 200 and the JSON body above. The `region` value is the module
constant `REGION = "asia-south1"`.

### Idempotency strategy

Pure read with no side effects; safe to call any number of times.

### Error semantics

None defined; the handler always returns 200.

### Region

`asia-south1`

---

## 2. recomputeSimplifiedBalances

### Purpose

Reads all non-deleted expenses and settlements for a given context (friendship or
group), executes the simplified-debts algorithm (SRS section 7.4), and writes the
resulting `simplifiedBalances` map to the context document inside a Firestore
transaction. This is the sole writer of `simplifiedBalances`. (SRS sections 4.6
FR-SE-03, FR-SE-04; Invariant 2.)

### Trigger type

**HTTPS Callable** (`onCall`, `functions/src/simplified-debts/index.ts`). The
callable wraps the shared `recomputeAndWrite` core. The same core is also invoked
by the `onExpenseWriteFriendship` and `onSettlementWrite` triggers, so the three
entry points always produce identical balances from the same underlying data. The
pure algorithm (`simplifyDebts`, `projectToBalancesMap`) is independently
unit-tested (see `functions/test/simplified-debts/`).

### Input contract

```typescript
/** Context identifying the friendship or group whose balances must be recomputed. */
interface RecomputeRequest {
  /** Discriminator: whether the context is a friendship or a group. */
  contextType: 'friendship' | 'group';

  /**
   * The Firestore document ID of the friendship or group.
   * Path resolved as:
   *   friendship -> `friendships/{contextId}`
   *   group      -> `groups/{contextId}`
   */
  contextId: string;
}
```

### Output contract

Writes the `simplifiedBalances` field on the context document. The field shape is:

```typescript
/**
 * Nested map keyed by debtorUserId -> creditorUserId -> amountPaise.
 * All amounts are positive integers in paise.
 */
interface SimplifiedBalancesMap {
  [debtorUserId: string]: {
    [creditorUserId: string]: number; // integer paise, always > 0
  };
}
```

Additionally, the callable returns the flat transfer list (defined in
`functions/src/simplified-debts/algorithm.ts`) alongside the projected map and an
ISO 8601 `computedAt` timestamp:

```typescript
/** A single directed transfer; amounts are positive integer paise. */
interface Transfer {
  from: string;   // debtorUserId
  to: string;     // creditorUserId
  amountPaise: number; // positive integer
}

/** Successful callable response (RecomputeResponse). */
interface RecomputeResponse {
  ok: true;
  transfers: Transfer[];
  simplifiedBalances: SimplifiedBalancesMap;
  computedAt: string; // ISO 8601
}
```

**Firestore paths written (inside transaction):**

| Context type | Document path | Field |
|---|---|---|
| friendship | `friendships/{contextId}` | `simplifiedBalances` |
| group | `groups/{contextId}` | `simplifiedBalances` |

**Firestore paths read (inside transaction):**

| Context type | Collection path |
|---|---|
| friendship | `friendships/{contextId}/expenses` (where `deleted != true`) |
| group | `groups/{contextId}/expenses` (where `deleted != true`) |
| both | `settlements` (where `contextType == X` and `contextId == Y`) |

### Idempotency strategy

The function is deterministic and side-effect-free beyond writing
`simplifiedBalances`. Re-running with the same set of expenses and settlements
always produces the identical map. Because the write occurs inside a Firestore
transaction that reads the current expense and settlement state, retries converge
to the correct result. No external effects (no notifications, no activity items)
are produced by this module.

### Error semantics

The shared core (`recomputeAndWrite`) never throws `HttpsError`; it returns a typed
`RecomputeResult` discriminated union. The callable handler maps that result to
`HttpsError` (see `docs/design/07-technical/cloud-functions-error-codes.md`):

- Invalid input (`contextType` not `friendship`/`group`, or empty `contextId`):
  `HttpsError('invalid-argument', …, { errorCode: 'INVALID_INPUT' })`.
- Context document not found: `HttpsError('not-found', …, { errorCode: 'CONTEXT_NOT_FOUND' })`.
- Non-zero net-balance sum: `simplifyDebts` throws a plain `Error` whose message
  contains "Balance invariant violation"; the core catches it and returns
  `BALANCE_INVARIANT_VIOLATED`, which the handler maps to
  `HttpsError('internal', …, { errorCode: 'BALANCE_INVARIANT_VIOLATED' })`.
- Any other (unknown) error: `HttpsError('internal', …, { errorCode: 'INTERNAL' })`.
- No partial writes: the read, compute, and write all occur inside one Firestore
  transaction.

There is **no** authentication check in this callable; it does not emit
`UNAUTHENTICATED` or `PERMISSION_DENIED`.

### Retry policy

No automatic retry. As an HTTPS Callable, retry behaviour is controlled by the
caller. The trigger-driven entry points (`onExpenseWriteFriendship`,
`onSettlementWrite`) carry their own retry semantics — see their sections.

### Region

`asia-south1`

---

## 3. onExpenseWriteFriendship

### Purpose

Responds to any create, update, soft-delete, or hard-delete of an expense document
under a **friendship**. Orchestrates, in order:

1. Recomputes `simplifiedBalances` and atomically advances `lastActivityAt` on the
   parent friendship document via the shared `recomputeAndWrite` core (FR-SE-03,
   FR-SE-04).
2. Writes activity-feed items for both friendship members (FR-EX-07).
3. Sends FCM push notifications to the non-author members (FR-AC-03).

Steps 2 and 3 run only after a successful recompute and are fully contained — their
failures are logged but never rethrown, so they cannot trigger a retry that would
re-run the recompute or duplicate notifications.

### Trigger type

**Firestore `onDocumentWritten`** (Cloud Functions v2; covers create, update, and
delete) registered with `{ region: "asia-south1", document: "...", retry: true }`.

Trigger path (single deployment):

- `friendships/{friendshipId}/expenses/{expenseId}`

> The companion `onExpenseWriteGroup` for `groups/{groupId}/expenses/{expenseId}`
> is **deferred** to the groups epic and is not currently deployed (see
> [Deferred Functions](#deferred-functions)).

### Input contract

```typescript
/**
 * Firestore onDocumentWritten event (v2).
 * `event.data` is a Change<DocumentSnapshot>; `.before.exists` is false on create,
 * `.after.exists` is false on delete.
 */
interface ExpenseWriteEvent {
  /** Path parameters extracted from the trigger path. */
  params: {
    friendshipId: string;
    expenseId: string;
  };
  /** Event delivery time (ISO 8601 string); used by the stale-event guard. */
  time: string;
  /** The before/after snapshots. */
  data: Change<DocumentSnapshot>;
}

interface ExpenseDocument {
  amountPaise: number;           // integer paise
  description: string;
  category: string;
  date: FirebaseFirestore.Timestamp;
  payerId: string;
  splits: ExpenseSplit[];
  splitMethod: 'equal' | 'unequal' | 'percentage' | 'shares' | 'exact';
  receiptUrl: string | null;
  createdBy: string;
  createdAt: FirebaseFirestore.Timestamp;
  updatedAt: FirebaseFirestore.Timestamp;
  deleted: boolean;
}

interface ExpenseSplit {
  userId: string;
  sharePaise: number;            // integer paise
}
```

### Output contract

**Firestore writes:**

| Target | Path | Description |
|---|---|---|
| Simplified balances + ordering | `friendships/{friendshipId}` | `simplifiedBalances` and `lastActivityAt` written together in the `recomputeAndWrite` transaction. `lastActivityAt` is guarded for monotonicity. |
| Activity feed | `activity/{memberId}/items/{auto-id}` | One auto-ID document per friendship member, written via `writeExpenseActivity`. |

**FCM:**

Sends a notification to each non-author friendship member via the shared
notifications module (`sendExpenseNotification`), subject to the recipient's
`notificationPrefs` (FR-AC-04). FCM is only attempted when the trigger is wired with
`notificationsApi` and `messaging` (it is, in production); otherwise it no-ops.

```typescript
interface ExpenseActivityItem {
  type: 'expense_added' | 'expense_edited' | 'expense_deleted';
  payload: ExpenseAddedPayload | ExpenseEditedPayload | ExpenseDeletedPayload;
  createdAt: FirebaseFirestore.Timestamp; // serverTimestamp()
}
```

A soft-delete (an update flipping `deleted` from `false` to `true`) emits
`expense_deleted`, not `expense_edited`.

### Idempotency strategy

- Activity items are written with Firestore **auto-IDs** (`collection(...).add(...)`),
  not deterministic IDs. There is no de-duplication at the writer level; idempotency
  is **inherited from the stale-event guard** (events older than 7 days are dropped).
  In-window redeliveries therefore can duplicate activity items, which is accepted
  v1.0 behaviour.
- `recomputeAndWrite` is inherently idempotent: it recomputes from the current
  expense and settlement state inside a transaction, so retries converge.
- FCM is best-effort / at-least-once; duplicate pushes are acceptable.

### Error semantics

- If `recomputeAndWrite` returns `CONTEXT_NOT_FOUND` (the friendship was deleted),
  the handler logs and returns successfully so Cloud Functions does **not** retry.
- If it returns `BALANCE_INVARIANT_VIOLATED`, the handler **throws** a plain `Error`
  (with the hashed friendship ID) so Cloud Functions retries; persistent failures
  surface as alerts.
- Any unknown error from the core is logged and rethrown (INTERNAL) so Cloud
  Functions retries.
- Activity-feed and FCM failures are logged but never rethrown — the critical
  recompute has already committed.

### Retry policy

**Enabled** via the v2 option `{ retry: true }`. The idempotency strategy keeps
retries safe. Events older than the 7-day Cloud Functions delivery window are
dropped by comparing `event.time` against `STALE_EVENT_AGE_MS`.

### Region

`asia-south1`

---

## 4. onSettlementWrite

### Purpose

Responds to every write (create, update, soft-delete, hard-delete) of a top-level
settlement document. Orchestrates, in order:

1. Calls the shared `recomputeAndWrite` core for the settlement's context, which
   reads the context's expenses **and** settlements in the same Firestore
   transaction and writes the updated `simplifiedBalances` map plus a monotonic
   `lastActivityAt` to the parent friendship/group document (FR-SE-05, FR-SE-06).
2. Writes activity-feed items to **both** parties (FR-AC-01) — only on **create**
   events (v1.0 emission policy).
3. Sends an FCM push notification to the settlement's `toUserId` (the payee; the
   payer is the actor and is not notified) (FR-AC-03) — only on **create** events.

Steps 2 and 3 run only after a successful recompute and are fully contained — their
failures are logged but never rethrown.

### Trigger type

**Firestore `onDocumentWritten`** (v2) on `settlements/{settlementId}`, registered
with `{ region: "asia-south1", document: "settlements/{settlementId}", retry: true }`.
Covers create, update, soft-delete, and hard-delete.

The context discriminator (`contextType`, `contextId`) is read from the document
**data**, because the settlements collection is top-level — the discriminator is not
in the trigger path. The after-side snapshot is preferred on create/update; the
before-side is the source on hard delete. If neither side carries a valid
discriminator, the handler logs `errorCode: 'INVALID_INPUT'` and returns (no retry).

### Input contract

```typescript
interface SettlementDocument {
  fromUserId: string;
  toUserId: string;
  amountPaise: number;           // integer paise, > 0
  contextType: 'friendship' | 'group';
  contextId: string;
  date: FirebaseFirestore.Timestamp;
  note: string | null;
  createdAt: FirebaseFirestore.Timestamp;
  deleted?: boolean;             // soft-delete flag (filtered in computeNetBalances)
}
```

### Output contract

**Firestore writes:**

| Target | Path | Description |
|---|---|---|
| Simplified balances + ordering | `friendships/{contextId}` or `groups/{contextId}` | `simplifiedBalances` and monotonic `lastActivityAt` written together in the `recomputeAndWrite` transaction. |
| Activity feed | `activity/{fromUserId}/items/{auto-id}` | `settlement` activity item (create events only). |
| Activity feed | `activity/{toUserId}/items/{auto-id}` | `settlement` activity item (create events only). |

**FCM:**

Sends a notification to `toUserId` (the payee) via the shared notifications module
(`sendSettlementNotification`), subject to the recipient's `notificationPrefs`
(create events only).

```typescript
interface SettlementActivityItem {
  type: 'settlement';
  payload: SettlementActivityPayload; // built by settlement-payload-builder.ts
  createdAt: FirebaseFirestore.Timestamp; // serverTimestamp()
}
```

### Idempotency strategy

- Activity items are written with Firestore **auto-IDs** (via the shared
  `writeExpenseActivity` helper), not deterministic IDs. As with the expense
  trigger, idempotency is inherited from the 7-day stale-event guard; in-window
  redeliveries can duplicate items (accepted v1.0 behaviour).
- `recomputeAndWrite` is inherently idempotent.
- FCM is best-effort / at-least-once.

### Error semantics

Same policy as `onExpenseWriteFriendship`: `CONTEXT_NOT_FOUND` logs and returns (no
retry); `BALANCE_INVARIANT_VIOLATED` and unknown errors throw (retry); a missing
discriminator logs `INVALID_INPUT` and returns; activity and FCM failures are logged
but do not block.

### Retry policy

**Enabled** via the v2 option `{ retry: true }`. Stale events (older than the 7-day
delivery window) are dropped by comparing `event.time` against `STALE_EVENT_AGE_MS`.

### Region

`asia-south1`

---

## 5. sendReminderNotification

### Purpose

Sends a free-text reminder push notification to a friend who owes the caller money,
as determined by the simplified balances. Rate-limited to one reminder per friend per
24-hour window. (SRS section 4.6, FR-SE-09.)

### Trigger type

**Callable** (`functions.https.onCall`).

### Input contract

```typescript
interface SendReminderRequest {
  /** The userId of the friend to remind. Must owe the caller per simplifiedBalances. */
  toUserId: string;

  /** The friendship or group context in which the debt exists. */
  contextType: 'friendship' | 'group';
  contextId: string;

  /**
   * Optional free-text message. If omitted, a default message is used.
   * Maximum length: 500 characters.
   */
  message?: string;
}
```

The function extracts `context.auth.uid` (the sender) and requires
`simplifiedBalances[toUserId][senderUid]` on the context document to be a positive
integer (the recipient must owe the sender). Reading `simplifiedBalances` is
read-only — Invariant 2 is preserved. Group contexts are not yet supported in v1.0.

### Output contract

**FCM:**

Dispatches to the recipient's `fcmTokens` via the shared notifications module
(`sendFcmToTokens`), subject to the recipient's `notificationPrefs` allowing
`reminder`.

**Firestore writes:**

| Target | Path | Description |
|---|---|---|
| Rate-limit record | `_rateLimits/{senderUid}/sends/{toUserId}` | Per-friend 24-hour throttle. Stores `lastSentAt`, `windowStart`, `count`, and the hashed-safe `senderUid`/`recipientUid`. |
| Activity feed | `activity/{toUserId}/items/{auto-id}` | Reminder-received activity item (auto-ID; recipient only; written fire-and-forget after dispatch). |

```typescript
interface SendReminderResponse {
  success: true;
  /** ISO 8601 timestamp after which the next reminder may be sent. */
  nextAllowedAtIso: string;
}
```

The response is only returned on success; all failure conditions throw `HttpsError`.

### Idempotency strategy

- The rate-limit record at `_rateLimits/{senderUid}/sends/{toUserId}` is read before
  dispatch. If a reminder was sent within the last 24 hours
  (`REMINDER_WINDOW_MS`), the function **throws** `RATE_LIMITED`
  (`resource-exhausted`) with a `nextAllowedAtIso` detail rather than returning a
  success response.
- The rate-limit record is written before the activity item, so a duplicate
  in-window invocation is rejected by the throttle.
- FCM is best-effort / at-least-once; a duplicate push is acceptable.

### Error semantics

See `docs/design/07-technical/cloud-functions-error-codes.md` for the full catalogue.

| Condition | Error code (`HttpsError` code) |
|---|---|
| Unauthenticated caller | `UNAUTHENTICATED` (`unauthenticated`) |
| Missing/invalid `toUserId`, `contextType`, `contextId`, or `message` > 500 chars | `INVALID_INPUT` (`invalid-argument`) |
| `contextType` is `group` | `GROUP_CONTEXT_NOT_SUPPORTED` (`unimplemented`) |
| Caller is not a member of the context | `NOT_A_MEMBER` (`permission-denied`) |
| Recipient does not owe the caller in this context | `RECIPIENT_DOESNT_OWE` (`failed-precondition`) |
| Rate limit exceeded (< 24 h since last reminder) | `RATE_LIMITED` (`resource-exhausted`, with `nextAllowedAtIso`) |
| Recipient has no FCM tokens | `RECIPIENT_NO_TOKENS` (`failed-precondition`) |
| Recipient has reminders disabled in prefs | `RECIPIENT_PREFS_DISABLED` (`failed-precondition`) |
| FCM dispatch failed for all tokens | `FCM_DISPATCH_FAILED` (`unavailable`) |
| Unexpected error | `INTERNAL` (`internal`) |

### Retry policy

**Not auto-retried** (callable). The client may re-invoke on transient failure,
subject to the rate limit.

### Region

`asia-south1`

---

## 6. lookupUserByPhoneNumber

### Purpose

Accepts an E.164 phone number from an authenticated caller, queries the `users`
collection for a matching `phoneNumber` field, and returns a minimal response to
confirm whether the phone number belongs to a registered user. (ADR-0014.)

### Trigger type

**HTTPS Callable** (`onCall`), region `asia-south1`.

### Input contract

```typescript
interface LookupRequest {
  phoneNumber: string; // E.164 format, e.g. "+919876543210"
}
```

### Output contract

```typescript
type LookupResponse =
  | { matched: false }
  | { matched: true; displayName: string; photoUrl: string | null; otherUserId: string };
```

**Firestore paths read:**

| Collection | Query |
|---|---|
| `users` | `where('phoneNumber', '==', phoneNumber)`, `limit(1)` |

**Firestore paths written:**

| Target | Path | Description |
|---|---|---|
| Rate-limit counter | `_rateLimits/{userId}/lookups/counter` | Increments `count` and updates `windowStart` if the current window has expired. |

### Rate limiting

100 lookups per user per hour. The counter is stored at
`_rateLimits/{userId}/lookups/counter` — a single `counter` document inside
the per-user `lookups` subcollection of `_rateLimits/{userId}`. The
4-segment subcollection layout extends naturally to future rate-limit
categories (e.g. `_rateLimits/{userId}/sends/counter` for reminder
send throttles, `_rateLimits/{userId}/uploads/counter` for receipt
upload throttles) without schema migration. The recursive-wildcard
`match /_rateLimits/{document=**}` deny rule in `firestore.rules`
covers all depths and all categories.

The `counter` doc has the following fields:

| Field | Type | Description |
|---|---|---|
| `count` | number | Number of lookups in the current window. |
| `windowStart` | timestamp | Start of the current rate-limit window. |

If the current window has expired (more than 1 hour since `windowStart`), the
counter resets to 1 and `windowStart` is set to the current time. If the counter
reaches 100 within the window, the function returns a `RATE_LIMITED` error.

### Privacy

The function NEVER returns `phoneNumber`, `fcmTokens`, `notificationPrefs`,
`locale`, `createdAt`, or `updatedAt`. Only the minimum fields needed for the UI
(`displayName`, `photoUrl`) and for friendship creation (`otherUserId`) are
included in the response. A "not found" phone number is not an error — it returns
`{ matched: false }` as a success response.

### Logging

Each invocation logs a structured event with:

- SHA-256 hashed phone number (raw phone numbers are NEVER logged).
- Caller `userId`.
- Matched or unmatched result.

This is consistent with the PII handling principles in
`docs/design/07-technical/pii-handling.md` (sections 2.1 and 2.2).

### Idempotency strategy

The function is a pure read (plus rate-limit counter update). Repeated calls with
the same phone number return the same result (subject to user registration state
changes). The rate-limit counter is incremented on each call.

### Error semantics

See `docs/design/07-technical/cloud-functions-error-codes.md` for the full error
code catalogue. Summary:

| Condition | Error Code |
|---|---|
| Unauthenticated caller | `UNAUTHENTICATED` (`unauthenticated`) |
| Missing or malformed phone number (must match `/^\+91[6-9]\d{9}$/`) | `INVALID_INPUT` (`invalid-argument`) |
| Rate limit exceeded (100 lookups / hour) | `RATE_LIMITED` (`resource-exhausted`) |
| Unexpected error | `INTERNAL` (`internal`) |

### Retry policy

**Not auto-retried** (callable). The client may re-invoke on transient failure,
subject to the rate limit.

### Region

`asia-south1`

### ADR Reference

ADR-0014 — Phone Number Lookup via Cloud Function.

---

## Deferred Functions

The following functions appeared in earlier drafts but are **not implemented or
deployed** today. They are retained here only to record intent — do not assume their
behaviour exists in the codebase.

| Function | Trigger (planned) | Requirement | Status |
|---|---|---|---|
| `onExpenseWriteGroup` | Firestore `onDocumentWritten` `groups/{groupId}/expenses/{expenseId}` | FR-SE-03, FR-SE-04 | Deferred to the groups epic. The settlement trigger already handles group-context settlements via the doc-data discriminator; the group expense trigger is the remaining piece. |
| `onUserDelete` (account deletion) | Callable / scheduled | FR-AU-09 | Not yet implemented. |
| `acceptGroupInvite` | Callable | FR-GR-02, FR-GR-03 | Not yet implemented. |
| `revokeGroupInvite` | Callable | FR-GR-03 | Not yet implemented. |

---

## Shared Module: notifications

`functions/src/notifications/` is a **shared module, not a deployed function**. It
provides the FCM dispatch, rendering, and preference-filter surface consumed by
`sendReminderNotification`, `onExpenseWriteFriendship`, and `onSettlementWrite`.

Key exports (`functions/src/notifications/index.ts`, the `NotificationsApi`):

- `sendExpenseNotification`, `sendSettlementNotification`, `sendReminderNotification`
  — high-level dispatchers that read the recipient `users/{uid}` doc, apply the
  preference filter, render the payload, and send.
- `sendFcmToTokens` (`fcm-send.ts`) — per-token `messaging.send(...)` via
  `Promise.allSettled` (not `sendMulticast`); prunes tokens rejected with
  `messaging/registration-token-not-registered` from the user's `fcmTokens` array
  via `arrayRemove`. Tokens are fingerprinted (8 hex) and user IDs hashed before
  logging.
- `renderPayload` (`payload-renderer.ts`) — builds the title/body, formatting money
  with `formatInrFromPaise` (e.g. `₹1,200`, with Indian digit grouping).
- `isNotificationAllowed` (`prefs-filter.ts`) — per-type preference gate. A missing
  preference defaults to allowed; `group_invite` bypasses the gate.

The six notification types are `expense_added`, `expense_edited`, `expense_deleted`,
`settlement_received`, `reminder`, and `group_invite`. See
`docs/design/07-technical/notifications.md` for the full module description.

---

## Appendix A: Deployment Summary

| Function name | Trigger | Auto-retry | Region | Status |
|---|---|---|---|---|
| `healthcheck` | HTTPS `onRequest` | No | `asia-south1` | shipped |
| `recomputeSimplifiedBalances` | Callable (`onCall`) | No | `asia-south1` | shipped |
| `lookupUserByPhoneNumber` | Callable (`onCall`) | No | `asia-south1` | shipped |
| `sendReminderNotification` | Callable (`onCall`) | No | `asia-south1` | shipped |
| `onExpenseWriteFriendship` | Firestore `onDocumentWritten` `friendships/{id}/expenses/{id}` | Yes (`retry: true`) | `asia-south1` | shipped |
| `onSettlementWrite` | Firestore `onDocumentWritten` `settlements/{id}` | Yes (`retry: true`) | `asia-south1` | shipped |

Deferred (not deployed): `onExpenseWriteGroup`, `onUserDelete`, `acceptGroupInvite`,
`revokeGroupInvite` — see [Deferred Functions](#deferred-functions).

---

## Appendix B: Source File Layout

Each function lives in its own folder (`index.ts` registration + `function.ts`
handler + algorithm/helpers); the healthcheck is inline in `index.ts`.

```
functions/
  src/
    index.ts                            — entry point: healthcheck (inline) + re-exports
    simplified-debts/
      index.ts                          — recomputeSimplifiedBalances onCall registration
      function.ts                       — recomputeAndWrite core + createHandler + computeNetBalances
      algorithm.ts                      — pure simplifyDebts / projectToBalancesMap (SRS 7.4)
    lookup-user-by-phone-number/
      index.ts                          — lookupUserByPhoneNumber onCall registration
      function.ts                       — handler: auth, validation, rate limit
      algorithm.ts                      — phone-number query + safe field projection
    send-reminder-notification/
      index.ts                          — sendReminderNotification onCall registration
      function.ts                       — handler: precondition, rate limit, dispatch, activity
    triggers/
      on-expense-write/
        index.ts                        — onExpenseWriteFriendship onDocumentWritten registration
        function.ts                     — trigger handler (recompute + activity + FCM)
        activity-writer.ts              — activity/{uid}/items/{auto-id} writer
        payload-builder.ts              — activity payload builder
        activity-validator.ts           — payload validation
      on-settlement-write/
        index.ts                        — onSettlementWrite onDocumentWritten registration
        function.ts                     — trigger handler (recompute + activity + FCM)
        settlement-payload-builder.ts   — settlement activity payload builder
    notifications/                      — SHARED module (not a deployed function)
      index.ts, types.ts, fcm-send.ts, payload-renderer.ts, prefs-filter.ts,
      send-expense-notification.ts, send-settlement-notification.ts,
      send-reminder-notification.ts
    utils/
      id-hash.ts                        — hashId (SHA-256, 16 hex) for PII-safe logging
      format-inr.ts                     — formatInrFromPaise (paise -> grouped rupees)
    __tests__/healthcheck.test.ts       — healthcheck unit test
  test/
    simplified-debts/                   — algorithm.test, algorithm.property.test, function.test
    lookup-user-by-phone-number/        — algorithm.test, function.test
    send-reminder-notification/         — function.test
    triggers/on-expense-write/          — function, activity-writer, payload-builder, activity-validator
    triggers/on-settlement-write/       — function, settlement-payload-builder
    notifications/                      — fcm-send, payload-renderer, prefs-filter, send-* tests
    integration/                        — *.integration.test.ts (emulator)
    firestore-rules/, storage-rules/    — security-rules tests
    boundary-contracts/                 — no-double-on-money-fields
    utils/                              — id-hash, format-inr
```

---

## Appendix C: Cross-References

| SRS Requirement | Cloud Function(s) |
|---|---|
| FR-SE-01, FR-SE-02, FR-SE-03, FR-SE-04 | `recomputeSimplifiedBalances`, `onExpenseWriteFriendship`, `onSettlementWrite` |
| FR-SE-05, FR-SE-06 | `onSettlementWrite` |
| FR-SE-09 | `sendReminderNotification` |
| FR-EX-07 | `onExpenseWriteFriendship` (activity items) |
| FR-AC-01 | `onExpenseWriteFriendship`, `onSettlementWrite` (activity items) |
| FR-AC-03, FR-AC-04 | `onExpenseWriteFriendship`, `onSettlementWrite`, `sendReminderNotification` (FCM + prefs) |
| FR-FR-01 | `lookupUserByPhoneNumber` |
| FR-AU-09 | `onUserDelete` (deferred — not implemented) |
| FR-GR-02, FR-GR-03 | `acceptGroupInvite`, `revokeGroupInvite` (deferred — not implemented) |
| SRS section 7.3 (Invariant 1) | All functions (integer paise) |
| SRS section 7.3 (Invariant 2) | `recomputeAndWrite` (sole writer of `simplifiedBalances`) |
| SRS section 7.4 | `simplified-debts/algorithm.ts` (pure algorithm) |
| SRS section 7.5 | Security Rules enforce client-read-only on `simplifiedBalances` |
| SRS section 5.2 | All functions region-pinned to `asia-south1`; recompute P95 <= 500 ms |
