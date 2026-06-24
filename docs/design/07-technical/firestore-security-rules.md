# Firestore Security Rules — Design Outline

> **Status:** Draft
> **Author:** Solution Architect
> **References:** SRS section 7.5 (Security Rules Principles), SRS section 7.2
> (Firestore Data Model), SRS section 7.3 (Key Architectural Decisions),
> Invariant 1 (integer paise), Invariant 2 (simplifiedBalances is
> client-read-only), ADR-0001, ADR-0002.

This document describes the Firestore Security Rules in plain English. It is a
companion to the implemented `firestore.rules` file and has been **reconciled with
that implementation**; where the rules and this prose differ, `firestore.rules` is
authoritative. Storage rules are summarised at the end (`storage.rules`).

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

- Allowed when `request.auth.uid == userId` (own document).
- Allowed when the caller shares a friendship with the target user. This is checked
  by the `isInFriendshipWith` helper, which derives the deterministic friendship ID
  (sorted UIDs joined with `_`) and calls `exists()` on it — it does not scan
  `memberIds`.
- Allowed when the caller shares a group with the target user (`isInGroupWith`). This
  helper is a **v1.0 placeholder that returns `false`** (groups are Sprint 3), so in
  practice reads resolve to owner-or-friend.
- Note: phone-number queries are NOT permitted from clients. The Cloud Function
  `lookupUserByPhoneNumber` performs phone-number lookups server-side with
  elevated permissions (Admin SDK). See ADR-0014.

### Create

- Allowed only when `request.auth.uid == userId` (`isValidUserCreate`).
- The key set is locked: the document must contain exactly `phoneNumber`,
  `displayName`, `fcmTokens`, `createdAt`, `updatedAt`, `notificationPrefs`, `locale`
  (and optionally `photoUrl`).
- `phoneNumber` must equal `request.auth.token.phone_number` (not merely match a `+91`
  pattern — it is bound to the verified token claim).
- `displayName` is a string of 1–50 characters.
- `photoUrl`, if present, is `null` or a string.
- `fcmTokens` must be a list. **No size cap is enforced.**
- `createdAt` and `updatedAt` must both equal `request.time`.
- `notificationPrefs` must be a map with exactly the boolean keys `newExpense`,
  `settlement`, and `reminder`.
- `locale` must equal `'en-IN'`.

### Update

- Allowed only when `request.auth.uid == userId` (`isValidUserUpdate`), with the same
  locked key set as create.
- `phoneNumber` and `createdAt` are **immutable**; an update that changes either is
  denied.
- `displayName` (1–50), `photoUrl` (null or string), `fcmTokens` (a list, **no cap**),
  `notificationPrefs` (the three boolean flags), and `locale == 'en-IN'` must remain
  valid. `updatedAt` must equal `request.time`.

### Delete

- Denied to all clients (`allow delete: if false`). There is **no account-deletion
  Cloud Function** in v1.0, so no server path deletes user documents either.

---

## friendships/{friendshipId}

### Read

- Allowed only when `request.auth.uid` is present in the document's `memberIds`
  array.

### Create

- Allowed only when `request.auth.uid` is present in the incoming `memberIds`
  array (`isValidFriendshipCreate`).
- `memberIds` must be a list of exactly 2 strings.
- `memberIds` must be sorted in ascending order — the rule asserts
  `memberIds[0] < memberIds[1]`.
- The `simplifiedBalances` field must **not** be present in the incoming data (it is
  initialised later by the server-side recompute core).
- `createdBy` must equal `request.auth.uid`.
- `lastActivityAt` must equal `request.time`.
- There is **no rule that ties the document ID to the sorted-UID composite**. The
  ordering guarantee comes from the `memberIds[0] < memberIds[1]` check plus the
  client's deterministic ID construction, not from a `request.resource.id` assertion.

### Update

- Allowed only when `request.auth.uid` is present in the existing document's
  `memberIds` array (`isValidFriendshipUpdate`).
- **The `simplifiedBalances` field must not be modified by the client.** Enforced by
  `request.resource.data.diff(resource.data).affectedKeys().hasAny(['simplifiedBalances'])`
  — any client write that touches the key is denied. Only the server-side recompute
  core may write it (Invariant 2; ADR-0001).
- `memberIds` and `createdBy` are immutable after creation (same `affectedKeys` guard).

### Delete

- Denied to all clients (`allow delete: if false`). There is **no** balance-conditional
  delete path — the earlier "delete only at zero balance" design was not implemented.
  Friendships are never hard-deleted from the client.

---

## groups/{groupId}

