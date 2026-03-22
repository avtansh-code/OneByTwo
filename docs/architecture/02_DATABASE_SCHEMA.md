# One By Two — Database Schema Design

> **Version:** 2.0  
> **Last Updated:** 2026-02-14

---

## 1. Overview

One By Two uses **Cloud Firestore** as its sole database:

- **Cloud Firestore** — NoSQL document database for persistence, real-time sync, multi-device access, and offline-first operations

**Firestore is the source of truth** (with built-in offline persistence via the SDK cache). The Firestore SDK transparently caches data on-device, enabling offline reads and writes that automatically sync when connectivity is restored.

---

## 2. Cloud Firestore Schema

### 2.1 Collection Hierarchy

```
firestore-root/
│
├── users/{userId}                          ← User profile
│   ├── notifications/{notificationId}      ← User's notifications
│   └── drafts/{draftId}                    ← Unsaved expense drafts
│
├── groups/{groupId}                        ← Group metadata
│   ├── members/{userId}                    ← Group membership (subcollection)
│   ├── expenses/{expenseId}                ← Expenses in this group
│   │   ├── splits/{splitId}                ← Per-person split details
│   │   ├── payers/{payerId}                ← Payer breakdown
│   │   ├── items/{itemId}                  ← Itemized bill items
│   │   └── attachments/{attachmentId}      ← Receipt photos/files
│   ├── settlements/{settlementId}          ← Payment settlements
│   ├── balances/{balancePairId}            ← Pre-computed pairwise balances
│   └── activity/{activityId}              ← Group activity log
│
├── friends/{friendPairId}                  ← 1:1 friend relationship (ID = min(A,B)_max(A,B))
│   ├── expenses/{expenseId}                ← 1:1 expenses between two friends
│   │   ├── splits/{splitId}                ← Per-person split (always 2 entries)
│   │   ├── payers/{payerId}                ← Payer (usually 1 person)
│   │   ├── items/{itemId}                  ← Itemized bill items
│   │   └── attachments/{attachmentId}      ← Receipt photos/files
│   ├── settlements/{settlementId}          ← 1:1 payment settlements
│   ├── balance/{balanceDocId}              ← Single balance doc (net between the pair)
│   └── activity/{activityId}              ← 1:1 activity log
│
├── invites/{inviteCode}                    ← Group invite links
│
├── userGroups/{userId}                     ← Denormalized: user's group list
│   └── groups/{groupId}                    ← Lightweight group reference
│
└── userFriends/{userId}                    ← Denormalized: user's friend list
    └── friends/{friendUserId}              ← Lightweight friend reference with balance
```

### 2.2 Document Schemas

#### `users/{userId}`
```json
{
  "uid": "string (Firebase Auth UID)",
  "name": "string",
  "email": "string",
  "phone": "string (+91XXXXXXXXXX)",
  "avatarUrl": "string | null",
  "language": "string (en | hi)",
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "fcmTokens": ["string (device tokens)"],
  "notificationPrefs": {
    "expenses": true,
    "settlements": true,
    "reminders": true,
    "weeklyDigest": false
  },
  "isDeleted": false
}
```

#### `groups/{groupId}`
```json
{
  "id": "string",
  "name": "string",
  "category": "string (trip | home | couple | event | other)",
  "coverPhotoUrl": "string | null",
  "createdBy": "string (userId)",
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "isArchived": false,
  "defaultSplitType": "string (equal | exact | percentage | shares)",
  "memberCount": "number (denormalized)",
  "totalExpenseCount": "number (denormalized)",
  "simplifiedDebts": true
}
```

#### `groups/{groupId}/members/{userId}`
```json
{
  "userId": "string",
  "name": "string (denormalized for offline display)",
  "role": "string (owner | admin | member)",
  "joinedAt": "timestamp",
  "isGuest": false,
  "guestName": "string | null",
  "isActive": true,
  "invitedBy": "string (userId) | null"
}
```

#### `groups/{groupId}/expenses/{expenseId}`
```json
{
  "id": "string",
  "groupId": "string",
  "description": "string",
  "amount": "number (in paise — ₹1 = 100 paise, integer)",
  "date": "timestamp",
  "category": "string (food | transport | groceries | rent | entertainment | utilities | shopping | health | travel | other)",
  "splitType": "string (equal | exact | percentage | shares | itemized)",
  "notes": "string | null",
  "createdBy": "string (userId)",
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "updatedBy": "string (userId)",
  "isDeleted": false,
  "deletedAt": "timestamp | null",
  "deletedBy": "string (userId) | null",
  "version": "number (optimistic concurrency)",
  "isRecurring": false,
  "recurringRule": {
    "frequency": "string (daily | weekly | monthly | yearly)",
    "interval": "number",
    "nextDate": "timestamp",
    "endDate": "timestamp | null"
  }
}
```

