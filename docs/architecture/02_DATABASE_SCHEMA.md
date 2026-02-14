# One By Two — Database Schema Design

> **Version:** 1.1  
> **Last Updated:** 2026-02-14

---

## 1. Overview

One By Two uses a **dual-database architecture**:

1. **Cloud Firestore** (remote) — NoSQL document database for cloud persistence, real-time sync, and multi-device access
2. **sqflite** (local) — Relational SQL database on-device for offline-first operations, complex queries, and fast reads

The **local sqflite database is the source of truth for the UI**. Firestore handles cloud sync and multi-device consistency.

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

## 3. Local sqflite Schema

### 3.1 Entity-Relationship Diagram

```
┌──────────────┐       ┌──────────────────┐       ┌──────────────────┐
│    users     │       │   group_members  │       │     groups       │
│──────────────│       │──────────────────│       │──────────────────│
│ id (PK)      │──┐    │ id (PK)          │    ┌──│ id (PK)          │
│ name         │  └───<│ user_id (FK)     │    │  │ name             │
│ email        │       │ group_id (FK)    │>───┘  │ category         │
│ phone        │       │ role             │       │ cover_photo_url  │
│ avatar_url   │       │ is_guest         │       │ created_by (FK)  │
│ language     │       │ guest_name       │       │ is_archived      │
│ is_current   │       │ is_active        │       │ default_split    │
│ created_at   │       │ joined_at        │       │ member_count     │
│ updated_at   │       │ sync_status      │       │ is_pinned        │
│ sync_status  │       └──────────────────┘       │ my_balance       │
└──────┬───────┘                                  │ last_activity_at │
       │                                          │ created_at       │
       │                                          │ updated_at       │
       │         ┌──────────────────┐             │ sync_status      │
       │         │    expenses      │             └──────────────────┘
       │         │──────────────────│                      │
       │         │ id (PK)          │                      │
       ├────────<│ created_by (FK)  │                      │
       │         │ group_id (FK)?   │>─────────────────────┘
       │         │ friend_pair_id?  │>───────────────────────────────┐
       │         │ context_type     │  ('group' | 'friend')         │
       │         │ description      │                                │
       │         │ amount           │  (stored in paise)             │
       │         │ date             │                                │
       │         │ category         │                                │
       │         │ split_type       │                                │
       │         │ notes            │                                │
       │         │ is_deleted       │                                │
       │         │ is_recurring     │                                │
       │         │ recurring_freq   │                                │
       │         │ recurring_intrvl │                                │
       │         │ recurring_next   │                                │
       │         │ recurring_end    │                                │
       │         │ version          │                                │
       │         │ created_at       │                                │
       │         │ updated_at       │                                │
       │         │ updated_by       │                                │
       │         │ sync_status      │                                │
       │         └────────┬─────────┘                                │
       │                  │                                          │
       │   ┌──────────────┼──────────────┬───────────────┐           │
       │   │              │              │               │           │
       │   ▼              ▼              ▼               ▼           │
  ┌────────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────────┐
  │ expense_payers │ │expense_splits│ │expense_items │ │expense_attachmts │
  │────────────────│ │──────────────│ │──────────────│ │──────────────────│
  │ id (PK)        │ │ id (PK)      │ │ id (PK)      │ │ id (PK)          │
  │ expense_id(FK) │ │ expense_id   │ │ expense_id   │ │ expense_id (FK)  │
  │ user_id (FK)   │ │ user_id (FK) │ │ name         │ │ url              │
  │ amount_paid    │ │ amount_owed  │ │ amount       │ │ local_path       │
  │ sync_status    │ │ percentage   │ │ assigned_to  │ │ file_name        │
  └────────────────┘ │ shares       │ │ sync_status  │ │ mime_type        │
                     │ sync_status  │ └──────────────┘ │ sync_status      │
                     └──────────────┘                  └──────────────────┘
       │
       │  ┌──────────────────┐
       │  │     friends      │
       │  │──────────────────│
       ├─<│ user_a_id (FK)   │
       └─<│ user_b_id (FK)   │
          │ id (PK)          │──────────────────────────────────────┐
          │ created_at       │                                     │
          │ last_activity_at │                                     │
          │ balance          │  (paise, +ve = A owes B)            │
          │ sync_status      │                                     │
          └──────────────────┘                                     │
                                                                   │
  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐ │
  │   settlements    │  │  activity_log    │  │  notifications   │ │
  │──────────────────│  │──────────────────│  │──────────────────│ │
  │ id (PK)          │  │ id (PK)          │  │ id (PK)          │ │
  │ group_id (FK)?   │  │ group_id (FK)?   │  │ type             │ │
  │ friend_pair_id?  │>─│ friend_pair_id?  │>─│ title            │ │
  │ context_type     │  │ context_type     │  │ body             │ │
  │ from_user_id(FK) │  │ user_id (FK)     │  │ group_id         │ │
  │ to_user_id (FK)  │  │ action           │  │ friend_pair_id   │ │
  │ amount           │  │ entity_type      │  │ entity_id        │ │
  │ date             │  │ entity_id        │  │ is_read          │ │
  │ notes            │  │ details_json     │  │ created_at       │ │
  │ is_deleted       │  │ timestamp        │  │ sync_status      │ │
  │ version          │  │ sync_status      │  └──────────────────┘ │
  │ created_by       │  └──────────────────┘                       │
  │ created_at       │                                             │
  │ sync_status      │  ┌──────────────────┐  ┌──────────────────┐ │
  └──────────────────┘  │ group_balances   │  │   sync_queue     │ │
                        │──────────────────│  │──────────────────│ │
                        │ id (PK)          │  │ id (PK)          │ │
                        │ group_id (FK)    │  │ entity_type      │ │
                        │ user_a_id (FK)   │  │ entity_id        │ │
                        │ user_b_id (FK)   │  │ operation        │ │
                        │ amount           │  │ payload_json     │ │
                        │ last_updated     │  │ context_type     │ │
                        └──────────────────┘  │ context_id       │ │
                                              │ retry_count      │ │
                                              │ created_at       │ │
                                              │ status           │ │
                                              └──────────────────┘ │
```

