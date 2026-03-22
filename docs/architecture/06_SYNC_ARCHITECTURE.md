# One By Two — Sync Architecture & Offline-First Design

> **Version:** 2.0  
> **Last Updated:** 2025-07-15

---

## 1. Offline-First Philosophy

The app must be **fully functional without internet**. Users should never be blocked from adding expenses, viewing balances, or recording settlements.

### Core Principles

1. **Firestore SDK is the source of truth** — with built-in offline cache, all reads and writes go through the Firestore SDK
2. **Write-through-SDK** — all mutations are written to the Firestore SDK, which caches locally and syncs to the cloud automatically
3. **Automatic sync** — the Firestore SDK handles queuing pending writes and syncing when connectivity resumes; no custom sync engine needed
4. **Last-write-wins by default** — Firestore's server timestamps determine the winner; transactions used for atomic operations requiring consistency
5. **Transparent connectivity** — user sees offline banner when disconnected; writes continue seamlessly against the local cache

### How Firestore Offline Persistence Works

Firestore SDK (enabled via `settings.persistenceEnabled = true`) maintains a **local disk cache** of all documents the client has read or written. This means:

- **Reads**: The SDK returns data from the local cache instantly. When online, it also listens for server updates and merges them into the cache. Snapshot listeners fire for both cached and server data.
- **Writes**: The SDK accepts writes immediately (even offline) and queues them internally. When connectivity resumes, the SDK replays pending writes to the server in order. The app never needs to manage a sync queue.
- **Cache size**: Configurable via `settings.cacheSizeBytes`. Default is 100MB. When the cache exceeds the configured size, Firestore garbage-collects the least-recently-used documents.
- **Metadata**: Each snapshot includes `metadata.isFromCache` and `metadata.hasPendingWrites`, allowing the UI to show sync state without custom tracking.

---

## 2. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    SYNC ARCHITECTURE                             │
│                                                                  │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────────┐ │
│  │     UI       │────>│  Repository  │────>│  Firestore SDK   │ │
│  │  (Riverpod)  │     │  (write)     │     │                  │ │
│  │              │<────│              │<────│  • Local cache   │ │
│  │              │     │  (read via   │     │    (disk-backed) │ │
│  │              │     │   streams)   │     │  • Pending write │ │
│  │              │     │              │     │    queue (auto)  │ │
│  └──────────────┘     └──────────────┘     └────────┬─────────┘ │
│                                                      │           │
│  ════════════════════════════════════════════════════╪═══════════│
│                   NETWORK BOUNDARY                   │           │
│  ════════════════════════════════════════════════════╪═══════════│
│                                                      │           │
│                                             ┌────────▼─────────┐ │
│                                             │  Cloud Firestore │ │
│                                             │  (asia-south1)   │ │
│                                             │                  │ │
│                                             │ • Authoritative  │ │
│                                             │   data store     │ │
│                                             │ • Real-time sync │ │
│                                             │ • Security Rules │ │
│                                             └────────┬─────────┘ │
│                                                      │           │
│                                             ┌────────▼─────────┐ │
│                                             │ Cloud Functions  │ │
│                                             │ • Recalc balance │ │
│                                             │ • Send push notif│ │
│                                             │ • Activity log   │ │
│                                             └──────────────────┘ │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Key simplification**: There is no separate local database, sync queue, or sync engine. The Firestore SDK's built-in offline cache replaces all of these. The Repository layer talks exclusively to the Firestore SDK, which transparently handles caching and synchronization.

---

## 3. Write Flow (Offline-Safe)