> **Implementation status (v1.0):** Group rules exist but there is **no client UI or
> client data layer** for groups (Sprint 3). The rules below are live in
> `firestore.rules` for forward-compatibility but are not exercised by the v1.0 app.

### Read

- Allowed only when `request.auth.uid` is present in the document's `memberIds`
  array.

### Create

- Allowed only when `request.auth.uid` is present in the incoming `memberIds` array
  **and** `adminId == request.auth.uid` (the creator becomes the admin).
- `isValidGroupCreate` requires: `simplifiedBalances` absent, `name` a string of
  1–100 characters, `type` in `['trip', 'home', 'couple', 'other']`, `memberIds`
  a list (size **not** constrained beyond "is a list"), and
  `createdAt == updatedAt == request.time`.
- Unlike friendships and expenses, the group create rule does **not** lock the key
  set (no `hasOnly`/`hasAll`), so additional fields such as `coverPhotoUrl` are
  permitted without further validation.

### Update

- Allowed only when `request.auth.uid` is present in the existing document's
  `memberIds` array (`isValidGroupUpdate`).
- **The `simplifiedBalances` field must not be modified by the client** (same
  `affectedKeys().hasAny([...])` guard as friendships; Invariant 2).
- `createdAt` is immutable.
- `adminId` may change only if `request.auth.uid == resource.data.adminId` (only the
  current admin can transfer admin rights). Note `memberIds` is **not** locked on
  group update.

### Delete

- Denied to all clients (`allow delete: if false`). There is no admin-only or
  zero-balance delete path; the earlier conditional-delete design was not implemented.

---

## friendships/{friendshipId}/expenses/{expenseId}

### Read

- Allowed only when `request.auth.uid` is present in the parent friendship
  document's `memberIds` array.

### Create

- Allowed only when `request.auth.uid` is present in the parent friendship document's
  `memberIds` array (`isCallerFriendshipMember`, resolved via `get()`).
- The key set is locked: `hasOnlyKnownKeys` + `hasAllRequiredKeys` permit
  `amountPaise`, `description`, `category`, `date`, `payerId`, `splits`,
  `splitMethod`, `receiptUrl`, `createdBy`, `createdAt`, `updatedAt`, `deleted`,
  `source`, `currency`, `recurringRule` (the last three being extension fields;
  `receiptUrl` and `recurringRule` are optional).
- **Shape (`isValidShape`):** `amountPaise` is an integer > 0; `description` a string
  ≤ 200 chars; `category` a string; `date` a timestamp; `payerId` a string; `splits`
  a list of **1–2** elements; `splitMethod` in `['equal','unequal','percentage','shares','exact']`;
  `receiptUrl` absent/null/string; `createdBy` a string; `createdAt`/`updatedAt`
  timestamps; `deleted` a bool.
- **Monetary validation (Invariant 1; ADR-0002)** via **bounded enumeration**, not a
  loop: each present split (indices 0 and 1 only) must have a string `userId` that is
  in the friendship `memberIds` and an integer `sharePaise ≥ 0`, and
  `shareAt(splits,0) + shareAt(splits,1) == amountPaise`, where `shareAt` yields 0 for
  an out-of-range index. The 1–2 cap is deliberate: a friendship has exactly two
  members, so splits beyond index 1 cannot add value.
- `payerId` must be present in the parent friendship's `memberIds`.
- Extension-point locks: `currency == 'INR'`, `source == 'manual'`, and `recurringRule`
  absent **or** `null` (ARCH-EXT-02/07/03).
- `deleted` must be `false`; `createdBy` must equal `request.auth.uid`; `createdAt` and
  `updatedAt` must equal `request.time`.

### Update

- Allowed when `request.auth.uid` is present in the parent friendship's `memberIds` —
  i.e., by **any** friendship member, **not** only the original creator.
- The same shape and sum-of-splits validation as create is re-applied to the new data.
- `createdBy` and `createdAt` are immutable; `updatedAt` must equal `request.time`.

### Delete (soft)

- Hard deletes are denied (`allow delete: if false`).
- A soft delete is an update that sets `deleted = true`, flowing through the update
  rule above. It is therefore allowed for **any** friendship member, not only the
  creator.

---

## groups/{groupId}/expenses/{expenseId}

**Not implemented in v1.0.** `firestore.rules` defines **no `match` block** for this
subcollection, so under the top-of-file default-deny all client access is rejected.
The friendship-expense rules above are the implemented model; the equivalent group
rules (with a bounded enumeration sized to the group-member cap) are a Sprint 3 task.

---

## groupInvites/{token}

