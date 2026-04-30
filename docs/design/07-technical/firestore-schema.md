# Firestore Schema — Final Design

> **Document owner:** Solution Architect
> **Version:** 1.0
> **Status:** Approved baseline
> **Audience:** Solution Architect, Flutter Developer, Cloud Functions Developer, DevOps Engineer

---

## Purpose

This document specifies the complete Firestore data model for OneByTwo v1.0. It
expands the logical model defined in SRS section 7.2 into a field-level reference
that the Flutter Developer and Cloud Functions Developer use when creating, reading,
or validating documents. Every field includes its type, whether it is required, its
default value, and whether it is indexed.

Extension-point fields from `docs/design/03-architecture/extension-points.md` are
included with their v1.0 default values. Per the extension-points design principle 1,
these fields are explicitly written at document creation time — never omitted.

All monetary values are stored as **integer paise** (1 INR = 100 paise). Conversion
to rupees occurs exclusively at the UI layer (SRS section 7.3, Invariant 1).

---

## Collections

### `users/{userId}`

The `userId` matches the Firebase Authentication UID assigned at phone-number sign-up.

| Field | Type | Required | Default | Description | Indexed |
|---|---|---|---|---|---|
| `phoneNumber` | `string` | Yes | — | E.164 format, restricted to `+91` prefix (SRS section 1.3). | Single-field (ascending) |
| `displayName` | `string` | Yes | — | User-chosen display name. Maximum 50 characters. | No |
| `photoUrl` | `string \| null` | No | `null` | Cloud Storage download URL for the user's avatar. See Storage Layout section. | No |
| `fcmTokens` | `array<string>` | Yes | `[]` | One entry per device. Managed by the client on app launch; pruned by Cloud Functions on send failure (SRS section 7.2). | No |
| `createdAt` | `timestamp` | Yes | Server timestamp | Document creation time. Set once, never updated. | No |
| `updatedAt` | `timestamp` | Yes | Server timestamp | Last modification time. Updated on every write. | No |
| `notificationPrefs` | `map` | Yes | `{ newExpense: true, settlement: true, reminder: true }` | Boolean flags controlling push notification categories (SRS section 7.2). | No |
| `locale` | `string` | Yes | `'en-IN'` | BCP 47 locale code. v1.0 supports only `'en-IN'`. Written explicitly per ARCH-EXT-04; supports future localisation without backfill. | No |

**Security rules summary (SRS section 7.5):**

- A user document is readable and writable only by the authenticated user whose UID
  matches the document ID (`request.auth.uid == userId`).

---

### `friendships/{friendshipId}`

The `friendshipId` is a deterministic composite key formed by sorting the two member
UIDs lexicographically and joining them with an underscore (e.g.,
`uid_A_uid_B` where `uid_A < uid_B`). This guarantees a single document per pair
(SRS section 7.2).

| Field | Type | Required | Default | Description | Indexed |
|---|---|---|---|---|---|
| `memberIds` | `array<string>` (exactly 2) | Yes | — | Sorted ascending. Used for access-control checks in security rules. | Single-field (array-contains) |
| `simplifiedBalances` | `map` | Yes | `{}` | Nested map: `{ [debtorUserId]: { [creditorUserId]: amountPaise } }`. **Server-maintained, client-read-only** (SRS section 7.3, Invariant 2). Written solely by the `recomputeSimplifiedBalances` Cloud Function. | No |
| `lastActivityAt` | `timestamp` | Yes | Server timestamp | Updated by Cloud Functions whenever an expense or settlement is created, edited, or deleted within this friendship context. | Composite (see Composite Indexes) |

**Security rules summary (SRS section 7.5):**

- Readable and writable only by users whose UID appears in `memberIds`.
- The `simplifiedBalances` field is **read-only to clients**; only the Cloud
  Functions service account may write to it.

---

### `groups/{groupId}`

The `groupId` is an auto-generated Firestore document ID.

| Field | Type | Required | Default | Description | Indexed |
|---|---|---|---|---|---|
| `name` | `string` | Yes | — | Group display name. Maximum 100 characters. | No |
| `type` | `string` | Yes | — | One of `'trip'`, `'home'`, `'couple'`, `'other'` (SRS section 7.2). | No |
| `coverPhotoUrl` | `string \| null` | No | `null` | Cloud Storage download URL for the group cover image. | No |
| `memberIds` | `array<string>` | Yes | — | UIDs of all current group members. Used for access-control checks in security rules. | Single-field (array-contains) |
| `adminId` | `string` | Yes | — | UID of the group administrator. Must be present in `memberIds`. | No |
| `simplifiedBalances` | `map` | Yes | `{}` | Nested map: `{ [debtorUserId]: { [creditorUserId]: amountPaise } }`. **Server-maintained, client-read-only** (SRS section 7.3, Invariant 2). Written solely by the `recomputeSimplifiedBalances` Cloud Function. | No |
| `createdAt` | `timestamp` | Yes | Server timestamp | Document creation time. Set once, never updated. | No |
| `updatedAt` | `timestamp` | Yes | Server timestamp | Last modification time. Updated on every write. | No |