```
┌─────────────────────────────────────────────────────────────────┐
│                    WRITE FLOW (e.g., Add Expense)                │
│                                                                  │
│  User taps "Save"                                                │
│       │                                                          │
│       ▼                                                          │
│  ┌─────────────────────────────────────────┐                    │
│  │ 1. VALIDATE                             │                    │
│  │    - Amount > 0                         │                    │
│  │    - At least one payer                 │                    │
│  │    - At least one participant           │                    │
│  │    - Splits sum equals amount           │                    │
│  └──────────────┬──────────────────────────┘                    │
│                 │                                                │
│       ┌─────────▼─────────┐                                     │
│       │ 2. GENERATE ID    │  UUID v4 on device                  │
│       └─────────┬─────────┘                                     │
│                 │                                                │
│       ┌─────────▼──────────────────────────────────┐            │
│       │ 3. WRITE TO FIRESTORE SDK                  │            │
│       │    Uses batched write for atomicity:        │            │
│       │    batch.set(expenseDoc, expenseData)       │            │
│       │    batch.set(payerDocs, payerData)          │            │
│       │    batch.set(splitDocs, splitData)          │            │
│       │    batch.set(itemDocs, itemData) // if any  │            │
│       │    await batch.commit()                     │            │
│       │                                             │            │
│       │    SDK behavior:                            │            │
│       │    • Online → writes to server immediately  │            │
│       │    • Offline → writes to local cache,       │            │
│       │      queued for server sync automatically   │            │
│       └─────────┬──────────────────────────────────┘            │
│                 │                                                │
│       ┌─────────▼──────────────────────────────────┐            │
│       │ 4. RETURN SUCCESS TO UI (< 200ms)          │            │
│       │    Firestore SDK confirms write to cache    │            │
│       │    instantly — no network round-trip needed  │            │
│       │                                             │            │
│       │    - Snapshot listener fires immediately     │            │
│       │      with hasPendingWrites = true            │            │
│       │    - Expense appears in list instantly       │            │
│       │    - Show undo snackbar (30s)                │            │
│       └─────────┬──────────────────────────────────┘            │
│                 │                                                │
│       ┌─────────▼──────────────────────────────────┐            │
│       │ 5. SDK SYNCS TO CLOUD (automatic)          │            │
│       │    IF online:                               │            │
│       │      - SDK sends write to Cloud Firestore   │            │
│       │      - Snapshot listener fires again with   │            │
│       │        hasPendingWrites = false              │            │
│       │      - Cloud Functions triggered:            │            │
│       │        • Recalculate balances               │            │
│       │        • Log activity                       │            │
│       │        • Send push notifications            │            │
│       │    ELSE:                                    │            │
│       │      - SDK holds write in pending queue     │            │
│       │      - Synced automatically when online     │            │
│       └────────────────────────────────────────────┘            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Write Patterns by Operation Type

| Operation       | Firestore Method           | Atomicity                      |
|-----------------|----------------------------|--------------------------------|
| Add expense     | `WriteBatch` (multi-doc)   | All docs written atomically    |
| Edit expense    | `Transaction` (read+write) | Ensures consistent update      |
| Delete expense  | `update({isDeleted: true})`| Soft delete, single field      |
| Add settlement  | `WriteBatch` (multi-doc)   | Settlement + balance update    |
| Create group    | `WriteBatch` (multi-doc)   | Group doc + member subdocs     |

### Server Timestamps

All documents include `createdAt` and `updatedAt` fields using `FieldValue.serverTimestamp()`. When written offline, these resolve to `null` locally and are assigned by the server upon sync. The UI handles `null` timestamps gracefully by falling back to `DateTime.now()` for display.

---

## 4. Read Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    READ FLOW                                     │
│                                                                  │
│  UI requests data (e.g., group or friend expenses)              │
│       │                                                          │
│       ▼                                                          │
│  ┌─────────────────────────────────────────────────┐            │
│  │ Repository.getExpenses(groupId) OR               │            │
│  │ Repository.getFriendExpenses(friendPairId)       │            │
│  │                                                  │            │
│  │ Returns: Stream<List<Expense>>                   │            │
│  │                                                  │            │
│  │ Source: Firestore SDK snapshot listener           │            │
│  │         (returns cached data when offline,       │            │
│  │          live data when online)                   │            │
│  └──────────────┬──────────────────────────────────┘            │
│                 │                                                │
│       ┌─────────▼──────────────────────────────────┐            │
│       │ Firestore Snapshot Listener                 │            │
│       │                                             │            │
│       │ GROUP:                                      │            │
│       │ firestore.collection('groups/$gid/expenses')│            │
│       │   .where('isDeleted', isEqualTo: false)     │            │
│       │   .orderBy('date', descending: true)        │            │
│       │   .snapshots()                              │            │
│       │                                             │            │
│       │ FRIEND:                                     │            │
│       │ firestore.collection('friends/$fid/expenses')│           │
│       │   .where('isDeleted', isEqualTo: false)     │            │
│       │   .orderBy('date', descending: true)        │            │
│       │   .snapshots()                              │            │
│       │                                             │            │
│       │ Behavior:                                   │            │
│       │ • First emission: data from local cache     │            │
│       │   (instant, even on cold start)             │            │
│       │ • Subsequent emissions: live server updates  │            │
│       │ • snapshot.metadata.isFromCache tells UI     │            │
│       │   whether data is from cache or server      │            │
│       └─────────────────────────────────────────────┘            │
│                                                                  │
│  Result:                                                         │
│  • Instant display from cached data (even offline)              │
│  • Live updates when Firestore pushes remote changes            │
│  • UI reflects local pending writes immediately                 │
│  • No separate local DB query — single data path                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Cache vs Server Reads

The Firestore SDK provides fine-grained control over data source:

```dart
// Default: SDK decides (cache first if available, then server)
firestore.collection('expenses').snapshots();