#### `groups/{groupId}/expenses/{expenseId}/payers/{payerId}`
```json
{
  "userId": "string",
  "amountPaid": "number (paise)"
}
```

#### `groups/{groupId}/expenses/{expenseId}/splits/{splitId}`
```json
{
  "userId": "string",
  "amountOwed": "number (paise)",
  "percentage": "number | null",
  "shares": "number | null"
}
```

#### `groups/{groupId}/expenses/{expenseId}/items/{itemId}`
```json
{
  "name": "string",
  "amount": "number (paise)",
  "assignedTo": ["string (userId)"],
  "splitEqually": true
}
```

#### `groups/{groupId}/expenses/{expenseId}/attachments/{attachmentId}`
```json
{
  "url": "string",
  "fileName": "string",
  "mimeType": "string",
  "uploadedBy": "string (userId)",
  "uploadedAt": "timestamp"
}
```

#### `groups/{groupId}/settlements/{settlementId}`
```json
{
  "id": "string",
  "groupId": "string",
  "fromUserId": "string (who is paying)",
  "toUserId": "string (who is receiving)",
  "amount": "number (paise)",
  "date": "timestamp",
  "notes": "string | null",
  "createdBy": "string (userId)",
  "createdAt": "timestamp",
  "isDeleted": false,
  "version": "number"
}
```

#### `groups/{groupId}/balances/{balancePairId}`

Pre-computed pairwise balances for fast reads. The `balancePairId` is deterministic: `min(userA, userB)_max(userA, userB)`.

```json
{
  "userA": "string (userId — lexicographically smaller)",
  "userB": "string (userId — lexicographically larger)",
  "amount": "number (paise, positive means A owes B, negative means B owes A)",
  "lastUpdated": "timestamp"
}
```

#### `groups/{groupId}/activity/{activityId}`
```json
{
  "id": "string",
  "userId": "string",
  "action": "string (expense_added | expense_edited | expense_deleted | settlement_added | settlement_deleted | member_joined | member_left | group_edited | group_archived)",
  "entityType": "string (expense | settlement | group | member)",
  "entityId": "string",
  "details": {
    "description": "string",
    "amount": "number | null",
    "changes": {} 
  },
  "timestamp": "timestamp"
}
```

#### `invites/{inviteCode}`
```json
{
  "code": "string (6-8 char alphanumeric)",
  "groupId": "string",
  "groupName": "string (denormalized)",
  "createdBy": "string (userId)",
  "createdAt": "timestamp",
  "expiresAt": "timestamp | null",
  "maxUses": "number | null",
  "useCount": "number",
  "isActive": true
}
```

#### `userGroups/{userId}/groups/{groupId}`

Denormalized collection for fast "my groups" listing without querying all groups.

```json
{
  "groupId": "string",
  "groupName": "string",
  "category": "string",
  "coverPhotoUrl": "string | null",
  "role": "string",
  "isPinned": false,
  "lastActivityAt": "timestamp",
  "myBalance": "number (paise — net amount across all members in this group)",
  "memberCount": "number"
}
```

#### `users/{userId}/notifications/{notificationId}`
```json
{
  "id": "string",
  "type": "string (expense_added | expense_edited | settlement | reminder | nudge)",
  "title": "string",
  "body": "string",
  "groupId": "string | null",
  "friendPairId": "string | null",
  "entityId": "string | null",
  "isRead": false,
  "createdAt": "timestamp"
}
```

#### `friends/{friendPairId}`

Represents a 1:1 relationship between two users for tracking expenses outside of groups. The `friendPairId` uses canonical ordering: `min(userA, userB)_max(userA, userB)`.

```json
{
  "id": "string (canonical pair ID)",
  "userA": "string (userId — lexicographically smaller)",
  "userB": "string (userId — lexicographically larger)",
  "createdAt": "timestamp",
  "lastActivityAt": "timestamp"
}
```

#### `friends/{friendPairId}/expenses/{expenseId}`
```json
{
  "id": "string",
  "friendPairId": "string",
  "description": "string",
  "amount": "number (in paise)",
  "date": "timestamp",
  "category": "string",
  "splitType": "string (equal | exact | percentage)",
  "notes": "string | null",
  "createdBy": "string (userId)",
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "updatedBy": "string (userId)",
  "isDeleted": false,
  "deletedAt": "timestamp | null",
  "deletedBy": "string (userId) | null",
  "version": "number",
  "isRecurring": false,
  "recurringRule": {
    "frequency": "string (daily | weekly | monthly | yearly)",
    "interval": "number",
    "nextDate": "timestamp",
    "endDate": "timestamp | null"
  }
}
```

> **Note:** 1:1 expenses use the same splits/payers/attachments subcollection structure as group expenses, including itemized bill items (`items/` subcollection).

#### `friends/{friendPairId}/settlements/{settlementId}`
```json
{
  "id": "string",
  "friendPairId": "string",
  "fromUserId": "string",
  "toUserId": "string",
  "amount": "number (paise)",
  "date": "timestamp",
  "notes": "string | null",
  "createdBy": "string (userId)",
  "createdAt": "timestamp",
  "isDeleted": false,
  "version": "number"
}
```