**Security rules summary (SRS section 7.5):**

- Readable only by users whose UID appears in `memberIds`.
- Writable (create, update) only by members; certain admin-only operations
  (e.g., removing a member) restricted to the user whose UID matches `adminId`.
- The `simplifiedBalances` field is **read-only to clients**; only the Cloud
  Functions service account may write to it.

---

### `groups/{groupId}/expenses/{expenseId}`

Subcollection of a group document. The `expenseId` is an auto-generated Firestore
document ID.

| Field | Type | Required | Default | Description | Indexed |
|---|---|---|---|---|---|
| `amountPaise` | `integer` | Yes | — | Total expense amount in paise. Must be a positive integer (SRS section 7.3, Invariant 1). | No |
| `description` | `string` | Yes | — | Free-text description. Maximum 200 characters. | No |
| `category` | `string` | Yes | — | Expense category enum value (e.g., `'food'`, `'transport'`, `'utilities'`, `'entertainment'`, `'other'`). | No |
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

**Security rules summary (SRS section 7.5):**

- Readable and writable only by users whose UID appears in the parent group's
  `memberIds`.
- On create and update, security rules validate that the sum of `splits[*].sharePaise`
  equals `amountPaise`.

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
| `splits` | `array<map>` | Yes | — | Each element: `{ userId: string, sharePaise: integer }`. The sum of all `sharePaise` values must equal `amountPaise`. | No |
| `splitMethod` | `string` | Yes | — | One of `'equal'`, `'unequal'`, `'percentage'`, `'shares'`, `'exact'`. | No |
| `receiptUrl` | `string \| null` | No | `null` | Cloud Storage download URL for the receipt image. | No |
| `createdBy` | `string` | Yes | — | UID of the member who created the expense record. | No |
| `createdAt` | `timestamp` | Yes | Server timestamp | Document creation time. Set once, never updated. | No |
| `updatedAt` | `timestamp` | Yes | Server timestamp | Last modification time. Updated on every write. | No |
| `deleted` | `boolean` | Yes | `false` | Soft-delete flag (SRS section 7.3). | Composite (see Composite Indexes) |
| `source` | `string` | Yes | `'manual'` | Expense creation source. v1.0: always `'manual'` (ARCH-EXT-07). | No |
| `currency` | `string` | Yes | `'INR'` | ISO 4217 currency code. v1.0: always `'INR'` (ARCH-EXT-02). | No |
| `recurringRule` | `map \| null` | No | `null` | Recurring expense rule. v1.0: always `null` (ARCH-EXT-03). | No |

**Security rules summary (SRS section 7.5):**

- Readable and writable only by users whose UID appears in the parent friendship's
  `memberIds`.
- On create and update, security rules validate that the sum of `splits[*].sharePaise`
  equals `amountPaise`.

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
| `note` | `string \| null` | No | `null` | Optional free-text note. Maximum 200 characters. | No |
| `method` | `string` | Yes | `'manual'` | Settlement method discriminator. v1.0 value is always `'manual'`. Written explicitly per ARCH-EXT-01; supports future `'upi'` value without backfill. | No |
| `verificationStatus` | `string` | Yes | `'unverified'` | Settlement verification state. v1.0 value is always `'unverified'`. **Client-read-only**; only the Cloud Functions service account may write to this field (ARCH-EXT-06, SRS section 7.5). | No |
| `currency` | `string` | Yes | `'INR'` | ISO 4217 currency code. v1.0 value is always `'INR'`. Written explicitly per ARCH-EXT-02; supports future multi-currency without backfill. | No |

**Security rules summary (SRS section 7.5):**

- Creatable only when `fromUserId == request.auth.uid`.
- Readable by both `fromUserId` and `toUserId`.
- The `verificationStatus` field is **read-only to clients**; only the Cloud
  Functions service account may write to it (mirrors the `simplifiedBalances`
  enforcement pattern).

---

### `activity/{userId}/items/{itemId}`

Subcollection under a per-user activity document. The `itemId` is an auto-generated
Firestore document ID. Activity items are written by Cloud Functions in response to
expense, settlement, and group-change events (SRS section 7.2).

