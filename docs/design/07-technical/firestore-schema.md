# Firestore Schema — Final Design

> **Document owner:** Solution Architect
> **Version:** 1.0
> **Status:** Approved baseline
> **Audience:** Solution Architect, Flutter Developer, Cloud Functions Developer, DevOps Engineer

---

## Purpose

This document specifies the complete Firestore data model for One By Two v1.0. It
expands the logical model defined in SRS section 7.2 into a field-level reference
that the Flutter Developer and Cloud Functions Developer use when creating, reading,
or validating documents. Every field includes its type, whether it is required, its
default value, and whether it is indexed.

Extension-point fields from `docs/design/03-architecture/extension-points.md` are
included with their v1.0 default values. Per the extension-points design principle 1,
these fields are written explicitly at document creation time, with one documented
exception: `recurringRule` on expenses is **omitted** by the client, and the rules
accept it absent or `null` (see ARCH-EXT-03).

All monetary values are stored as **integer paise** (1 INR = 100 paise). Conversion
to rupees occurs exclusively at the UI layer (SRS section 7.3, Invariant 1).

---

## Collections

### `users/{userId}`

The `userId` matches the Firebase Authentication UID assigned at phone-number sign-up.

| Field | Type | Required | Default | Description | Indexed |
|---|---|---|---|---|---|
| `phoneNumber` | `string` | Yes | — | E.164 format, restricted to `+91` prefix (SRS section 1.3). On create the rules require `phoneNumber == request.auth.token.phone_number`. Immutable after create. | Automatic single-field index (Firestore default; used by `lookupUserByPhoneNumber`) |
| `displayName` | `string` | Yes | — | User-chosen display name. Maximum 50 characters. | No |
| `photoUrl` | `string \| null` | No | `null` | Cloud Storage download URL for the user's avatar. See Storage Layout section. | No |
| `fcmTokens` | `array<string>` | Yes | `[]` | One entry per device. Managed by the client on app launch; pruned by Cloud Functions on send failure (SRS section 7.2). | No |
| `createdAt` | `timestamp` | Yes | Server timestamp | Document creation time. Set once, never updated. | No |
| `updatedAt` | `timestamp` | Yes | Server timestamp | Last modification time. Updated on every write. | No |
| `notificationPrefs` | `map` | Yes | `{ newExpense: true, settlement: true, reminder: true }` | Boolean flags controlling push notification categories (SRS section 7.2). | No |
| `locale` | `string` | Yes | `'en-IN'` | BCP 47 locale code. v1.0 supports only `'en-IN'`. Written explicitly per ARCH-EXT-04; supports future localisation without backfill. | No |

**Security rules summary (SRS section 7.5, as implemented in `firestore.rules`):**

- **Read** is allowed to the owner (`request.auth.uid == userId`) **or** to a user
  who shares a friendship with the owner (`isFriendshipMemberWith`) **or** to a user
  who shares a group with the owner (`isInGroupWith`). The `isInGroupWith` helper is a
  v1.0 placeholder that returns `false` until the groups feature ships, so in practice
  reads resolve to owner-or-friend.
- **Create** and **update** are allowed only to the owner, and the rules validate the
  document shape: `displayName` is a string of 1–50 characters, `phoneNumber` equals
  `request.auth.token.phone_number`, `locale == 'en-IN'`, `fcmTokens` is a list (no
  size cap is enforced), and `notificationPrefs` is a map carrying boolean
  `newExpense`, `settlement`, and `reminder` flags. On update, `phoneNumber` and
  `createdAt` are immutable.
- **Delete** is denied for all clients (no `allow delete` rule).

---

### `friendships/{friendshipId}`

The `friendshipId` is a deterministic composite key formed by sorting the two member
UIDs lexicographically and joining them with an underscore (e.g.,
`uid_A_uid_B` where `uid_A < uid_B`). This guarantees a single document per pair
(SRS section 7.2).