#### `friends/{friendPairId}/balance/{balanceDocId}`

Single document storing the net balance between the pair. Simpler than group balances (only 1 pair).

```json
{
  "userA": "string (lexicographically smaller)",
  "userB": "string (lexicographically larger)",
  "amount": "number (paise, positive = A owes B, negative = B owes A)",
  "lastUpdated": "timestamp"
}
```

#### `userFriends/{userId}/friends/{friendUserId}`

Denormalized collection for fast "my friends" listing on the dashboard.

```json
{
  "friendUserId": "string",
  "friendName": "string (denormalized)",
  "friendAvatarUrl": "string | null",
  "friendPairId": "string (canonical pair ID for lookup)",
  "balance": "number (paise — positive = you owe them, negative = they owe you)",
  "lastActivityAt": "timestamp"
}
```

### 2.3 Firestore Indexes

| Collection | Fields | Query Purpose |
|-----------|--------|---------------|
| `groups/{gid}/expenses` | `isDeleted ASC, date DESC` | Active expenses sorted by date |
| `groups/{gid}/expenses` | `isDeleted ASC, category ASC, date DESC` | Expenses filtered by category |
| `groups/{gid}/expenses` | `isDeleted ASC, createdBy ASC, date DESC` | Expenses by payer |
| `groups/{gid}/activity` | `timestamp DESC` | Activity feed chronological |
| `friends/{fid}/expenses` | `isDeleted ASC, date DESC` | Active 1:1 expenses sorted by date |
| `friends/{fid}/expenses` | `isDeleted ASC, category ASC, date DESC` | 1:1 expenses filtered by category |
| `friends/{fid}/activity` | `timestamp DESC` | 1:1 activity feed |
| `userGroups/{uid}/groups` | `isPinned DESC, lastActivityAt DESC` | User's groups: pinned first, then recent |
| `userFriends/{uid}/friends` | `lastActivityAt DESC` | User's friends sorted by recent activity |
| `users/{uid}/notifications` | `isRead ASC, createdAt DESC` | Unread notifications first |
| `invites` | `code ASC, isActive ASC` | Invite code lookup |

---

## 3. Offline Persistence

The app relies on **Firestore's built-in offline persistence** rather than a separate local database. The Firestore SDK (via `cloud_firestore` for Flutter) provides:

- **Automatic local caching** — All read documents are cached on-device in a local cache managed by the Firestore SDK.
- **Offline writes** — Mutations are queued locally and automatically synced when the device regains connectivity.
- **Optimistic UI updates** — Listeners receive local changes immediately (with `hasPendingWrites` metadata), so the UI stays responsive without a custom sync layer.
- **Conflict resolution** — Last-write-wins by default; the `version` field on expenses and settlements supports application-level optimistic concurrency checks when needed.

No separate local schema, sync queue, or sync-status tracking is required.

---

## 4. Data Design Principles

### 4.1 Amount Storage

All monetary amounts are stored as **integers in paise** (1/100th of ₹) to avoid floating-point precision errors.

- `₹150.50` → stored as `15050`
- Display conversion: `amount / 100` with 2 decimal places
- All split calculations use integer arithmetic with remainder distribution

### 4.2 Offline Writes & Conflict Handling

Firestore's SDK handles offline writes automatically. Pending mutations are queued locally and flushed when connectivity is restored (last-write-wins). The `version` field on expenses and settlements supports application-level optimistic concurrency checks to detect conflicting edits.

### 4.3 Soft Deletes

Expenses and settlements use soft delete (`isDeleted: true`) to:
- Support 30-second undo
- Maintain audit trail
- Allow listeners to detect deletions via snapshot changes

### 4.4 Denormalization Strategy

| Denormalized Field | Location | Source | Purpose |
|---|---|---|---|
| `memberCount` | `groups/{groupId}` | Count of members subcollection | Avoid subcollection query for group cards |
| `myBalance` | `userGroups/{uid}/groups/{gid}` | Computed from balances subcollection | Dashboard balance display |
| `name` | `groups/{gid}/members/{uid}` | `users/{uid}.name` | Display without extra document read |
| `groupName` | `userGroups/{uid}/groups/{gid}` | `groups/{gid}.name` | Fast group listing |
| `lastActivityAt` | `groups`, `userGroups` | Latest activity timestamp | Sort groups by recency |

### 4.5 ID Generation

- Firestore documents: Firestore auto-generated IDs (20 chars, URL-safe)
- Client-created entities: UUID v4 (generated on device, used as Firestore document ID so offline writes get a stable ID)
- Invite codes: 8-character alphanumeric (base36, uppercase)
- Balance pair IDs: Deterministic `${min(a,b)}_${max(a,b)}` for idempotent upserts