| Field | Type | Required | Default | Description | Indexed |
|---|---|---|---|---|---|
| `type` | `string` | Yes | — | One of `'expense_added'`, `'expense_edited'`, `'expense_deleted'`, `'settlement'`, `'group_change'` (SRS section 7.2). | No |
| `payload` | `map` | Yes | — | Event-specific data. Structure varies by `type`. Contains sufficient information for the client to render an activity feed item without additional reads (e.g., expense description, amount, group name). | No |
| `createdAt` | `timestamp` | Yes | Server timestamp | Event timestamp. Used for ordering the activity feed. | Single-field (descending) |

**Security rules summary (SRS section 7.5):**

- Readable only by the user whose UID matches the parent `activity/{userId}` path.
- Writable only by the Cloud Functions service account. Clients may read but never
  create, update, or delete activity items.

---

## Composite Indexes

All composite indexes are defined in `firestore.indexes.json` (SRS section 7.3).
The following indexes are required for the query patterns used by the Flutter client
and Cloud Functions.

### Group Expenses by Date

| Property | Detail |
|---|---|
| **Collection** | `groups/{groupId}/expenses` (collection scope) |
| **Fields** | `deleted` (ascending), `date` (descending) |
| **Purpose** | List non-deleted expenses for a group, ordered by most recent date first. The client queries `where('deleted', '==', false).orderBy('date', 'desc')`. |

### Friendship Expenses by Date

| Property | Detail |
|---|---|
| **Collection** | `friendships/{friendshipId}/expenses` (collection scope) |
| **Fields** | `deleted` (ascending), `date` (descending) |
| **Purpose** | List non-deleted expenses for a friendship, ordered by most recent date first. |

### Settlements by Context and Date

| Property | Detail |
|---|---|
| **Collection** | `settlements` (collection scope) |
| **Fields** | `contextType` (ascending), `contextId` (ascending), `date` (descending) |
| **Purpose** | List settlements for a specific friendship or group context, ordered by most recent date first. Used by the `recomputeSimplifiedBalances` Cloud Function and the client settlement history view. |

### Friendships by Member and Last Activity

| Property | Detail |
|---|---|
| **Collection** | `friendships` (collection scope) |
| **Fields** | `memberIds` (array-contains), `lastActivityAt` (descending) |
| **Purpose** | List a user's friendships ordered by most recent activity. The client queries `where('memberIds', 'array-contains', uid).orderBy('lastActivityAt', 'desc')`. |

### Groups by Member and Updated Timestamp

| Property | Detail |
|---|---|
| **Collection** | `groups` (collection scope) |
| **Fields** | `memberIds` (array-contains), `updatedAt` (descending) |
| **Purpose** | List a user's groups ordered by most recently updated. |

### Activity Items by Created Timestamp

| Property | Detail |
|---|---|
| **Collection** | `activity/{userId}/items` (collection scope) |
| **Fields** | `createdAt` (descending) |
| **Purpose** | Paginated activity feed for a user, ordered by most recent first. This is a single-field index and is created automatically by Firestore; listed here for completeness. |

### Settlements by User and Date

| Property | Detail |
|---|---|
| **Collection** | `settlements` (collection scope) |
| **Fields** | `fromUserId` (ascending), `date` (descending) |
| **Purpose** | List settlements made by a specific user, ordered by most recent date first. |

| Property | Detail |
|---|---|
| **Collection** | `settlements` (collection scope) |
| **Fields** | `toUserId` (ascending), `date` (descending) |
| **Purpose** | List settlements received by a specific user, ordered by most recent date first. |

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

### Receipts

| Property | Detail |
|---|---|
| **Path** | `receipts/{contextType}/{contextId}/{expenseId}` |
| **Maximum size** | 10 MB |
| **Permitted MIME types** | `image/jpeg`, `image/png` |
| **Access** | Readable and writable only by users who are members of the associated group or friendship (validated by matching against the `memberIds` of the context document). |
| **Notes** | The download URL is stored in the `receiptUrl` field of the corresponding expense document. `contextType` is either `groups` or `friendships`; `contextId` is the group or friendship document ID. |

### Lifecycle Rules

| Rule | Detail |
|---|---|
| **Orphaned file deletion** | Files under `receipts/` that are not referenced by any expense document's `receiptUrl` field shall be deleted after 90 days. This is enforced by a scheduled Cloud Function that scans for orphaned references, not by a Cloud Storage lifecycle policy (Firestore cross-reference is required). |
| **Avatar cleanup on account deletion** | When a user account is deleted (SRS section 4.9), the account-deletion Cloud Function deletes the corresponding file at `avatars/{userId}`. |

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