| Field | Type | Required | Default | Description | Indexed |
|---|---|---|---|---|---|
| `memberIds` | `array<string>` (exactly 2) | Yes | — | Sorted ascending; the rules require `memberIds[0] < memberIds[1]`. Used for access-control checks in security rules. Immutable after create. | Composite (see Composite Indexes) |
| `createdBy` | `string` | Yes | — | UID of the user who created the friendship. The rules require `createdBy == request.auth.uid` on create and treat it as immutable on update. | No |
| `simplifiedBalances` | `map` | No at create | — | Nested map: `{ [debtorUserId]: { [creditorUserId]: amountPaise } }`. **Server-maintained, client-read-only** (SRS section 7.3, Invariant 2). **Absent when the client creates the document** — the rules reject a create that includes it — and added/updated only by the server-side simplified-debts recompute core (`functions/src/simplified-debts/function.ts`), reached via the `recomputeSimplifiedBalances` callable and the `onExpenseWriteFriendship` / `onSettlementWrite` triggers. | No |
| `lastActivityAt` | `timestamp` | Yes | `request.time` at create | Set to the server time on create and refreshed by the Cloud Functions whenever an expense or settlement changes within this friendship. | Composite (see Composite Indexes) |

**Security rules summary (SRS section 7.5, as implemented in `firestore.rules`):**

- **Read**, **create**, and **update** are allowed only to users whose UID appears in
  `memberIds` (the caller must also be a member of the pair).
- On **create**: `memberIds` must hold exactly the two member UIDs in ascending order,
  `createdBy` must equal the caller UID, `lastActivityAt` must equal `request.time`, and
  `simplifiedBalances` must be **absent**. There is no rule that ties the document ID to
  the sorted-UID composite; the ordering guarantee comes from the `memberIds[0] < memberIds[1]`
  check and the client's deterministic ID construction.
- On **update**: `memberIds` and `createdBy` are immutable, and a client write that
  touches `simplifiedBalances` is rejected
  (`request.resource.data.diff(resource.data).affectedKeys().hasAny(['simplifiedBalances'])`).
- **Delete** is denied for all clients (`allow delete: if false`).

---

### `groups/{groupId}`

The `groupId` is an auto-generated Firestore document ID.

> **Implementation status (v1.0):** The group schema and security rules exist in
> `firestore.rules`, but there is **no Flutter client UI and no client data layer**
> for groups in v1.0 — `lib/features/groups/` contains only placeholders. Groups are
> a Sprint 3 feature; the rules below are in place so the data model is forward-compatible.

| Field | Type | Required | Default | Description | Indexed |
|---|---|---|---|---|---|
| `name` | `string` | Yes | — | Group display name. The rules require 1–100 characters. | No |
| `type` | `string` | Yes | — | One of `'trip'`, `'home'`, `'couple'`, `'other'` (enforced by the rules). | No |
| `coverPhotoUrl` | `string \| null` | No | `null` | Cloud Storage download URL for the group cover image. Not validated by the rules. | No |
| `memberIds` | `array<string>` | Yes | — | UIDs of all current group members; the rules require a list. Used for access-control checks. | No |
| `adminId` | `string` | Yes | — | UID of the group administrator. The rules require `adminId == request.auth.uid` on create. | No |
| `simplifiedBalances` | `map` | No at create | — | Nested map: `{ [debtorUserId]: { [creditorUserId]: amountPaise } }`. **Server-maintained, client-read-only** (SRS section 7.3, Invariant 2). **Absent at create** (the rules reject a create that includes it). No group expense/settlement trigger exists in v1.0, so this field is not yet populated for groups. | No |
| `createdAt` | `timestamp` | Yes | `request.time` at create | Document creation time; the rules require `createdAt == request.time`. | No |
| `updatedAt` | `timestamp` | Yes | `request.time` | Last modification time; the rules require `updatedAt == request.time` on create. | No |

**Security rules summary (SRS section 7.5, as implemented in `firestore.rules`):**

- **Read** is allowed to users whose UID appears in `memberIds`.
- **Create** is allowed to a member when the document validates: `name` 1–100 chars,
  `type` in the allow-list, `memberIds` is a list, `adminId == request.auth.uid`,
  `createdAt == updatedAt == request.time`, and `simplifiedBalances` is absent. Unlike
  the friendship and expense rules, the group create rule does **not** restrict the set
  of keys, so additional fields (e.g. `coverPhotoUrl`) are permitted.