### 3.2 SQL DDL

```sql
-- Users table
CREATE TABLE users (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  avatar_url TEXT,
  language TEXT NOT NULL DEFAULT 'en',
  is_current_user INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,  -- epoch ms
  updated_at INTEGER NOT NULL,
  sync_status TEXT NOT NULL DEFAULT 'synced'  -- synced | pending | conflict
);

-- Groups table
CREATE TABLE groups (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'other',
  cover_photo_url TEXT,
  created_by TEXT NOT NULL,
  is_archived INTEGER NOT NULL DEFAULT 0,
  default_split_type TEXT NOT NULL DEFAULT 'equal',
  member_count INTEGER NOT NULL DEFAULT 0,
  is_pinned INTEGER NOT NULL DEFAULT 0,
  my_balance INTEGER NOT NULL DEFAULT 0,  -- paise
  last_activity_at INTEGER,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  sync_status TEXT NOT NULL DEFAULT 'synced',
  FOREIGN KEY (created_by) REFERENCES users(id)
);

-- Group members
CREATE TABLE group_members (
  id TEXT PRIMARY KEY,
  group_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  name TEXT NOT NULL,  -- denormalized
  role TEXT NOT NULL DEFAULT 'member',  -- owner | admin | member
  is_guest INTEGER NOT NULL DEFAULT 0,
  guest_name TEXT,
  is_active INTEGER NOT NULL DEFAULT 1,
  joined_at INTEGER NOT NULL,
  sync_status TEXT NOT NULL DEFAULT 'synced',
  FOREIGN KEY (group_id) REFERENCES groups(id),
  FOREIGN KEY (user_id) REFERENCES users(id),
  UNIQUE (group_id, user_id)
);

-- Expenses (group or 1:1 friend context)
CREATE TABLE expenses (
  id TEXT PRIMARY KEY,
  group_id TEXT,                            -- NULL for friend expenses
  friend_pair_id TEXT,                      -- NULL for group expenses
  context_type TEXT NOT NULL DEFAULT 'group', -- 'group' | 'friend'
  description TEXT NOT NULL,
  amount INTEGER NOT NULL,  -- paise
  date INTEGER NOT NULL,    -- epoch ms
  category TEXT NOT NULL DEFAULT 'other',
  split_type TEXT NOT NULL DEFAULT 'equal',
  notes TEXT,
  created_by TEXT NOT NULL,
  updated_by TEXT,
  is_deleted INTEGER NOT NULL DEFAULT 0,
  deleted_at INTEGER,
  deleted_by TEXT,
  is_recurring INTEGER NOT NULL DEFAULT 0,
  recurring_frequency TEXT,
  recurring_interval INTEGER,
  recurring_next_date INTEGER,
  recurring_end_date INTEGER,
  version INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  sync_status TEXT NOT NULL DEFAULT 'synced',
  FOREIGN KEY (group_id) REFERENCES groups(id),
  FOREIGN KEY (friend_pair_id) REFERENCES friends(id),
  FOREIGN KEY (created_by) REFERENCES users(id),
  CHECK (
    (context_type = 'group' AND group_id IS NOT NULL AND friend_pair_id IS NULL) OR
    (context_type = 'friend' AND friend_pair_id IS NOT NULL AND group_id IS NULL)
  )
);

-- Expense payers (who paid)
CREATE TABLE expense_payers (
  id TEXT PRIMARY KEY,
  expense_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  amount_paid INTEGER NOT NULL,  -- paise
  sync_status TEXT NOT NULL DEFAULT 'synced',
  FOREIGN KEY (expense_id) REFERENCES expenses(id),
  FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Expense splits (who owes)
CREATE TABLE expense_splits (
  id TEXT PRIMARY KEY,
  expense_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  amount_owed INTEGER NOT NULL,  -- paise
  percentage REAL,
  shares REAL,
  sync_status TEXT NOT NULL DEFAULT 'synced',
  FOREIGN KEY (expense_id) REFERENCES expenses(id),
  FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Itemized bill items
CREATE TABLE expense_items (
  id TEXT PRIMARY KEY,
  expense_id TEXT NOT NULL,
  name TEXT NOT NULL,
  amount INTEGER NOT NULL,  -- paise
  assigned_to TEXT NOT NULL,  -- JSON array of userIds
  split_equally INTEGER NOT NULL DEFAULT 1,
  sync_status TEXT NOT NULL DEFAULT 'synced',
  FOREIGN KEY (expense_id) REFERENCES expenses(id)
);

-- Receipt attachments
CREATE TABLE expense_attachments (
  id TEXT PRIMARY KEY,
  expense_id TEXT NOT NULL,
  url TEXT,           -- remote URL (null if not yet uploaded)
  local_path TEXT,    -- local file path
  file_name TEXT NOT NULL,
  mime_type TEXT NOT NULL,
  uploaded_by TEXT NOT NULL,
  uploaded_at INTEGER NOT NULL,
  sync_status TEXT NOT NULL DEFAULT 'synced',
  FOREIGN KEY (expense_id) REFERENCES expenses(id)
);

-- Settlements (group or 1:1 friend context)
CREATE TABLE settlements (
  id TEXT PRIMARY KEY,
  group_id TEXT,                            -- NULL for friend settlements
  friend_pair_id TEXT,                      -- NULL for group settlements
  context_type TEXT NOT NULL DEFAULT 'group', -- 'group' | 'friend'
  from_user_id TEXT NOT NULL,
  to_user_id TEXT NOT NULL,
  amount INTEGER NOT NULL,  -- paise
  date INTEGER NOT NULL,
  notes TEXT,
  created_by TEXT NOT NULL,
  is_deleted INTEGER NOT NULL DEFAULT 0,
  version INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER NOT NULL,
  sync_status TEXT NOT NULL DEFAULT 'synced',
  FOREIGN KEY (group_id) REFERENCES groups(id),
  FOREIGN KEY (friend_pair_id) REFERENCES friends(id),
  FOREIGN KEY (from_user_id) REFERENCES users(id),
  FOREIGN KEY (to_user_id) REFERENCES users(id),
  CHECK (
    (context_type = 'group' AND group_id IS NOT NULL AND friend_pair_id IS NULL) OR
    (context_type = 'friend' AND friend_pair_id IS NOT NULL AND group_id IS NULL)
  )
);

-- Pre-computed pairwise balances per group
CREATE TABLE group_balances (
  id TEXT PRIMARY KEY,
  group_id TEXT NOT NULL,
  user_a_id TEXT NOT NULL,   -- lexicographically smaller
  user_b_id TEXT NOT NULL,   -- lexicographically larger
  amount INTEGER NOT NULL DEFAULT 0,  -- positive = A owes B
  last_updated INTEGER NOT NULL,
  FOREIGN KEY (group_id) REFERENCES groups(id),
  UNIQUE (group_id, user_a_id, user_b_id)
);

-- Activity log (group or 1:1 friend context)
CREATE TABLE activity_log (
  id TEXT PRIMARY KEY,
  group_id TEXT,                            -- NULL for friend activity
  friend_pair_id TEXT,                      -- NULL for group activity
  context_type TEXT NOT NULL DEFAULT 'group', -- 'group' | 'friend'
  user_id TEXT NOT NULL,
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  details_json TEXT,  -- JSON blob
  timestamp INTEGER NOT NULL,
  sync_status TEXT NOT NULL DEFAULT 'synced',
  FOREIGN KEY (group_id) REFERENCES groups(id),
  FOREIGN KEY (friend_pair_id) REFERENCES friends(id)
);

-- Notifications
CREATE TABLE notifications (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  group_id TEXT,
  friend_pair_id TEXT,
  entity_id TEXT,
  is_read INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  sync_status TEXT NOT NULL DEFAULT 'synced'
);

-- Sync queue (pending operations to push to Firestore)
CREATE TABLE sync_queue (
  id TEXT PRIMARY KEY,
  entity_type TEXT NOT NULL,  -- expense | settlement | group | member | friend | friend_expense | friend_settlement
  entity_id TEXT NOT NULL,
  operation TEXT NOT NULL,    -- create | update | delete
  payload_json TEXT NOT NULL,
  context_type TEXT NOT NULL DEFAULT 'group', -- 'group' | 'friend'
  context_id TEXT,            -- group_id or friend_pair_id
  retry_count INTEGER NOT NULL DEFAULT 0,
  max_retries INTEGER NOT NULL DEFAULT 5,
  status TEXT NOT NULL DEFAULT 'pending',  -- pending | in_progress | failed | completed
  error_message TEXT,
  created_at INTEGER NOT NULL,
  last_attempted_at INTEGER
);

-- Expense drafts (auto-save)
CREATE TABLE expense_drafts (
  id TEXT PRIMARY KEY,
  group_id TEXT,
  friend_pair_id TEXT,
  context_type TEXT NOT NULL DEFAULT 'group', -- 'group' | 'friend'
  data_json TEXT NOT NULL,  -- serialized partial expense
  updated_at INTEGER NOT NULL
);

-- Friends (1:1 expense pairs)
CREATE TABLE friends (
  id TEXT PRIMARY KEY,           -- canonical pair ID: min(A,B)_max(A,B)
  user_a_id TEXT NOT NULL,       -- lexicographically smaller userId
  user_b_id TEXT NOT NULL,       -- lexicographically larger userId
  balance INTEGER NOT NULL DEFAULT 0,  -- paise, positive = A owes B
  last_activity_at INTEGER,
  created_at INTEGER NOT NULL,
  sync_status TEXT NOT NULL DEFAULT 'synced',
  FOREIGN KEY (user_a_id) REFERENCES users(id),
  FOREIGN KEY (user_b_id) REFERENCES users(id),
  UNIQUE (user_a_id, user_b_id)
);

-- Indexes
CREATE INDEX idx_expenses_group ON expenses(group_id, is_deleted, date);
CREATE INDEX idx_expenses_friend ON expenses(friend_pair_id, is_deleted, date);
CREATE INDEX idx_expenses_context ON expenses(context_type, is_deleted, date);
CREATE INDEX idx_expenses_category ON expenses(group_id, category, date);
CREATE INDEX idx_expenses_friend_category ON expenses(friend_pair_id, category, date);
CREATE INDEX idx_expenses_created_by ON expenses(created_by, date);
CREATE INDEX idx_expense_payers_expense ON expense_payers(expense_id);
CREATE INDEX idx_expense_splits_expense ON expense_splits(expense_id);
CREATE INDEX idx_expense_splits_user ON expense_splits(user_id);
CREATE INDEX idx_expense_items_expense ON expense_items(expense_id);
CREATE INDEX idx_settlements_group ON settlements(group_id, is_deleted);
CREATE INDEX idx_settlements_friend ON settlements(friend_pair_id, is_deleted);
CREATE INDEX idx_group_members_group ON group_members(group_id, is_active);
CREATE INDEX idx_group_members_user ON group_members(user_id, is_active);
CREATE INDEX idx_activity_group ON activity_log(group_id, timestamp);
CREATE INDEX idx_activity_friend ON activity_log(friend_pair_id, timestamp);
CREATE INDEX idx_notifications_read ON notifications(is_read, created_at);
CREATE INDEX idx_sync_queue_status ON sync_queue(status, created_at);
CREATE INDEX idx_group_balances_group ON group_balances(group_id);
CREATE INDEX idx_friends_user_a ON friends(user_a_id);
CREATE INDEX idx_friends_user_b ON friends(user_b_id);
```