> **Implementation status (design outline, Sprint 3):** This is a **forward design** for
> the FR-GR-02 / FR-GR-03 invite-link flow (ADR-0023). **No `match` block for
> `groupInvites/{token}` exists in `firestore.rules` in v1.0**, so under the top-of-file
> default-deny all access is currently rejected. The outline below is the intended
> Sprint 3 shape, ratified now (ADR-0023) so the groups epic is not designed blind. The
> collection is **server/admin-managed** — see `firestore-schema.md`
> (`groupInvites/{token}`) for the field-level model.

The document ID **is** the invite token (high-entropy, server-generated). A token holder
who is not yet a group member must be able to resolve the invite **without** reading the
membership-gated group document, which is why this is a top-level collection keyed by the
token rather than a `groups/{groupId}/invites/{token}` subcollection (ADR-0023).

### Read

- Allowed to any signed-in user performing a **get by token** (the document ID is the
  unguessable token), but only while the token is **live**:
  `resource.data.revoked == false && request.time < resource.data.expiresAt`
  (the 7-day expiry check; ADR-0023).
- **List/query is denied** (`allow list: if false`) so tokens cannot be enumerated; a
  token can only be fetched by its exact id.

### Create

- **Denied to direct client writes.** Tokens are minted **server-side** by the
  `createGroupInvite` callable acting for the group admin, which sets `createdBy` to the
  caller (who must be the group's `adminId`), `createdAt == request.time`,
  `expiresAt == createdAt + 7 days`, and `revoked == false`. Running the mint through a
  callable keeps token entropy and the expiry window server-controlled.

### Update

- Limited to **revocation by the group admin**: the only permitted change is flipping
  `revoked` from `false` to `true`, and only when `request.auth.uid` is the group's
  `adminId`. `token`, `groupId`, `createdBy`, `createdAt`, and `expiresAt` are immutable.
- Acceptance does **not** mutate the token — the `acceptGroupInvite` callable validates
  liveness and adds the caller to `groups/{groupId}.memberIds` server-side.

### Delete

- Denied to all clients (`allow delete: if false`). Expired tokens are reaped by a
  server-side lifecycle task, not by client delete.

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
- Both `fromUserId` and `toUserId` must be members of the parent context
  (`memberIds` on the friendship/group document).
- Extension-point locks (v1.0 fixed values per
  `extension-points-register.md`):
  - `method == 'manual'` (ARCH-EXT-01).
  - `currency == 'INR'` (ARCH-EXT-02).
  - `verificationStatus == 'unverified'` (ARCH-EXT-06).
- `deleted` must be `false` on create.
- `createdAt` must equal `request.time`.
- The document MAY contain only the whitelisted fields:
  `fromUserId`, `toUserId`, `amountPaise`, `contextType`, `contextId`,
  `date`, `note`, `method`, `verificationStatus`, `currency`,
  `createdAt`, `deleted`.

### Update

- Allowed for either party (`fromUserId` or `toUserId`) — soft-delete only.
- The ONLY field that may change is `deleted` (false → true). All other
  fields are immutable, including `note`. The check uses Firestore's
  `affectedKeys()` to enforce `hasOnly(['deleted'])`.
- Un-delete is denied (clients cannot set `deleted` back to false).
- `verificationStatus` is **client-read-only** — only the Cloud Functions
  service account may write to this field (mirrors the
  `simplifiedBalances` Invariant-2 enforcement pattern; ARCH-EXT-06).
  v1.0 has no server-side writer; the field stays at the literal
  `'unverified'` default.

### Delete

- Denied to all clients (hard-delete is admin-SDK only). Soft-delete via
  update is the supported client path.

---

## activity/{userId}/items/{itemId}

### Read

- Allowed only when `request.auth.uid == userId` (the owning user).

### Write (create, update, delete)

- Denied to all clients. Activity items are written exclusively by Cloud
  Functions (SRS section 7.3).

---

## _rateLimits/{document=**}

### Read / Write (all operations)

- Denied to all clients: `match /_rateLimits/{document=**} { allow read, write: if false; }`.
  This collection is internal infrastructure managed exclusively by Cloud Functions via
  the Admin SDK (which bypasses rules). The path is a recursive wildcard, so every
  document at any depth under `_rateLimits/` is locked.

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

### 4. Member attempts to mutate `createdBy`/`createdAt` on an expense — DENIED

> **Setup:** Authenticated user who is a member of the parent friendship.
> **Action:** Update an expense, changing `createdBy` or `createdAt`.
> **Expected:** Write is denied (`isValidExpenseUpdate` pins both to their previous
> values).
> **Note (correction):** Being the original creator is **not** required to edit a
> friendship expense — **any** member may update or soft-delete it. An earlier draft of
> this document asserted a creator-only edit rule; the implemented rules do not enforce
> one.

### 5. User attempts to delete a friendship — DENIED

> **Setup:** Authenticated user who is a member of a friendship (with any balance,
> zero or non-zero).
> **Action:** Attempt to delete the friendship document.
> **Expected:** Delete is denied unconditionally (`allow delete: if false`).
> **Note (correction):** There is no balance-conditional delete; deletion is always
> denied regardless of `simplifiedBalances`.

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

### 11. Client attempts to read or write `_rateLimits` — DENIED

> **Setup:** Authenticated user.
> **Action:** Attempt to read or write any document under `_rateLimits/` (the rule
> uses the recursive wildcard `_rateLimits/{document=**}`).
> **Expected:** Read and write are both denied.
> **Rationale:** The `_rateLimits` collection is internal infrastructure managed
> exclusively by Cloud Functions via the Admin SDK.

### 12. Friendship created with `createdBy` not matching auth UID — DENIED

> **Setup:** Authenticated user creating a friendship document.
> **Action:** Create a friendship where `createdBy` is set to a different user's
> UID.
> **Expected:** Write is denied.

### 13. Friendship created with unsorted `memberIds` — DENIED

> **Setup:** Authenticated user creating a friendship document.
> **Action:** Create a friendship whose `memberIds` are not in ascending order
> (`memberIds[0] >= memberIds[1]`).
> **Expected:** Write is denied (`isValidFriendshipCreate` asserts
> `memberIds[0] < memberIds[1]`).
> **Note (correction):** The rules do **not** assert `request.resource.id ==
> memberIds[0] + '_' + memberIds[1]`. There is no document-ID equality check; the
> deterministic ID is a client convention, and ordering is enforced via `memberIds`.

---

## Implementation Notes

- **`simplifiedBalances` write-guard (Invariant 2).** Implemented with
  `request.resource.data.diff(resource.data).affectedKeys().hasAny(['simplifiedBalances'])`
  on update — the write is denied if the key is *touched at all*, which is stricter and
  cheaper than comparing values. The same `affectedKeys()` pattern enforces immutability
  of `memberIds`/`createdBy` (friendships), `createdAt`/`adminId` (groups), and the
  settlement soft-delete (`hasOnly(['deleted'])`). Cloud Functions bypass Security Rules
  via the Admin SDK, so no server-side allow rule is needed.
- **Split-sum validation is bounded enumeration, not a loop.** Firestore rules have no
  loops, so the friendship-expense rules enumerate a **fixed, small** set of indices.
  `shareAt(splits, i)` returns `splits.size() > i ? splits[i].sharePaise : 0`, and
  `sumOfSharesEquals(splits, amount)` checks `shareAt(splits,0) + shareAt(splits,1) == amount`
  — indices 0 and 1 only, matching the 1–2 split cap (`splits.size() <= 2`). Element
  validity (`areValidSplitElements`) and membership (`areSplitMembers`) are guarded the
  same way. There is **no** "enumerate up to 50 participants" and **no** `math.abs`
  computed field; a future group subcollection would extend the enumeration to the
  group-member cap.
- **Helper decomposition.** Each collection composes small named predicates
  (`hasOnlyKnownKeys`, `hasAllRequiredKeys`, `isValidShape`, `isValidExtensionPointLocks`,
  `isValid…Create` / `isValid…Update`) for readability and reuse.
- All rules should be tested using `@firebase/rules-unit-testing` against the
  Emulator Suite (SRS section 8.2; Invariant 4). The Cloud Functions Developer owns the
  rules-test implementation; the Architect owns the rule definitions.

---

## Storage Rules (`storage.rules`)

Cloud Storage uses a separate rules file with the same deny-by-default philosophy
(`match /{allPaths=**} { allow read, write: if false; }`).

- **`avatars/{userId}`** — read allowed to any authenticated user; write allowed only to
  the owner (`request.auth.uid == userId`), capped at 5 MB and `image/(jpeg|png)`.
- **`receipts/friendships/{friendshipId}/{expenseId}`** (FR-EX-05, shipped) — read and
  write require the caller to be in the parent friendship's `memberIds`, evaluated via a
  cross-service `firestore.get(...).data.memberIds` lookup; write additionally caps at
  10 MB and `image/(jpeg|png)`.
- **`receipts/groups/{groupId}/{expenseId}`** (defensive, no v1.0 UI) — same predicate
  shape against `groups/{groupId}.memberIds`; included now for forward-compatibility with
  the Sprint 3 groups epic.