// Force server read (useful for pull-to-refresh)
firestore.collection('expenses').get(GetOptions(source: Source.server));

// Force cache read (useful for instant display)
firestore.collection('expenses').get(GetOptions(source: Source.cache));
```

For real-time streams (`snapshots()`), the SDK always returns cached data first, then updates with server data when available. This provides the best of both worlds: instant UI and live updates.

---

## 5. Conflict Resolution

### 5.1 Firestore's Default: Last-Write-Wins

Firestore uses **last-write-wins** semantics by default. When two users edit the same document offline, the last write to reach the server overwrites the previous one. For most fields in our app, this is acceptable:

| Field Type         | Strategy            | Rationale                                    |
|--------------------|---------------------|----------------------------------------------|
| description, notes | Last-write-wins     | Low-stakes; either version is fine            |
| category, date     | Last-write-wins     | Low-stakes; either version is fine            |
| amount, splits     | Transaction-based   | Financial data requires consistency           |
| isDeleted          | Last-write-wins     | Delete intent should propagate                |
| group membership   | Server-authoritative| Cloud Function manages canonical member list  |

### 5.2 Transactions for Critical Operations

For operations where consistency matters (e.g., editing an expense's amount), we use Firestore **transactions**:

```
┌─────────────────────────────────────────────────────────────────┐
│            TRANSACTION-BASED EDIT FLOW                           │
│                                                                  │
│  1. Start Firestore transaction                                 │
│  2. Read current document from server                           │
│  3. Validate: has the document changed since user loaded it?    │
│     • Compare updatedAt timestamp                               │
│     • If unchanged → apply edits, commit                        │
│     • If changed → abort, reload latest, prompt user            │
│  4. On commit: server applies atomically                        │
│                                                                  │
│  Note: Transactions require network connectivity.               │
│  If offline, the edit is queued as a regular write              │
│  (last-write-wins) and the user is informed that the            │
│  edit will sync when connectivity resumes.                      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 5.3 Additive Operations

New expenses, new settlements, and new groups use **client-generated UUIDs** as document IDs. Since each document ID is unique, these operations never conflict — they are purely additive and always succeed.

### 5.4 Balance Recalculation

Balances are **not** edited by clients directly. Instead, Cloud Functions listen for expense/settlement changes and recalculate balances server-side. This eliminates balance conflicts entirely:

```
Client writes expense → Cloud Function triggers →
  Recalculates all balances for group/friend →
    Writes updated balance docs →
      Clients receive updated balances via snapshot listeners
```

---

## 6. Firestore Listener Management