- **Update** is allowed to members, and a client write that touches `simplifiedBalances`
  is rejected via the same `affectedKeys()` guard used for friendships.
- **Delete** is denied for all clients (`allow delete: if false`).

---

### `groups/{groupId}/expenses/{expenseId}`

Subcollection of a group document. The `expenseId` is an auto-generated Firestore
document ID.

> **Implementation status (v1.0):** This subcollection has **no security rules** in
> `firestore.rules` (only friendship expenses are covered) and **no client or trigger
> code**. The table below is the intended Sprint 3 shape, kept aligned with the
> implemented friendship-expense schema; it is not yet reachable or enforced.

| Field | Type | Required | Default | Description | Indexed |
|---|---|---|---|---|---|
| `amountPaise` | `integer` | Yes | — | Total expense amount in paise. Must be a positive integer (SRS section 7.3, Invariant 1). | No |
| `description` | `string` | Yes | — | Free-text description. Maximum 200 characters. | No |
| `category` | `string` | Yes | — | Expense category enum value. The eight v1.0 values are `'food'`, `'travel'`, `'rent'`, `'utilities'`, `'groceries'`, `'entertainment'`, `'shopping'`, `'other'` (`lib/features/expenses/domain/expense_category.dart`). | No |
| `date` | `timestamp` | Yes | — | The date the expense was incurred (user-specified, may differ from `createdAt`). | Composite (see Composite Indexes) |
| `payerId` | `string` | Yes | — | UID of the member who paid. Must be present in the parent group's `memberIds`. | No |
| `splits` | `array<map>` | Yes | — | Each element: `{ userId: string, sharePaise: integer }`. The sum of all `sharePaise` values must equal `amountPaise` (validated by security rules, SRS section 7.5). | No |
| `splitMethod` | `string` | Yes | — | One of `'equal'`, `'unequal'`, `'percentage'`, `'shares'`, `'exact'` (SRS section 7.2). | No |
| `receiptUrl` | `string \| null` | No | `null` | Cloud Storage download URL for the receipt image. See Storage Layout section. | No |
| `createdBy` | `string` | Yes | — | UID of the member who created the expense record. | No |
| `createdAt` | `timestamp` | Yes | Server timestamp | Document creation time. Set once, never updated. | No |
| `updatedAt` | `timestamp` | Yes | Server timestamp | Last modification time. Updated on every write. | No |
| `deleted` | `boolean` | Yes | `false` | Soft-delete flag. When `true`, the expense is excluded from balance computations but retained for audit history (SRS section 7.3). | Composite (see Composite Indexes) |
| `source` | `string` | Yes | `'manual'` | Expense creation source. v1.0 value is always `'manual'`. Written explicitly per ARCH-EXT-07; supports future `'ocr'` value without backfill. | No |
| `currency` | `string` | Yes | `'INR'` | ISO 4217 currency code. v1.0 value is always `'INR'`. Written explicitly per ARCH-EXT-02; supports future multi-currency without backfill. | No |
| `recurringRule` | `map \| null` | No | `null` | Recurring expense rule sub-document. v1.0 value is always `null`. Written explicitly per ARCH-EXT-03; supports future recurrence scheduling without backfill. | No |

**Security rules summary:**

- **None.** `firestore.rules` defines no `match` block for `groups/{groupId}/expenses`,
  so under the default deny-all all client access is rejected in v1.0. Sum-of-splits
  validation, soft-delete handling, and a group-expense trigger are deferred to Sprint 3.

---

### `groupInvites/{token}`

> **Implementation status (design outline, Sprint 3):** This is a **forward design** for
> the FR-GR-02 / FR-GR-03 invite-link flow (ADR-0023). The collection, its security
> rules, and the `createGroupInvite` / `acceptGroupInvite` callables are **not present in
> `firestore.rules` or the client in v1.0**; the shape below is ratified now so the
> Sprint 3 groups epic is not designed blind. Documents are **server/admin-managed** —
> created and revoked only through Cloud Functions acting for the group admin.