---

## 4. Data Design Principles

### 4.1 Amount Storage

All monetary amounts are stored as **integers in paise** (1/100th of ₹) to avoid floating-point precision errors.

- `₹150.50` → stored as `15050`
- Display conversion: `amount / 100` with 2 decimal places
- All split calculations use integer arithmetic with remainder distribution

### 4.2 Sync Status Field

Every syncable table has a `sync_status` column:

| Value | Meaning |
|-------|---------|
| `synced` | Data matches Firestore |
| `pending` | Local change not yet pushed |
| `conflict` | Server version differs; needs resolution |

### 4.3 Soft Deletes

Expenses and settlements use soft delete (`is_deleted = 1`) to:
- Support 30-second undo
- Maintain audit trail
- Enable proper sync (hard-delete doesn't propagate well offline)

### 4.4 Denormalization Strategy

| Denormalized Field | Location | Source | Purpose |
|---|---|---|---|
| `member_count` | groups | Count of group_members | Avoid join for group cards |
| `my_balance` | groups | Sum of group_balances | Dashboard balance display |
| `name` | group_members | users.name | Offline display without user lookup |
| `groupName` | userGroups | groups.name | Fast group listing |
| `lastActivityAt` | groups, userGroups | Max activity timestamp | Sort groups by recency |

### 4.5 ID Generation

- Firestore documents: Firestore auto-generated IDs (20 chars, URL-safe)
- Local-first entities: UUID v4 (generated on device, used as Firestore document ID)
- Invite codes: 8-character alphanumeric (base36, uppercase)
- Balance pair IDs: Deterministic `${min(a,b)}_${max(a,b)}` for idempotent upserts
