# One By Two — API & Cloud Functions Design

> **Version:** 1.1  
> **Last Updated:** 2026-02-14

---

## 1. Overview

The backend logic runs entirely on **Firebase Cloud Functions (2nd gen, TypeScript/Node.js)**. There is no custom server. The app communicates with the backend via:

1. **Firestore SDK** — Direct reads/writes with security rules (primary)
2. **Cloud Functions (HTTPS Callable)** — Complex operations that require server-side logic
3. **Cloud Functions (Firestore Triggers)** — Reactive logic on data changes
4. **Cloud Functions (Scheduled)** — Periodic tasks

---

## 2. Firebase Cloud Functions

### 2.1 HTTPS Callable Functions

These are called explicitly by the client via `FirebaseFunctions.httpsCallable()`.

```
┌────────────────────────────────────────────────────────────────────┐
│                   CALLABLE FUNCTIONS                               │
│                                                                    │
│  Function                    │ Input                  │ Output     │
│  ────────────────────────────┼────────────────────────┼─────────── │
│                                                                    │
│  simplifyDebts               │ { groupId }            │ List of    │
│  Calculates optimized        │                        │ simplified │
│  settlement plan             │                        │ Settlement │
│                                                                    │
│  generateInviteLink          │ { groupId,             │ { code,    │
│  Creates group invite        │   expiresIn?,          │   link }   │
│                              │   maxUses? }           │            │
│                                                                    │
│  joinGroupViaInvite          │ { inviteCode,          │ { groupId, │
│  Validates invite, adds      │   guestName? }         │   success }│
│  user/guest to group         │                        │            │
│                                                                    │
│  migrateGuestToUser          │ { guestId,             │ { success }│
│  Links guest data to         │   userId }             │            │
│  newly registered user       │                        │            │
│                                                                    │
│  deleteAccount               │ { }                    │ { success }│
│  GDPR: Removes all user      │ (uses auth context)    │            │
│  data across all groups       │                        │            │
│                                                                    │
│  exportData                  │ { format,              │ { fileUrl }│
│  Generates CSV/PDF export    │   groupId?,            │            │
│  of expenses                 │   dateRange? }         │            │
│                                                                    │
│  nudgeUser                   │ { groupId,             │ { success }│
│  Sends reminder notification │   targetUserId }       │            │
│  to a user who owes money    │                        │            │
│                                                                    │
│  settleAll                   │ { groupId,             │ { count }  │
│  Records all suggested       │   settlements: [] }    │            │
│  settlements in batch        │                        │            │
│                                                                    │
│  addFriend                   │ { friendUserId }       │ { pairId } │
│  Creates a friend pair and   │                        │            │
│  userFriends entries for     │                        │            │
│  both users                  │                        │            │
│                                                                    │
│  nudgeFriend                 │ { friendPairId,        │ { success }│
│  Sends reminder notification │   targetUserId }       │            │
│  to a friend who owes money  │                        │            │
│                                                                    │
│  settleFriend                │ { friendPairId,        │ { id }     │
│  Records a settlement        │   amount,              │            │
│  between two friends         │   date? }              │            │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

### 2.2 Firestore Trigger Functions

These run automatically when Firestore documents change.

```
┌────────────────────────────────────────────────────────────────────┐
│                   TRIGGER FUNCTIONS                                │
│                                                                    │
│  Trigger                     │ Event               │ Action        │
│  ────────────────────────────┼─────────────────────┼────────────── │
│                                                                    │
│  onExpenseCreated            │ groups/{gid}/        │ • Recalculate │
│                              │ expenses/{eid}       │   pairwise    │
│                              │ onCreate             │   balances    │
│                              │                      │ • Update group│
│                              │                      │   summary     │
│                              │                      │ • Log activity│
│                              │                      │ • Send push   │
│                              │                      │   notifications│
│                              │                      │ • Update      │
│                              │                      │   userGroups  │
│                                                                    │
│  onExpenseUpdated            │ groups/{gid}/        │ • Recalculate │
│                              │ expenses/{eid}       │   balances    │
│                              │ onUpdate             │ • Log changes │
│                              │                      │ • Send push   │
│                              │                      │   to affected │
│                                                                    │
│  onExpenseDeleted            │ groups/{gid}/        │ • Recalculate │
│                              │ expenses/{eid}       │   balances    │
│                              │ onUpdate             │ • Log deletion│
│                              │ (soft delete)        │ • Send push   │
│                                                                    │
│  onSettlementCreated         │ groups/{gid}/        │ • Update      │
│                              │ settlements/{sid}    │   balances    │
│                              │ onCreate             │ • Log activity│
│                              │                      │ • Send push   │
│                                                                    │
│  onMemberJoined              │ groups/{gid}/        │ • Update      │
│                              │ members/{uid}        │   memberCount │
│                              │ onCreate             │ • Log activity│
│                              │                      │ • Update      │
│                              │                      │   userGroups  │
│                                                                    │
│  onMemberLeft                │ groups/{gid}/        │ • Update      │
│                              │ members/{uid}        │   memberCount │
│                              │ onUpdate             │ • Log activity│
│                              │ (isActive=false)     │ • Update      │
│                              │                      │   userGroups  │
│                                                                    │
│  onUserCreated               │ users/{uid}          │ • Initialize  │
│                              │ onCreate             │   userGroups  │
│                              │                      │ • Welcome     │
│                              │                      │   notification│
│                                                                    │
│  onUserDeleted               │ users/{uid}          │ • Cleanup     │
│                              │ onDelete             │   orphaned    │
│                              │                      │   references  │
│                                                                    │
│  ─── FRIEND-SCOPED TRIGGERS ────────────────────────────────────── │
│                                                                    │
│  onFriendExpenseCreated      │ friends/{fid}/       │ • Recalculate │
│                              │ expenses/{eid}       │   1:1 balance │
│                              │ onCreate             │ • Log activity│
│                              │                      │ • Send push   │
│                              │                      │ • Update      │
│                              │                      │   userFriends │
│                                                                    │
│  onFriendExpenseUpdated      │ friends/{fid}/       │ • Recalculate │
│                              │ expenses/{eid}       │   1:1 balance │
│                              │ onUpdate             │ • Log changes │
│                              │                      │ • Send push   │
│                                                                    │
│  onFriendExpenseDeleted      │ friends/{fid}/       │ • Recalculate │
│                              │ expenses/{eid}       │   1:1 balance │
│                              │ onUpdate             │ • Log deletion│
│                              │ (soft delete)        │ • Send push   │
│                                                                    │
│  onFriendSettlementCreated   │ friends/{fid}/       │ • Update      │
│                              │ settlements/{sid}    │   1:1 balance │
│                              │ onCreate             │ • Log activity│
│                              │                      │ • Send push   │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