The document ID **is** the invite `token`: a high-entropy, server-generated, URL-safe
string embedded in the `/invite/group/:inviteToken` universal/App Link (ADR-0023). A
top-level collection — rather than a `groups/{groupId}/invites/{token}` subcollection —
is used deliberately: the invitee is a non-member who holds only the token and does not
know the `groupId`, and reading the parent group is membership-gated, so the token must
be resolvable without a group read (see ADR-0023).

| Field | Type | Required | Default | Description | Indexed |
|---|---|---|---|---|---|
| `token` | `string` | Yes | — | The invite token; mirrors the document ID. High-entropy, server-generated, URL-safe. | No (the document ID is the lookup key) |
| `groupId` | `string` | Yes | — | The target `groups/{groupId}` the token grants membership to. | No |
| `createdBy` | `string` | Yes | — | UID of the group admin who minted the token. Must equal the group's `adminId` at creation. | No |
| `createdAt` | `timestamp` | Yes | `request.time` at create | Token mint time. | No |
| `expiresAt` | `timestamp` | Yes | `createdAt + 7 days` | Hard expiry; a token is invalid once `request.time >= expiresAt` (ADR-0023, 7-day window). | No |
| `revoked` | `boolean` | Yes | `false` | Admin revocation flag. A revoked token is invalid regardless of `expiresAt`. | No |

**Security rules summary (design outline — authoritative rules land in Sprint 3):**

- **Read** is allowed to a signed-in user performing a **get by token** (the document ID
  is the unguessable token) only while the token is live —
  `resource.data.revoked == false && request.time < resource.data.expiresAt`. **List/query
  is denied** so tokens cannot be enumerated.
- **Create** is performed **server-side** by the `createGroupInvite` callable acting for
  the group admin (`createdBy == adminId`), which sets `expiresAt = createdAt + 7 days`
  and `revoked = false`. Direct client create is denied.
- **Update** is limited to the admin flipping `revoked` to `true` (revocation); all other
  field mutations are denied. Acceptance does **not** mutate the token — membership is
  added to `groups/{groupId}.memberIds` by the `acceptGroupInvite` callable.
- **Delete** is denied for all clients; expired tokens are reaped by a server-side
  lifecycle task, not by client delete.

See `firestore-security-rules.md` (`groupInvites/{token}`) for the matching rules outline
and ADR-0023 for the full decision.

---

### `friendships/{friendshipId}/expenses/{expenseId}`

Subcollection of a friendship document. The schema is identical to group expenses.
The `expenseId` is an auto-generated Firestore document ID.

| Field | Type | Required | Default | Description | Indexed |
|---|---|---|---|---|---|
| `amountPaise` | `integer` | Yes | — | Total expense amount in paise. Must be a positive integer (SRS section 7.3, Invariant 1). | No |
| `description` | `string` | Yes | — | Free-text description. Maximum 200 characters. | No |
| `category` | `string` | Yes | — | Expense category enum value. | No |
| `date` | `timestamp` | Yes | — | The date the expense was incurred (user-specified). | Composite (see Composite Indexes) |
| `payerId` | `string` | Yes | — | UID of the member who paid. Must be present in the parent friendship's `memberIds`. | No |
| `splits` | `array<map>` | Yes | — | Each element: `{ userId: string, sharePaise: integer }`. For friendships the list holds 1–2 elements; the rules validate `sum(splits[*].sharePaise) == amountPaise` by **bounded enumeration** (indices 0 and 1 only). | No |
| `splitMethod` | `string` | Yes | — | One of `'equal'`, `'unequal'`, `'percentage'`, `'shares'`, `'exact'`. | No |
| `receiptUrl` | `string \| null` | No | `null` | Cloud Storage download URL for the receipt image. | No |
| `createdBy` | `string` | Yes | — | UID of the member who created the expense record. | No |
| `createdAt` | `timestamp` | Yes | Server timestamp | Document creation time. Set once, never updated. | No |
| `updatedAt` | `timestamp` | Yes | Server timestamp | Last modification time. Updated on every write. | No |
| `deleted` | `boolean` | Yes | `false` | Soft-delete flag (SRS section 7.3). | Composite (see Composite Indexes) |
| `source` | `string` | Yes | `'manual'` | Expense creation source. v1.0: always `'manual'` (ARCH-EXT-07). | No |
| `currency` | `string` | Yes | `'INR'` | ISO 4217 currency code. v1.0: always `'INR'` (ARCH-EXT-02). | No |
| `recurringRule` | `map \| null` | No | absent | Recurring expense rule. **The client omits this field entirely** (`ExpenseDoc` does not write it); the rules accept it absent **or** `null` (ARCH-EXT-03). This is the one extension field that is not written at create time — see the note in `extension-points.md`. | No |

