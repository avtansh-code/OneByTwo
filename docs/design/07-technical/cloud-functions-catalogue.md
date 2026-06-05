# Cloud Functions Catalogue

> **Document version:** 1.0
> **Status:** Draft
> **Region:** All functions are deployed to `asia-south1` (Mumbai) per SRS section 5.2.
> **Runtime:** Node 20, TypeScript, strict mode enabled.
> **Authoritative source:** `docs/OneByTwo_Requirements_Spec.md` v1.1.

---

## Table of Contents

1. [recomputeSimplifiedBalances](#1-recomputesimplifiedbalances)
2. [onExpenseWrite](#2-onexpensewrite)
3. [onSettlementWrite](#3-onsettlementwrite)
4. [onUserDelete](#4-onuserdelete)
5. [acceptGroupInvite](#5-acceptgroupinvite)
6. [revokeGroupInvite](#6-revokegroupinvite)
7. [sendReminderNotification](#7-sendremindernotification)
8. [lookupUserByPhoneNumber](#8-lookupuserbyphonenumber)

---

## Conventions

- All monetary values are integer **paise** (1 INR = 100 paise). Floats are never
  used for money. (SRS section 7.3; Invariant 1.)
- `simplifiedBalances` is written exclusively by Cloud Functions. Clients may read
  but never write this field. (SRS sections 4.6, 7.3, 7.5; Invariant 2.)
- Deterministic output: when creditors or debtors tie on absolute value, ties are
  broken by ascending `userId`. (SRS section 7.4.)

---

## 1. recomputeSimplifiedBalances

### Purpose

Reads all non-deleted expenses and settlements for a given context (friendship or
group), executes the simplified-debts algorithm (SRS section 7.4), and writes the
resulting `simplifiedBalances` map to the context document inside a Firestore
transaction. This is the sole writer of `simplifiedBalances`. (SRS sections 4.6
FR-SE-03, FR-SE-04; Invariant 2.)

### Trigger type

**HTTPS Callable** (`onCall`) — currently deployed as a standalone callable function
for Sprint 1 development and testing. The pure algorithm is independently
unit-testable (ADR-0011). Integration with trigger functions (`onExpenseWrite`,
`onSettlementWrite`) is planned for Sprint 2 (FR-SE-03, FR-SE-04).

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

Additionally, the pure algorithm function returns a flat list for use by callers
(e.g. for composing activity-feed items):

```typescript
interface DebtEdge {
  from: string;   // debtorUserId
  to: string;     // creditorUserId
  amountPaise: number; // positive integer
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

- If the Firestore transaction fails (contention, deadline), the callable returns
  an error to the caller.
- If the algorithm detects that the sum of all net balances is non-zero (invariant
  violation), it logs an error via `functions.logger.error` with the context ID and
  the residual, then throws. The caller receives the failure and may retry.
- No partial writes: the transaction is atomic.

### Retry policy

No automatic retry. Because this is currently deployed as an HTTPS Callable
function (`onCall`), retry behaviour is controlled by the caller. Automatic
trigger integration is planned for Sprint 2 (FR-SE-03, FR-SE-04).

### Region

`asia-south1`

---

## 2. onExpenseWrite

### Purpose

Responds to any create, update, or delete of an expense document within a friendship
or group. Orchestrates three side-effects:

1. Calls `recomputeSimplifiedBalances` to update the context document (FR-SE-04).
2. Writes activity-feed items for all affected users (FR-EX-07, FR-AC-01).
3. Sends FCM push notifications to affected users (FR-AC-03).

### Trigger type

**Firestore onWrite** (covers onCreate, onUpdate, onDelete).

Trigger paths (two separate function deployments sharing the same handler):

- `friendships/{friendshipId}/expenses/{expenseId}`
- `groups/{groupId}/expenses/{expenseId}`

### Input contract

```typescript
/**
 * Firestore onWrite trigger event.
 * `change.before` is undefined on create; `change.after` is undefined on delete.
 */
interface ExpenseWriteEvent {
  /** Path parameters extracted from the trigger path. */
  params: {
    friendshipId?: string;
    groupId?: string;
    expenseId: string;
  };

  /** The expense document shape (before and/or after). */
  change: {
    before?: ExpenseDocument;
    after?: ExpenseDocument;
  };
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
| Simplified balances | `friendships/{id}` or `groups/{id}` | `simplifiedBalances` field via `recomputeSimplifiedBalances` (transactional). |
| Activity feed | `activity/{userId}/items/{auto-id}` | One document per affected user (payer + all split participants). |
| Context document | `friendships/{id}` or `groups/{id}` | `updatedAt` timestamp. |

**FCM:**

Sends a data+notification message to each affected user (excluding the author of the
write) via their `fcmTokens` array on `users/{userId}`. Notification respects the
user's `notificationPrefs.newExpense` preference (FR-AC-04).

```typescript
interface ActivityItem {
  type: 'expense_added' | 'expense_edited' | 'expense_deleted';
  payload: {
    expenseId: string;
    contextType: 'friendship' | 'group';
    contextId: string;
    description: string;
    amountPaise: number;
    actorUserId: string;
  };
  createdAt: FirebaseFirestore.Timestamp;
}
```

### Idempotency strategy

- The function derives a deterministic activity-item ID from the expense ID and the
  event type (e.g. `{expenseId}_added`). Activity writes use `set()` with this ID
  rather than `add()`, so duplicate triggers produce the same document rather than
  duplicates.
- `recomputeSimplifiedBalances` is inherently idempotent (see section 1).
- FCM is best-effort and tolerated as at-least-once; duplicate pushes are acceptable
  per Firebase's delivery model.

### Error semantics

- If the `recomputeSimplifiedBalances` transaction fails, the entire function throws
  and Cloud Functions retries (see below).
- If activity-feed writes fail, the function logs the error but does not throw; the
  simplified-balances write (the critical path) has already committed.
- If FCM delivery fails for a specific token, the function removes stale tokens from
  the user's `fcmTokens` array and logs a warning. It does not throw.

### Retry policy

**Enabled.** The function is deployed with `failurePolicy: { retry: {} }` so that
transient Firestore transaction failures are automatically retried by Cloud Functions.
The idempotency strategy ensures retries are safe. Events older than the Cloud
Functions event-delivery window (7 days) are dropped by checking
`context.timestamp`.

### Region

`asia-south1`

---

## 3. onSettlementWrite

### Purpose

Responds to every write (create, update, soft-delete, hard-delete) of a
settlement document. v1.0 orchestrates only the simplified-balances
recompute; activity items and FCM are deferred to FR-AC-01 / FR-AC-03.

1. Calls the shared `recomputeAndWrite` core for the settlement's
   context, which reads expenses AND settlements in the same Firestore
   transaction and writes the updated `simplifiedBalances` map to the
   parent friendship/group document (FR-SE-04, FR-SE-06).
2. **(Deferred to FR-AC-01)** Writes an activity-feed item for both
   parties. Hand-off seam (`// TODO(FR-AC-01)`) lives in the trigger
   source.
3. **(Deferred to FR-AC-03)** Sends an FCM push notification to the
   recipient. Hand-off seam (`// TODO(FR-AC-03)`) lives in the trigger
   source.

### Trigger type

**Firestore onWrite** on `settlements/{settlementId}` (the v2
`onDocumentWritten` event). Covers create, update, soft-delete, and
hard-delete. Region: `asia-south1`. Retry: enabled.

The context discriminator (`contextType`, `contextId`) is read from the
document data because the settlements collection is top-level — the
discriminator is NOT in the trigger path. The after-side snapshot is
preferred on create/update; the before-side is the source on hard
delete.

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
}
```

### Output contract

**Firestore writes:**

| Target | Path | Description |
|---|---|---|
| Simplified balances | `friendships/{contextId}` or `groups/{contextId}` | `simplifiedBalances` field via `recomputeSimplifiedBalances` (transactional). |
| Activity feed | `activity/{fromUserId}/items/{settlementId}_settlement` | Settlement recorded activity item. |
| Activity feed | `activity/{toUserId}/items/{settlementId}_settlement` | Settlement received activity item. |
| Context document | `friendships/{contextId}` or `groups/{contextId}` | `updatedAt` and `lastActivityAt` timestamps. |

**FCM:**

Sends a notification to `toUserId` (the recipient of the payment) if their
`notificationPrefs.settlement` preference is enabled.

```typescript
interface SettlementActivityItem {
  type: 'settlement';
  payload: {
    settlementId: string;
    fromUserId: string;
    toUserId: string;
    amountPaise: number;
    contextType: 'friendship' | 'group';
    contextId: string;
  };
  createdAt: FirebaseFirestore.Timestamp;
}
```

### Idempotency strategy

- Activity-feed documents use the deterministic ID `{settlementId}_settlement`,
  so duplicate triggers overwrite the same document.
- `recomputeSimplifiedBalances` is inherently idempotent.
- FCM is best-effort / at-least-once.

### Error semantics

Same pattern as `onExpenseWrite`: transaction failure causes a throw and retry;
activity and FCM failures are logged but do not block.

### Retry policy

**Enabled.** Deployed with `failurePolicy: { retry: {} }`. Stale events (older than
the event-delivery window) are dropped by checking `context.timestamp`.

### Region

`asia-south1`

---

## 4. onUserDelete

### Purpose

Handles permanent account deletion per FR-AU-09 (SRS section 4.1). Anonymises the
user's data in shared groups and friendships, removes personal records, deletes the
Firebase Auth account, and removes Firebase Storage files. The operation completes
within a 30-day SLA as stated in the requirement.

### Trigger type

**Callable** (`functions.https.onCall`). The client invokes this after the user
confirms deletion. The function is also invokable by a scheduled clean-up job if a
queued deletion needs to be finalised.

### Input contract

```typescript
/** Callable request. Auth context is mandatory (verified via Firebase Admin SDK). */
interface DeleteAccountRequest {
  /**
   * Confirmation token generated by the client after the user types
   * "DELETE" or equivalent confirmation UI. Prevents accidental calls.
   */
  confirmation: string;
}
```

The function extracts `context.auth.uid` from the authenticated callable context.
Unauthenticated calls are rejected with `unauthenticated`.

### Output contract

The function performs the following operations. Each step is logged for auditability.

| Step | Action | Firestore path / resource |
|---|---|---|
| 1 | Mark user document as `deletionStatus: 'pending'` with `deletionRequestedAt` timestamp. | `users/{uid}` |
| 2 | Anonymise user in all friendships: replace `displayName` references with "Deleted User", remove from `memberIds` if balances are zero, or retain anonymised entry if non-zero balances exist. | `friendships/{*}` where `memberIds` contains `uid` |
| 3 | Anonymise user in all groups: same logic as friendships. Reassign admin role if the user is admin (to the earliest-joined remaining member by `userId` sort). | `groups/{*}` where `memberIds` contains `uid` |
| 4 | Soft-delete all expenses created by the user (set `deleted: true`) and trigger balance recomputation for affected contexts. | `friendships/{*}/expenses/{*}`, `groups/{*}/expenses/{*}` |
| 5 | Delete all activity-feed items for the user. | `activity/{uid}/items/{*}` |
| 6 | Delete user's profile photo and receipt images from Storage. | `users/{uid}/avatar.*`, `receipts/{uid}/*` |
| 7 | Delete the Firebase Auth account. | Firebase Auth |
| 8 | Delete the user document. | `users/{uid}` |

```typescript
interface DeleteAccountResponse {
  /** Whether the deletion was immediately completed or queued for async processing. */
  status: 'completed' | 'queued';

  /**
   * Estimated completion timestamp (ISO 8601) if queued.
   * Null if completed immediately.
   */
  estimatedCompletionAt: string | null;
}
```

### Idempotency strategy

- The function first checks `users/{uid}.deletionStatus`. If already `'pending'` or
  `'completed'`, it returns early with the appropriate status rather than
  re-processing.
- Each sub-operation (anonymise friendship, anonymise group, etc.) is individually
  idempotent: anonymising an already-anonymised record is a no-op; deleting an
  already-deleted Auth account returns gracefully.

### Error semantics

- If the caller is unauthenticated: throws `functions.https.HttpsError('unauthenticated')`.
- If the confirmation token is invalid: throws `functions.https.HttpsError('invalid-argument')`.
- If a sub-step fails (e.g. Storage deletion times out), the function logs the error
  and continues with remaining steps. The user document retains
  `deletionStatus: 'pending'` so a scheduled retry can pick it up.
- A scheduled function (daily) scans for `deletionStatus: 'pending'` documents older
  than 24 hours and re-attempts incomplete deletions.

### Retry policy

**Not auto-retried** (callable functions do not support `failurePolicy`). Retries
are handled by the scheduled clean-up job and by the client re-invoking the callable
if the initial call fails.

### Region

`asia-south1`

---

## 5. acceptGroupInvite

### Purpose

Validates a group invite token, checks expiry, and adds the authenticated user to
the group's `memberIds`. This logic runs server-side to prevent clients from
bypassing invite validation. (SRS section 4.4, FR-GR-02, FR-GR-03; SRS section 7.3.)

### Trigger type

**Callable** (`functions.https.onCall`).

### Input contract

```typescript
interface AcceptGroupInviteRequest {
  /** The invite token extracted from the deep link. */
  inviteToken: string;

  /** The group ID the invite pertains to (used for cross-validation). */
  groupId: string;
}
```

The function extracts `context.auth.uid`. Unauthenticated calls are rejected.

The function reads the invite record to validate:

```typescript
interface GroupInviteRecord {
  token: string;
  groupId: string;
  createdBy: string;
  createdAt: FirebaseFirestore.Timestamp;
  expiresAt: FirebaseFirestore.Timestamp;  // createdAt + 7 days (FR-GR-03)
  revoked: boolean;
}
```

### Output contract

**Firestore writes (transactional):**

| Target | Path | Description |
|---|---|---|
| Group document | `groups/{groupId}` | Append `uid` to `memberIds` array. |
| Activity feed | `activity/{uid}/items/{groupId}_joined` | "You joined group X" item. |
| Activity feed | `activity/{memberId}/items/{groupId}_{uid}_joined` | "User Y joined group X" for each existing member. |

```typescript
interface AcceptGroupInviteResponse {
  success: boolean;
  groupId: string;
  groupName: string;
}
```

### Idempotency strategy

- Before appending to `memberIds`, the function checks whether `uid` is already
  present. If so, it returns success without modification.
- Activity-feed items use deterministic IDs (see table above), so duplicate
  invocations overwrite the same document.

### Error semantics

| Condition | Error |
|---|---|
| Unauthenticated caller | `unauthenticated` |
| Token not found | `not-found` — "Invite not found." |
| Token expired (> 7 days from `createdAt`) | `deadline-exceeded` — "This invite has expired." |
| Token revoked | `permission-denied` — "This invite has been revoked." |
| `groupId` in request does not match token's `groupId` | `invalid-argument` — "Group ID mismatch." |
| Group document does not exist | `not-found` — "Group not found." |

### Retry policy

**Not auto-retried** (callable). The client may re-invoke on transient failure.

### Region

`asia-south1`

---

## 6. revokeGroupInvite

### Purpose

Allows a group admin to invalidate an existing invite token so it can no longer be
used to join the group. (SRS section 4.4, FR-GR-03.)

### Trigger type

**Callable** (`functions.https.onCall`).

### Input contract

```typescript
interface RevokeGroupInviteRequest {
  /** The invite token to revoke. */
  inviteToken: string;

  /** The group ID (for authorisation check). */
  groupId: string;
}
```

The function extracts `context.auth.uid` and verifies the caller is the group's
`adminId`.

### Output contract

**Firestore writes:**

| Target | Path | Description |
|---|---|---|
| Invite record | `groups/{groupId}/invites/{inviteToken}` | Set `revoked: true`, `revokedAt: Timestamp`, `revokedBy: uid`. |

```typescript
interface RevokeGroupInviteResponse {
  success: boolean;
}
```

### Idempotency strategy

Revoking an already-revoked token is a no-op; the function returns success.

### Error semantics

| Condition | Error |
|---|---|
| Unauthenticated caller | `unauthenticated` |
| Caller is not the group's `adminId` | `permission-denied` — "Only the group admin may revoke invites." |
| Token not found | `not-found` — "Invite not found." |
| Group does not exist | `not-found` — "Group not found." |

### Retry policy

**Not auto-retried** (callable). The client may re-invoke on transient failure.

### Region

`asia-south1`

---

## 7. sendReminderNotification

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

The function extracts `context.auth.uid` (the sender).

### Output contract

**FCM:**

Sends a data+notification message to `toUserId` via their `fcmTokens`, subject to
`notificationPrefs.reminder` being enabled (FR-AC-04).

**Firestore writes:**

| Target | Path | Description |
|---|---|---|
| Rate-limit record | `reminders/{senderUid}_{toUserId}` | `lastSentAt: Timestamp`. Used to enforce the 24-hour rate limit. |
| Activity feed | `activity/{toUserId}/items/{auto-deterministic-id}` | Reminder-received activity item. |

```typescript
interface SendReminderResponse {
  success: boolean;
  /** ISO 8601 timestamp after which the next reminder may be sent. */
  nextAllowedAt: string;
}
```

### Idempotency strategy

- The rate-limit record is checked before sending. If a reminder was sent within the
  last 24 hours, the function returns early with `success: false` and the
  `nextAllowedAt` timestamp.
- If the function is invoked twice in rapid succession, the first call writes the
  rate-limit record; the second call reads it and short-circuits.
- FCM is best-effort / at-least-once; a duplicate push is acceptable.

### Error semantics

| Condition | Error |
|---|---|
| Unauthenticated caller | `unauthenticated` |
| `toUserId` does not owe caller in the specified context | `failed-precondition` — "This user does not owe you in this context." |
| Rate limit exceeded (< 24 hours since last reminder) | `resource-exhausted` — "Rate limit: one reminder per friend per 24 hours." |
| `message` exceeds 500 characters | `invalid-argument` — "Message too long." |
| `toUserId` has no valid FCM tokens | Logged as warning; returns `success: true` (the reminder was "sent" but undeliverable). |

### Retry policy

**Not auto-retried** (callable). The client may re-invoke on transient failure,
subject to the rate limit.

### Region

`asia-south1`

---

## 8. lookupUserByPhoneNumber

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
| Rate-limit counter | `_rateLimits/{userId}/lookups` | Increments `count` and updates `windowStart` if the current window has expired. |

### Rate limiting

100 lookups per user per hour. The counter is stored at
`_rateLimits/{userId}/lookups` with the following fields:

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
| Missing or malformed phone number | `INVALID_INPUT` (`invalid-argument`) |
| Rate limit exceeded | `RATE_LIMITED` (`resource-exhausted`) |
| Unexpected error | `INTERNAL` (`internal`) |

### Retry policy

**Not auto-retried** (callable). The client may re-invoke on transient failure,
subject to the rate limit.

### Region

`asia-south1`

### ADR Reference

ADR-0014 — Phone Number Lookup via Cloud Function.

---

## Appendix A: Deployment Summary

| Function name | Trigger | Auto-retry | Region | Status |
|---|---|---|---|---|
| `recomputeSimplifiedBalances` | Callable | No | `asia-south1` | shipped |
| `onExpenseWriteFriendship` | Firestore onWrite `friendships/{id}/expenses/{id}` | Yes | `asia-south1` | shipped |
| `onExpenseWriteGroup` | Firestore onWrite `groups/{id}/expenses/{id}` | Yes | `asia-south1` | planned |
| `onSettlementWrite` | Firestore onWrite `settlements/{id}` | Yes | `asia-south1` | shipped |
| `onUserDelete` | Callable | No | `asia-south1` | planned |
| `acceptGroupInvite` | Callable | No | `asia-south1` | planned |
| `revokeGroupInvite` | Callable | No | `asia-south1` | planned |
| `sendReminderNotification` | Callable | No | `asia-south1` | planned |
| `lookupUserByPhoneNumber` | Callable | No | `asia-south1` | planned |

---

## Appendix B: Source File Layout

```
functions/
  src/
    index.ts                         — Cloud Function entry points
    simplifiedDebts.ts               — Pure algorithm (SRS section 7.4)
    triggers/
      onExpenseWrite.ts              — Firestore onWrite handler
      onSettlementWrite.ts           — Firestore onCreate handler
    callables/
      onUserDelete.ts                — Account deletion callable
      acceptGroupInvite.ts           — Invite acceptance callable
      revokeGroupInvite.ts           — Invite revocation callable
      sendReminderNotification.ts    — Reminder callable
      lookupUserByPhoneNumber.ts     — Phone number lookup callable
    utils/
      recomputeSimplifiedBalances.ts — Transaction-based recomputation
      activityFeed.ts                — Activity-feed write helpers
      fcm.ts                         — FCM send helpers
      rateLimiter.ts                 — Rate-limit check helpers
    types/
      index.ts                       — Shared TypeScript interfaces
  test/
    unit/
      simplifiedDebts.test.ts
      recomputeSimplifiedBalances.test.ts
    integration/
      onExpenseWrite.test.ts
      onSettlementWrite.test.ts
      onUserDelete.test.ts
      acceptGroupInvite.test.ts
      revokeGroupInvite.test.ts
      sendReminderNotification.test.ts
      lookupUserByPhoneNumber.test.ts
```

---

## Appendix C: Cross-References

| SRS Requirement | Cloud Function(s) |
|---|---|
| FR-SE-01, FR-SE-02, FR-SE-03, FR-SE-04 | `recomputeSimplifiedBalances`, `onExpenseWrite`, `onSettlementWrite` |
| FR-SE-05, FR-SE-06 | `onSettlementWrite` |
| FR-SE-09 | `sendReminderNotification` |
| FR-EX-06, FR-EX-07 | `onExpenseWrite` |
| FR-AC-01, FR-AC-03, FR-AC-04 | `onExpenseWrite`, `onSettlementWrite`, `sendReminderNotification` |
| FR-AU-09 | `onUserDelete` |
| FR-GR-02, FR-GR-03 | `acceptGroupInvite`, `revokeGroupInvite` |
| FR-FR-01 | `lookupUserByPhoneNumber` |
| SRS section 7.3 (Invariant 1) | All functions (integer paise) |
| SRS section 7.3 (Invariant 2) | `recomputeSimplifiedBalances` |
| SRS section 7.4 | `simplifiedDebts.ts` (pure algorithm) |
| SRS section 7.5 | Security Rules enforce client-read-only on `simplifiedBalances` |
| SRS section 5.2 | All functions region-pinned to `asia-south1`; simplified-debts P95 <= 500 ms |