### 2.3 Scheduled Functions

```
┌────────────────────────────────────────────────────────────────────┐
│                   SCHEDULED FUNCTIONS                              │
│                                                                    │
│  Function                    │ Schedule       │ Action              │
│  ────────────────────────────┼────────────────┼──────────────────── │
│                                                                    │
│  processRecurringExpenses    │ Daily 00:00    │ Check recurring     │
│                              │ IST            │ expenses due today, │
│                              │                │ create new entries  │
│                                                                    │
│  sendWeeklyDigest            │ Monday 09:00   │ Compile spending    │
│                              │ IST            │ summary, send push  │
│                              │                │ to opted-in users   │
│                                                                    │
│  cleanupExpiredInvites       │ Daily 02:00    │ Deactivate expired  │
│                              │ IST            │ invite links        │
│                                                                    │
│  cleanupSoftDeletes          │ Weekly Sun     │ Hard-delete expenses│
│                              │ 03:00 IST      │ soft-deleted > 30   │
│                              │                │ days ago            │
│                                                                    │
│  sendSettlementReminders     │ Daily 10:00    │ Send nudge to users │
│                              │ IST            │ with pending debts  │
│                              │                │ > 7 days old        │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

---

## 3. Balance Recalculation Logic

### 3.1 Group Balance Recalculation

Triggered by `onExpenseCreated`, `onExpenseUpdated`, `onExpenseDeleted`, and `onSettlementCreated`.

```
┌────────────────────────────────────────────────────────────────────┐
│              BALANCE RECALCULATION (Cloud Function)                │
│                                                                    │
│  Input: groupId (triggered by expense/settlement change)          │
│                                                                    │
│  Algorithm:                                                        │
│  1. Fetch ALL active expenses in group                            │
│  2. Fetch ALL active settlements in group                         │
│  3. Initialize balance matrix: Map<(userA, userB), int>           │
│                                                                    │
│  For each expense:                                                 │
│    For each payer P who paid amount X:                             │
│      For each participant S who owes amount Y:                    │
│        if P != S:                                                  │
│          balance[canonicalPair(P, S)] += or -= Y                  │
│                                                                    │
│  For each settlement:                                              │
│    balance[canonicalPair(from, to)] -= settlement.amount          │
│                                                                    │
│  4. Write updated balances to groups/{gid}/balances/              │
│  5. Calculate myBalance for each member → update userGroups       │
│                                                                    │
│  canonicalPair(a, b):                                              │
│    if a < b: return (a, b, +amount means a owes b)                │
│    else: return (b, a, -amount means b owes a)                    │
│                                                                    │
│  Performance:                                                      │
│  • Full recalc for groups ≤ 50 members and ≤ 10,000 expenses     │
│  • Uses Firestore batch writes (max 500 ops per batch)            │
│  • Idempotent: safe to re-run on conflicts                       │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