**Security rules summary (SRS section 7.5, as implemented in `firestore.rules`):**

- **Read** is allowed to users whose UID appears in the parent friendship's `memberIds`
  (checked via `get()` on the parent document).
- **Create** is allowed to a friendship member when the document validates: a fixed key
  set, `amountPaise` a positive integer, `description` a string up to 200 characters,
  `splits` 1–2 elements whose `sharePaise` sum equals `amountPaise` (bounded
  enumeration), `splitMethod` and `category` strings, `payerId`/`createdBy` equal to
  the caller UID, `deleted == false`, `currency == 'INR'`, `source == 'manual'`, and
  `recurringRule` absent or `null`.
- **Update** (including soft-delete) is allowed to **any** friendship member — not only
  the creator. `createdBy` and `createdAt` are immutable; `updatedAt` must equal
  `request.time`; the same sum-of-splits invariant is re-validated.
- **Delete** (hard delete) is denied for all clients; removal is modelled as a soft
  delete by setting `deleted == true`.

---

### `settlements/{settlementId}`

Top-level collection. The `settlementId` is an auto-generated Firestore document ID.

| Field | Type | Required | Default | Description | Indexed |
|---|---|---|---|---|---|
| `fromUserId` | `string` | Yes | — | UID of the user making the payment (the debtor). Security rules enforce `fromUserId == request.auth.uid` (SRS section 7.5). | Composite (see Composite Indexes) |
| `toUserId` | `string` | Yes | — | UID of the user receiving the payment (the creditor). | Composite (see Composite Indexes) |
| `amountPaise` | `integer` | Yes | — | Settlement amount in paise. Must be a positive integer (SRS section 7.3, Invariant 1). | No |
| `contextType` | `string` | Yes | — | One of `'friendship'` or `'group'` (SRS section 7.2). Identifies the context in which the settlement occurs. | Composite (see Composite Indexes) |
| `contextId` | `string` | Yes | — | The document ID of the friendship or group to which this settlement belongs. | Composite (see Composite Indexes) |
| `date` | `timestamp` | Yes | — | The date the settlement was made (user-specified). | Composite (see Composite Indexes) |
| `note` | `string \| null` | No | `null` | Optional free-text note. Maximum 200 characters. Immutable after create. | No |
| `method` | `string` | Yes | `'manual'` | Settlement method discriminator. v1.0 value is always `'manual'`. Written explicitly per ARCH-EXT-01; supports future `'upi'` value without backfill. | No |
| `verificationStatus` | `string` | Yes | `'unverified'` | Settlement verification state. v1.0 value is always `'unverified'`. **Client-read-only**; only the Cloud Functions service account may write to this field (ARCH-EXT-06, SRS section 7.5). | No |
| `currency` | `string` | Yes | `'INR'` | ISO 4217 currency code. v1.0 value is always `'INR'`. Written explicitly per ARCH-EXT-02; supports future multi-currency without backfill. | No |
| `createdAt` | `timestamp` | Yes | — | Server timestamp (`request.time` on create). Immutable after create. Required for audit history. | No |
| `deleted` | `boolean` | Yes | `false` | Soft-delete flag. The simplified-debts algorithm (PR #37 `recomputeAndWrite` extension) excludes settlements where `deleted == true` from the net-balance fold. The only field a client may mutate after create; un-delete is admin-only. | No |

**Security rules summary (SRS section 7.5):**

- Creatable only when `fromUserId == request.auth.uid`.
- Readable by both `fromUserId` and `toUserId`.
- Updatable only via soft-delete (`deleted: false → true`) by either party.
  Every other field — including `note` — is immutable.
- The `verificationStatus` field is **read-only to clients**; only the Cloud
  Functions service account may write to it (mirrors the `simplifiedBalances`
  enforcement pattern — the Invariant-2 parallel for settlements per
  ARCH-EXT-06).
- Hard-delete is denied; admin SDK bypasses for cleanup paths.

---

### `activity/{userId}/items/{itemId}`

Subcollection under a per-user activity document. The `itemId` is an auto-generated
Firestore document ID. Activity items are written **only by the Cloud Functions**
(Admin SDK) in response to expense and settlement changes and reminder sends.

| Field | Type | Required | Default | Description | Indexed |
|---|---|---|---|---|---|
| `type` | `string` | Yes | — | One of `'expense_added'`, `'expense_edited'`, `'expense_deleted'`, `'settlement'`, `'friend_added'`, or `'reminder'`. The first four are produced by `onExpenseWriteFriendship` and `onSettlementWrite`; `'friend_added'` is produced by `onFriendshipCreate`; `'reminder'` is produced by `sendReminderNotification`. There is **no** `'group_change'` producer in v1.0. | No |
| `payload` | `map` | Yes | — | Event-specific data; the shape varies by `type` (see `functions/src/triggers/on-expense-write/payload-builder.ts` and the settlement payload builder). Carries enough to render a feed item without extra reads. | No |
| `createdAt` | `timestamp` | Yes | Server timestamp | Event timestamp. Used for ordering the activity feed. | Single-field (descending) |

> **Client note:** The v1.0 client enum `ActivityEventType`
> (`lib/features/activity/domain/activity_event_type.dart`) parses the four expense
> and settlement variants plus `'friend_added'`. A `'reminder'` item is written
> server-side but has no client renderer yet, so the feed silently drops it
> (forward-compatible parsing).

**Security rules summary (SRS section 7.5):**

- Readable only by the user whose UID matches the parent `activity/{userId}` path.
- Writable only by the Cloud Functions service account. Clients may read but never
  create, update, or delete activity items.

---

### `_rateLimits/{document=**}`

Server-only bookkeeping collection used by the Cloud Functions (e.g. the reminder
rate-limit guard). Its shape is owned by the functions and is intentionally opaque to
clients.

**Security rules summary:**

- Fully locked: `allow read, write: if false` for `_rateLimits/{document=**}`. Only the
  Admin SDK (which bypasses rules) may access it.

---

## Composite Indexes

All composite indexes are defined in `firestore.indexes.json`. v1.0 defines exactly
**three** composite indexes, all at `COLLECTION` query scope, and an empty
`fieldOverrides` array (no single-field exemptions).

### Friendships by Member and Last Activity

| Property | Detail |
|---|---|
| **Collection group** | `friendships` (`COLLECTION` scope) |
| **Fields** | `memberIds` (array-contains), `lastActivityAt` (descending) |
| **Purpose** | List a user's friendships ordered by most recent activity. The client queries `where('memberIds', 'array-contains', uid).orderBy('lastActivityAt', 'desc')`. |

### Settlements by Context and Date

| Property | Detail |
|---|---|
| **Collection group** | `settlements` (`COLLECTION` scope) |
| **Fields** | `contextType` (ascending), `contextId` (ascending), `date` (descending) |
| **Purpose** | List settlements for a specific friendship or group context, ordered by most recent first. Used by the simplified-debts recompute core and the client settlement history view. |

### Expenses by Deletion State and Date

| Property | Detail |
|---|---|
| **Collection group** | `expenses` (`COLLECTION` scope) |
| **Fields** | `deleted` (ascending), `date` (descending) |
| **Purpose** | List non-deleted expenses for one parent collection, ordered by most recent first (`where('deleted', '==', false).orderBy('date', 'desc')`). Because the index is keyed by the collection ID `expenses` at `COLLECTION` scope, the **same** index serves both `friendships/{id}/expenses` and (future) `groups/{id}/expenses` single-collection queries. It does **not** serve collection-group queries, which would require `COLLECTION_GROUP` scope. |

### Indexes that are NOT defined in v1.0

These were previously documented but are absent from `firestore.indexes.json`:

- **Activity items by `createdAt`** — the feed relies on Firestore's automatic
  single-field index on `createdAt`; no composite entry is required or present.
- **Groups by member and updated timestamp** — not defined; the groups list view is a
  Sprint 3 feature with no client query yet.
- **Settlements by `fromUserId` / `toUserId` and date** — not defined; settlement
  history is queried by context (`contextType` + `contextId`), not by payer or payee.

---

## Storage Layout

Cloud Storage paths and constraints for user-uploaded binary assets.

### Avatars

| Property | Detail |
|---|---|
| **Path** | `avatars/{userId}` |
| **Maximum size** | 5 MB |
| **Permitted MIME types** | `image/jpeg`, `image/png` |
| **Access** | Readable by any authenticated user (avatars are displayed in group member lists and friendship views). Writable only by the user whose UID matches `{userId}`. |
| **Notes** | The download URL is stored in `users/{userId}.photoUrl`. When a user uploads a new avatar, the client overwrites the existing file at the same path and updates the `photoUrl` field. |

### Receipts (friendship context — shipped, FR-EX-05)

| Property | Detail |
|---|---|
| **Path** | `receipts/friendships/{friendshipId}/{expenseId}` |
| **Maximum size** | 10 MB (write) |
| **Permitted MIME types** | `image/jpeg`, `image/png` |
| **Access** | Read and write require the caller to be a member of the parent friendship, evaluated by a cross-collection `firestore.get(...).data.memberIds` lookup. Both sides share the same membership predicate so either member can view a receipt the other uploaded. |
| **Notes** | The download URL is stored in the `receiptUrl` field of the corresponding friendship expense document. |

### Receipts (group context — defensive, no UI in v1.0)

| Property | Detail |
|---|---|
| **Path** | `receipts/groups/{groupId}/{expenseId}` |
| **Maximum size** | 10 MB (write) |
| **Permitted MIME types** | `image/jpeg`, `image/png` |
| **Access** | Read and write require group membership (`firestore.get(.../groups/{groupId}).data.memberIds`). |
| **Notes** | The rule is present defensively; the group-receipt UI is part of the Sprint 3 groups epic and is not reachable in v1.0. Everything outside the avatar and two receipt paths is denied by the `match /{allPaths=**} { allow read, write: if false; }` default. |

### Lifecycle Rules

| Rule | Detail |
|---|---|
| **Orphaned file deletion** | **Not implemented in v1.0.** No scheduled Cloud Function exists to scan for and delete unreferenced files under `receipts/`. Documented as a future hardening task. |
| **Avatar cleanup on account deletion** | **Implemented.** The `deleteUserAccount` HTTPS callable (FR-AU-09, ADR-0016) deletes the caller's avatar object at `avatars/{uid}` idempotently as part of the deletion cascade (Firestore personal data → Storage avatar → Auth record last). Avatar garbage-collection on deletion is therefore covered; the orphaned-receipt sweep above remains a future task. |

---

## Cross-References

| Topic | Reference |
|---|---|
| Logical data model | SRS section 7.2 |
| Key architectural decisions | SRS section 7.3 |
| Simplified-debts algorithm | SRS section 7.4 |
| Security rules principles | SRS section 7.5 |
| Extension-point fields | `docs/design/03-architecture/extension-points.md` |
| Invariants | `.github/shared/invariants.md` |

---

## Revision History

| Date | Author | Change |
|---|---|---|
| 2025-01-XX | Solution Architect | Initial version — complete field-level schema for all collections, composite indexes, and storage layout |
| 2025-02-XX | Solution Architect | Reconciled with implemented code: friendship `createdBy`; `simplifiedBalances` absent-at-create and written by the recompute core via callable + triggers; `users` read scope (owner/friend/group placeholder) and field validation; groups marked data-layer-only; group-expense subcollection has no rules; activity `type` set corrected (`reminder` added, `group_change` removed); composite indexes reduced to the three real entries; storage receipt paths and not-implemented lifecycle rules; added `_rateLimits`. |
