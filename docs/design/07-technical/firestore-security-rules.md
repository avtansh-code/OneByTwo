# Firestore Security Rules — Design Outline

> **Status:** Draft
> **Author:** Solution Architect
> **References:** SRS section 7.5 (Security Rules Principles), SRS section 7.2
> (Firestore Data Model), SRS section 7.3 (Key Architectural Decisions),
> Invariant 1 (integer paise), Invariant 2 (simplifiedBalances is
> client-read-only), ADR-0001, ADR-0002.

This document describes the intended Firestore Security Rules in plain English.
It is **not** final rules code. It serves as the specification from which the
actual `firestore.rules` file shall be implemented and tested.

All rules assume that `request.auth != null` unless stated otherwise. No
collection permits unauthenticated access (SRS section 7.5: "Public collections
do not exist; everything is participant-scoped").

---

## Global Defaults

- **Deny all** by default. Every path must have an explicit allow rule.
- All timestamps written by clients must be `request.time` (server timestamp);
  clients may not backdate or forward-date `createdAt` or `updatedAt`.
- No document may be read or written by an unauthenticated request.

---

## users/{userId}

### Read

- Allowed only when `request.auth.uid == userId`.
- A user may read only their own profile document.

### Create

- Allowed only when `request.auth.uid == userId`.
- Required fields: `phoneNumber` (string, must match `+91` followed by exactly
  10 digits), `displayName` (string, 1-50 characters), `createdAt` (timestamp),
  `updatedAt` (timestamp).
- `fcmTokens` must be a list with at most 10 entries.

### Update

- Allowed only when `request.auth.uid == userId`.
- The `phoneNumber` field is **immutable after creation**. An update request that
  changes `phoneNumber` from its current value must be denied. (Re-verification
  is handled by a Cloud Function, not a client write.)
- The `fcmTokens` array must not exceed 10 entries after the write.
- `createdAt` is immutable; updates must not change it.

### Delete

- Denied to all clients. Account deletion is handled by a Cloud Function
  (SRS section 7.3).

---

## friendships/{friendshipId}

### Read

- Allowed only when `request.auth.uid` is present in the document's `memberIds`
  array.

### Create

- Allowed only when `request.auth.uid` is present in the incoming `memberIds`
  array.
- `memberIds` must be a list of exactly 2 strings.
- `memberIds` must be sorted in ascending lexicographic order (deterministic ID
  derivation; SRS section 7.2).
- The `simplifiedBalances` field must not be present in the incoming data (it is
  initialised by the Cloud Function).

### Update

- Allowed only when `request.auth.uid` is present in the existing document's
  `memberIds` array.
- **The `simplifiedBalances` field must not be modified by the client.** If the
  incoming data changes `simplifiedBalances` from the existing value, the write
  must be denied. Only the Cloud Functions service account may write this field
  (Invariant 2; SRS sections 4.6, 7.3, 7.5; ADR-0001).
- `memberIds` is immutable after creation.

### Delete

- Allowed only when `request.auth.uid` is present in the existing `memberIds`
  array **and** the existing `simplifiedBalances` map is either absent, empty, or
  contains only zero-value entries for all pairs.
- Rationale: preventing deletion whilst debts are outstanding protects both
  parties from data loss.

---

## groups/{groupId}

### Read

- Allowed only when `request.auth.uid` is present in the document's `memberIds`
  array.

### Create

- Allowed only when `request.auth.uid` is present in the incoming `memberIds`
  array.
- The `adminId` field must equal `request.auth.uid` (the creator becomes the
  admin).
- Required fields: `name` (string, 1-100 characters), `type` (one of `trip`,
  `home`, `couple`, `other`), `memberIds` (list of strings, at least 1 entry),
  `adminId`, `createdAt`, `updatedAt`.
- The `simplifiedBalances` field must not be present in the incoming data.

### Update

- Allowed only when `request.auth.uid` is present in the existing document's
  `memberIds` array.
- **The `simplifiedBalances` field must not be modified by the client.** Same
  enforcement as friendships (Invariant 2).
- The `adminId` field may only be changed if `request.auth.uid == resource.data.adminId`
  (i.e., only the current admin can transfer admin rights).
- `createdAt` is immutable.

### Delete

- Allowed only when `request.auth.uid == resource.data.adminId` **and** the
  existing `simplifiedBalances` map is either absent, empty, or contains only
  zero-value entries for all pairs.

---

## friendships/{friendshipId}/expenses/{expenseId}

### Read

- Allowed only when `request.auth.uid` is present in the parent friendship
  document's `memberIds` array.

### Create

- Allowed only when `request.auth.uid` is present in the parent friendship
  document's `memberIds` array.
- **Monetary validation (Invariant 1; ADR-0002):**
  - `amountPaise` must be an integer greater than 0.
  - Each element in the `splits` array must have a `sharePaise` field that is an
    integer greater than or equal to 0.
  - The sum of all `sharePaise` values across `splits` must equal `amountPaise`
    exactly (SRS section 7.5).
- `payerId` must be a string present in the parent friendship's `memberIds`.
- `splitMethod` must be one of: `equal`, `unequal`, `percentage`, `shares`,
  `exact`.
- `deleted` must be `false` on creation.
- `createdBy` must equal `request.auth.uid`.

### Update

- Allowed only when `request.auth.uid == resource.data.createdBy` (only the
  original creator may edit).
- The same monetary validation rules as create apply to the updated data.
- `createdBy` and `createdAt` are immutable.

### Delete (soft)

- Hard deletes are denied.
- A soft delete is an update that sets `deleted = true`. This is allowed only
  when `request.auth.uid == resource.data.createdBy`.

---

## groups/{groupId}/expenses/{expenseId}

### Read

- Allowed only when `request.auth.uid` is present in the parent group document's
  `memberIds` array.

### Create

- Allowed only when `request.auth.uid` is present in the parent group document's
  `memberIds` array.
- Same monetary validation as friendship expenses (Invariant 1; ADR-0002):
  - `amountPaise` must be an integer greater than 0.
  - Each `sharePaise` must be an integer greater than or equal to 0.
  - `sum(sharePaise) == amountPaise` exactly.
- `payerId` must be present in the parent group's `memberIds`.
- `splitMethod` must be one of: `equal`, `unequal`, `percentage`, `shares`,
  `exact`.
- `deleted` must be `false` on creation.
- `createdBy` must equal `request.auth.uid`.

### Update

- Allowed only when `request.auth.uid == resource.data.createdBy`.
- Same monetary validation as create.
- `createdBy` and `createdAt` are immutable.

### Delete (soft)

- Hard deletes are denied.
- Soft delete (setting `deleted = true`) is allowed only when
  `request.auth.uid == resource.data.createdBy`.

---

## settlements/{settlementId}

### Read

- Allowed only when `request.auth.uid == resource.data.fromUserId` or
  `request.auth.uid == resource.data.toUserId`.

### Create

- Allowed only when `request.auth.uid == request.resource.data.fromUserId`
  (SRS section 7.5: "Settlement writes shall validate that
  `fromUserId == request.auth.uid`").
- `amountPaise` must be an integer greater than 0 (Invariant 1).
- `contextType` must be one of: `friendship`, `group`.
- `contextId` must be a non-empty string.
- `toUserId` must be a non-empty string and must differ from `fromUserId`.

### Update

- Denied to all clients. Settlements are immutable once created.

### Delete

- Denied to all clients. Settlements are never removed.

---

## activity/{userId}/items/{itemId}

### Read

- Allowed only when `request.auth.uid == userId` (the owning user).

### Write (create, update, delete)

- Denied to all clients. Activity items are written exclusively by Cloud
  Functions (SRS section 7.3).

---

## Negative Test Cases

The following test cases must be included in the security rules test suite
(run against the Firebase Emulator Suite; SRS section 8.2). Each case asserts
that a disallowed operation is rejected.

### 1. Client attempts to write `simplifiedBalances` — DENIED

> **Setup:** Authenticated user who is a member of a friendship (or group).
> **Action:** Update the friendship (or group) document, setting or modifying the
> `simplifiedBalances` field.
> **Expected:** Write is denied.
> **Invariant:** 2 (simplifiedBalances is client-read-only).
> **SRS:** sections 4.6, 7.3, 7.5.

### 2. Client creates expense with splits not summing to total — DENIED

> **Setup:** Authenticated user who is a member of a friendship.
> **Action:** Create an expense document where `sum(splits[*].sharePaise) != amountPaise`.
> **Expected:** Write is denied.
> **Invariant:** 1 (money is integer paise; splits must be exact).
> **SRS:** section 7.5.
> **ADR:** ADR-0002.

### 3. Non-participant attempts to read group — DENIED

> **Setup:** Authenticated user whose UID is not in the group's `memberIds`.
> **Action:** Attempt to `get()` the group document.
> **Expected:** Read is denied.
> **SRS:** section 7.5 ("everything is participant-scoped").

### 4. Non-creator attempts to edit expense — DENIED

> **Setup:** Authenticated user who is a member of the parent friendship/group
> but did not create the expense (i.e., `request.auth.uid != resource.data.createdBy`).
> **Action:** Attempt to update any field on the expense document.
> **Expected:** Write is denied.

### 5. User attempts to delete friendship with non-zero balance — DENIED

> **Setup:** Authenticated user who is a member of a friendship. The friendship's
> `simplifiedBalances` contains at least one non-zero amount.
> **Action:** Attempt to delete the friendship document.
> **Expected:** Delete is denied.

### 6. Client attempts to write activity item — DENIED

> **Setup:** Authenticated user attempting to create a document in their own
> `activity/{userId}/items` subcollection.
> **Action:** Attempt to create (or update, or delete) an activity item.
> **Expected:** Write is denied.
> **SRS:** section 7.3 (activity is Cloud-Function-written only).

### 7. Settlement created with `fromUserId` not matching auth UID — DENIED

> **Setup:** Authenticated user attempting to create a settlement where
> `fromUserId` is a different user's UID.
> **Action:** Create a settlement document with `fromUserId != request.auth.uid`.
> **Expected:** Write is denied.
> **SRS:** section 7.5.

### 8. Expense created with non-integer or non-positive `amountPaise` — DENIED

> **Setup:** Authenticated user who is a member of a friendship.
> **Action:** Create an expense with `amountPaise` set to `0`, a negative number,
> a floating-point value, or a string.
> **Expected:** Write is denied.
> **Invariant:** 1.
> **ADR:** ADR-0002.

### 9. Non-admin attempts to change group `adminId` — DENIED

> **Setup:** Authenticated user who is a group member but not the current admin.
> **Action:** Update the group document, changing `adminId` to their own UID.
> **Expected:** Write is denied.

### 10. User attempts to update own `phoneNumber` — DENIED

> **Setup:** Authenticated user updating their own user document.
> **Action:** Change the `phoneNumber` field to a different value.
> **Expected:** Write is denied.

---

## Implementation Notes

- The `simplifiedBalances` write-guard (Invariant 2) can be implemented by
  comparing `request.resource.data.simplifiedBalances` with
  `resource.data.simplifiedBalances` on every client update and denying if they
  differ. Cloud Functions bypass Security Rules when using the Admin SDK, so no
  additional allow rule is needed for server writes.
- Split-sum validation requires a helper function in the rules file. Firestore
  rules support `list` operations but not arbitrary loops; the implementation may
  need to enumerate split indices up to a reasonable maximum (e.g., 50
  participants) or use `math.abs(sum - total) == 0` via a computed field. The
  Functions Dev should confirm the feasible approach during implementation.
- All rules should be tested using `@firebase/rules-unit-testing` against the
  Emulator Suite (SRS section 8.2; Invariant 4).