### 3.2 Friend (1:1) Balance Recalculation

Triggered by `onFriendExpenseCreated/Updated/Deleted` and `onFriendSettlementCreated`.

```
┌────────────────────────────────────────────────────────────────────┐
│           1:1 FRIEND BALANCE RECALCULATION (Cloud Function)       │
│                                                                    │
│  Input: friendPairId (triggered by expense/settlement change)     │
│                                                                    │
│  Algorithm:                                                        │
│  1. Fetch ALL active expenses in friends/{fid}/expenses/          │
│  2. Fetch ALL active settlements in friends/{fid}/settlements/    │
│  3. Initialize netBalance = 0  (single scalar, not a matrix)     │
│                                                                    │
│  For each expense:                                                 │
│    For each payer P:                                               │
│      For each split S:                                             │
│        if P == userA && S == userB: netBalance -= S.amount        │
│        if P == userB && S == userA: netBalance += S.amount        │
│                                                                    │
│  For each settlement:                                              │
│    if from == userA: netBalance -= settlement.amount              │
│    if from == userB: netBalance += settlement.amount              │
│                                                                    │
│  4. Write to friends/{fid}/balance/ (single doc)                  │
│  5. Update userFriends/{userA}/friends/{userB}.balance            │
│  6. Update userFriends/{userB}/friends/{userA}.balance (negated)  │
│                                                                    │
│  Convention: positive netBalance = userA owes userB               │
│  Simpler than group: no debt simplification needed (only 2 users) │
│  Idempotent: safe to re-run on conflicts                          │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

---

## 4. Firebase Security Rules

### 4.1 Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helper functions
    function isSignedIn() {
      return request.auth != null;
    }

    function isOwner(userId) {
      return request.auth.uid == userId;
    }

    function isGroupMember(groupId) {
      return exists(/databases/$(database)/documents/groups/$(groupId)/members/$(request.auth.uid));
    }

    function isGroupAdmin(groupId) {
      let member = get(/databases/$(database)/documents/groups/$(groupId)/members/$(request.auth.uid));
      return member.data.role in ['owner', 'admin'];
    }

    function isGroupOwner(groupId) {
      let member = get(/databases/$(database)/documents/groups/$(groupId)/members/$(request.auth.uid));
      return member.data.role == 'owner';
    }

    // Users
    match /users/{userId} {
      allow read: if isSignedIn();
      allow create: if isOwner(userId);
      allow update: if isOwner(userId);
      allow delete: if isOwner(userId);

      match /notifications/{notificationId} {
        allow read, write: if isOwner(userId);
      }

      match /drafts/{draftId} {
        allow read, write: if isOwner(userId);
      }
    }

    // User Groups (denormalized)
    match /userGroups/{userId}/groups/{groupId} {
      allow read: if isOwner(userId);
      allow write: if false; // only written by Cloud Functions
    }

    // Groups
    match /groups/{groupId} {
      allow read: if isSignedIn() && isGroupMember(groupId);
      allow create: if isSignedIn();
      allow update: if isSignedIn() && isGroupAdmin(groupId);
      allow delete: if false; // archive only, no hard delete

      // Members
      match /members/{memberId} {
        allow read: if isSignedIn() && isGroupMember(groupId);
        allow create: if isSignedIn() && isGroupAdmin(groupId);
        allow update: if isSignedIn() && (isGroupAdmin(groupId) || isOwner(memberId));
        allow delete: if isSignedIn() && isGroupAdmin(groupId);
      }

      // Expenses
      match /expenses/{expenseId} {
        allow read: if isSignedIn() && isGroupMember(groupId);
        allow create: if isSignedIn() && isGroupMember(groupId);
        allow update: if isSignedIn() && isGroupMember(groupId);
        allow delete: if false; // soft delete only

        match /splits/{splitId} {
          allow read: if isSignedIn() && isGroupMember(groupId);
          allow write: if isSignedIn() && isGroupMember(groupId);
        }

        match /payers/{payerId} {
          allow read: if isSignedIn() && isGroupMember(groupId);
          allow write: if isSignedIn() && isGroupMember(groupId);
        }

        match /items/{itemId} {
          allow read: if isSignedIn() && isGroupMember(groupId);
          allow write: if isSignedIn() && isGroupMember(groupId);
        }

        match /attachments/{attachmentId} {
          allow read: if isSignedIn() && isGroupMember(groupId);
          allow write: if isSignedIn() && isGroupMember(groupId);
        }
      }

      // Settlements
      match /settlements/{settlementId} {
        allow read: if isSignedIn() && isGroupMember(groupId);
        allow create: if isSignedIn() && isGroupMember(groupId);
        allow update: if isSignedIn() && isGroupMember(groupId);
        allow delete: if false;
      }

      // Balances (read-only for clients, written by Cloud Functions)
      match /balances/{balanceId} {
        allow read: if isSignedIn() && isGroupMember(groupId);
        allow write: if false; // only Cloud Functions
      }

      // Activity log (read-only for clients)
      match /activity/{activityId} {
        allow read: if isSignedIn() && isGroupMember(groupId);
        allow write: if false; // only Cloud Functions
      }
    }

    // Invites (public read for join flow)
    match /invites/{inviteCode} {
      allow read: if isSignedIn();
      allow write: if false; // only Cloud Functions
    }

    // ── FRIEND (1:1) RULES ──────────────────────────────────────

    function isFriendPairMember(friendPairId) {
      let pair = get(/databases/$(database)/documents/friends/$(friendPairId));
      return request.auth.uid == pair.data.userA || request.auth.uid == pair.data.userB;
    }

    // Friend pairs
    match /friends/{friendPairId} {
      allow read: if isSignedIn() && isFriendPairMember(friendPairId);
      allow create: if false; // only Cloud Functions (addFriend callable)
      allow update: if false; // only Cloud Functions
      allow delete: if false;

      // 1:1 Expenses
      match /expenses/{expenseId} {
        allow read: if isSignedIn() && isFriendPairMember(friendPairId);
        allow create: if isSignedIn() && isFriendPairMember(friendPairId);
        allow update: if isSignedIn() && isFriendPairMember(friendPairId);
        allow delete: if false; // soft delete only

        match /splits/{splitId} {
          allow read: if isSignedIn() && isFriendPairMember(friendPairId);
          allow write: if isSignedIn() && isFriendPairMember(friendPairId);
        }

        match /payers/{payerId} {
          allow read: if isSignedIn() && isFriendPairMember(friendPairId);
          allow write: if isSignedIn() && isFriendPairMember(friendPairId);
        }

        match /items/{itemId} {
          allow read: if isSignedIn() && isFriendPairMember(friendPairId);
          allow write: if isSignedIn() && isFriendPairMember(friendPairId);
        }

        match /attachments/{attachmentId} {
          allow read: if isSignedIn() && isFriendPairMember(friendPairId);
          allow write: if isSignedIn() && isFriendPairMember(friendPairId);
        }
      }

      // 1:1 Settlements
      match /settlements/{settlementId} {
        allow read: if isSignedIn() && isFriendPairMember(friendPairId);
        allow create: if isSignedIn() && isFriendPairMember(friendPairId);
        allow update: if isSignedIn() && isFriendPairMember(friendPairId);
        allow delete: if false;
      }

      // 1:1 Balance (read-only for clients, written by Cloud Functions)
      match /balance/{balanceId} {
        allow read: if isSignedIn() && isFriendPairMember(friendPairId);
        allow write: if false; // only Cloud Functions
      }

      // 1:1 Activity log (read-only for clients)
      match /activity/{activityId} {
        allow read: if isSignedIn() && isFriendPairMember(friendPairId);
        allow write: if false; // only Cloud Functions
      }
    }

    // User Friends (denormalized, read-only for clients)
    match /userFriends/{userId}/friends/{friendUserId} {
      allow read: if isOwner(userId);
      allow write: if false; // only Cloud Functions
    }
  }
}
```