```
┌─────────────────────────────────────────────────────────────────┐
│              FIRESTORE LISTENER LIFECYCLE                        │
│                                                                  │
│  Listeners are registered per-screen to minimize read costs:    │
│                                                                  │
│  ┌──────────────────────┬───────────────────────────────────┐   │
│  │ Screen               │ Active Listeners                  │   │
│  │──────────────────────┼───────────────────────────────────│   │
│  │ Home                 │ userGroups/{uid}/groups            │   │
│  │                      │ userFriends/{uid}/friends          │   │
│  │                      │ users/{uid}/notifications          │   │
│  │──────────────────────┼───────────────────────────────────│   │
│  │ Group Detail         │ groups/{gid}/expenses              │   │
│  │                      │ groups/{gid}/balances              │   │
│  │                      │ groups/{gid}/members               │   │
│  │──────────────────────┼───────────────────────────────────│   │
│  │ Friend Detail        │ friends/{fid}/expenses             │   │
│  │                      │ friends/{fid}/balance              │   │
│  │──────────────────────┼───────────────────────────────────│   │
│  │ Activity Feed        │ groups/{gid}/activity              │   │
│  │                      │ friends/{fid}/activity             │   │
│  │──────────────────────┼───────────────────────────────────│   │
│  │ Settle Up (Group)    │ groups/{gid}/balances              │   │
│  │                      │ groups/{gid}/settlements           │   │
│  │──────────────────────┼───────────────────────────────────│   │
│  │ Settle Up (Friend)   │ friends/{fid}/balance              │   │
│  │                      │ friends/{fid}/settlements          │   │
│  └──────────────────────┴───────────────────────────────────┘   │
│                                                                  │
│  Lifecycle:                                                      │
│  • Listener started when screen is opened (via Riverpod)        │
│  • Listener disposed when screen is popped                      │
│  • Riverpod autoDispose ensures no memory leaks                 │
│  • Snapshot streams drive UI directly — no intermediate DB      │
│                                                                  │
│  Cost optimization:                                              │
│  • Listen to changed docs only (Firestore incremental sync)     │
│  • Use field masks where possible                               │
│  • Pagination for large collections (expenses)                  │
│  • Debounce rapid changes (200ms window)                        │
│                                                                  │
│  Snapshot metadata:                                              │
│  • snapshot.metadata.isFromCache — true when data is cached     │
│  • snapshot.metadata.hasPendingWrites — true when local writes  │
│    have not yet been confirmed by the server                    │
│  • docChange.type — 'added', 'modified', 'removed'             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 7. Connectivity & Sync Status

### 7.1 Connectivity Handling

The app monitors network connectivity to provide appropriate UI feedback. However, unlike a custom sync engine, **no action is needed** on connectivity changes — the Firestore SDK resumes syncing automatically.

```
┌─────────────────────────────────────────────────────────────────┐
│              CONNECTIVITY STATE MACHINE                          │
│                                                                  │
│  ┌─────────┐    network lost    ┌──────────┐                   │
│  │ ONLINE  │ ──────────────────>│ OFFLINE  │                   │
│  │         │                    │          │                   │
│  │ • Reads │    network back    │ • Reads  │                   │
│  │   from  │ <──────────────────│   from   │                   │
│  │   server│                    │   cache  │                   │
│  │ • Writes│                    │ • Writes │                   │
│  │   sync  │                    │   queued │                   │
│  │   live  │                    │   by SDK │                   │
│  └─────────┘                    └──────────┘                   │
│                                                                  │
│  UI behavior:                                                    │
│  • ONLINE:  No banner. Data streams from server.                │
│  • OFFLINE: Show offline banner. All features still work.       │
│             Pending writes indicated via hasPendingWrites.       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 7.2 Sync Status Indicators

```
┌─────────────────────────────────────────────────────────────────┐
│              SYNC STATUS UI                                      │
│                                                                  │
│  Determined from Firestore snapshot metadata:                   │
│                                                                  │
│  ✓  Synced     — hasPendingWrites = false, isFromCache = false  │
│                  Green checkmark, subtle                        │
│  ↑  Pending    — hasPendingWrites = true                        │
│                  Blue upload arrow, shown while offline          │
│  ☁  Cached     — isFromCache = true, hasPendingWrites = false   │
│                  Grey cloud icon, data from cache               │
│                                                                  │
│  No custom sync_status field needed — metadata is live.         │
│                                                                  │
│  Offline Banner (shown when no internet):                       │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  📵 You're offline. Changes will sync when connected.    │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 8. Data Flow Diagram (Complete)

```
┌──────────────────────────────────────────────────────────────────────┐
│                     COMPLETE DATA FLOW                                │
│                                                                      │
│                        ┌───────────┐                                 │
│                        │    UI     │                                 │
│                        │ (Flutter) │                                 │
│                        └─────┬─────┘                                 │
│                     reads ↑  │ writes                                │
│                              │                                       │
│                     ┌────────▼────────┐                              │
│                     │    Riverpod     │                              │
│                     │   Providers     │                              │
│                     └────────┬────────┘                              │
│                              │                                       │
│                     ┌────────▼────────┐                              │
│                     │   Use Cases     │                              │
│                     │   (Domain)      │                              │
│                     └────────┬────────┘                              │
│                              │                                       │
│                     ┌────────▼────────┐                              │
│                     │  Repositories   │                              │
│                     │  (Data Layer)   │                              │
│                     └────────┬────────┘                              │
│                              │                                       │
│                     ┌────────▼────────┐                              │
│                     │  Firestore SDK  │                              │
│                     │                 │                              │
│                     │  • Local cache  │                              │
│                     │    (disk-backed)│                              │
│                     │  • Pending write│                              │
│                     │    queue (auto) │                              │
│                     │  • Snapshot     │                              │
│                     │    listeners    │                              │
│                     └────────┬────────┘                              │
│                              │                                       │
│           ═══════════════════╪═══════════════                        │
│                              │                                       │
│                     ┌────────▼────────┐                              │
│                     │ Cloud Firestore │                              │
│                     │ (asia-south1)   │                              │
│                     └────────┬────────┘                              │
│                              │                                       │
│                     ┌────────▼────────┐                              │
│                     │ Cloud Functions │                              │
│                     │ • Recalc balance│                              │
│                     │ • Send push ntf │                              │
│                     │ • Activity log  │                              │
│                     └─────────────────┘                              │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```