### 4.2 Cloud Storage Security Rules

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {

    // User avatars
    match /avatars/{userId}/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null
                   && request.auth.uid == userId
                   && request.resource.size < 5 * 1024 * 1024  // 5MB
                   && request.resource.contentType.matches('image/.*');
    }

    // Group cover photos
    match /groups/{groupId}/cover/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null
                   && request.resource.size < 5 * 1024 * 1024
                   && request.resource.contentType.matches('image/.*');
    }

    // Receipt images
    match /groups/{groupId}/receipts/{expenseId}/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null
                   && request.resource.size < 10 * 1024 * 1024  // 10MB
                   && request.resource.contentType.matches('image/.*');
    }
  }
}
```

---

## 5. Push Notification Payloads

### 5.1 Notification Types

```
┌────────────────────────────────────────────────────────────────────┐
│                   NOTIFICATION PAYLOADS                            │
│                                                                    │
│  Type: expense_added                                              │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │ {                                                            │ │
│  │   "title": "New expense in Goa Trip",                       │ │
│  │   "body": "Rahul added 'Lunch at Beach Shack' — ₹2,400",   │ │
│  │   "data": {                                                  │ │
│  │     "type": "expense_added",                                 │ │
│  │     "groupId": "abc123",                                     │ │
│  │     "expenseId": "exp456",                                   │ │
│  │     "route": "/groups/abc123"                                │ │
│  │   }                                                          │ │
│  │ }                                                            │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                    │
│  Type: settlement_recorded                                        │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │ {                                                            │ │
│  │   "title": "Payment received!",                              │ │
│  │   "body": "Amit paid you ₹1,200 in Goa Trip",               │ │
│  │   "data": {                                                  │ │
│  │     "type": "settlement",                                    │ │
│  │     "groupId": "abc123",                                     │ │
│  │     "route": "/groups/abc123/settle"                         │ │
│  │   }                                                          │ │
│  │ }                                                            │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                    │
│  Type: nudge                                                      │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │ {                                                            │ │
│  │   "title": "Friendly reminder 😊",                           │ │
│  │   "body": "Rahul is reminding you about ₹800 in Goa Trip",  │ │
│  │   "data": {                                                  │ │
│  │     "type": "nudge",                                         │ │
│  │     "groupId": "abc123",                                     │ │
│  │     "fromUserId": "user789",                                 │ │
│  │     "route": "/groups/abc123/settle"                         │ │
│  │   }                                                          │ │
│  │ }                                                            │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

---

## 6. Rate Limiting & Abuse Protection

```
┌────────────────────────────────────────────────────────────────────┐
│                   RATE LIMITING                                    │
│                                                                    │
│  Implemented as middleware in Cloud Functions:                     │
│                                                                    │
│  ┌────────────────────────────────┬───────────┬──────────────────┐│
│  │ Endpoint                       │ Limit     │ Window           ││
│  │────────────────────────────────┼───────────┼──────────────────││
│  │ OTP requests (per phone)       │ 5         │ 15 minutes       ││
│  │ Expense creates (per user)     │ 100       │ 1 hour           ││
│  │ Invite generation              │ 10        │ 1 hour           ││
│  │ Nudge sends (per user pair)    │ 3         │ 24 hours         ││
│  │ Export requests                │ 5         │ 1 hour           ││
│  │ Account deletion               │ 1         │ 24 hours         ││
│  └────────────────────────────────┴───────────┴──────────────────┘│
│                                                                    │
│  Implementation: Firestore-backed rate limiter                    │
│  - Document: rateLimits/{userId}_{action}                         │
│  - Fields: count, windowStart                                     │
│  - Checked in Cloud Function before processing                    │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

---

## 7. Cloud Functions Directory Structure

```
functions/
├── src/
│   ├── index.ts                    # Function exports
│   ├── config.ts                   # Environment config
│   │
│   ├── callable/
│   │   ├── simplifyDebts.ts
│   │   ├── generateInvite.ts
│   │   ├── joinViaInvite.ts
│   │   ├── migrateGuest.ts
│   │   ├── deleteAccount.ts
│   │   ├── exportData.ts
│   │   ├── nudgeUser.ts
│   │   └── settleAll.ts
│   │
│   ├── triggers/
│   │   ├── onExpenseWrite.ts
│   │   ├── onSettlementWrite.ts
│   │   ├── onMemberWrite.ts
│   │   └── onUserWrite.ts
│   │
│   ├── scheduled/
│   │   ├── recurringExpenses.ts
│   │   ├── weeklyDigest.ts
│   │   ├── cleanupInvites.ts
│   │   ├── cleanupSoftDeletes.ts
│   │   └── settlementReminders.ts
│   │
│   ├── services/
│   │   ├── balanceService.ts       # Balance recalculation
│   │   ├── debtSimplifier.ts       # Debt minimization algorithm
│   │   ├── notificationService.ts  # FCM send logic
│   │   ├── activityService.ts      # Activity log writes
│   │   └── rateLimiter.ts          # Rate limiting middleware
│   │
│   ├── models/
│   │   ├── expense.ts
│   │   ├── settlement.ts
│   │   ├── balance.ts
│   │   └── notification.ts
│   │
│   └── utils/
│       ├── amountUtils.ts          # Paise arithmetic helpers
│       ├── validators.ts
│       └── firestorePaths.ts
│
├── test/
│   ├── callable/
│   ├── triggers/
│   ├── services/
│   └── rules/
│       ├── firestore.rules.test.ts
│       └── storage.rules.test.ts
│
├── package.json
├── tsconfig.json
├── .eslintrc.js
└── firestore.rules
```
