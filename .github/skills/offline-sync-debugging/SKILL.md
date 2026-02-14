---
name: offline-sync-debugging
description: Guide for debugging offline sync issues in the One By Two app — sync queue processing, conflict resolution, Firestore listener management, and data consistency between local sqflite and remote Firestore.
---

## Sync Architecture Overview

The app uses an **offline-first** pattern:
- All writes save to local sqflite first (sync_status = 'pending')
- A sync queue processes pending items when online
- Firestore listeners update local DB in background
- Conflicts detected via integer `version` field

See `docs/architecture/06_SYNC_ARCHITECTURE.md` for full details.

## Debugging Sync Issues

### 1. Data Written Locally But Not Syncing

**Symptoms:** Expense shows ↑ (pending) icon indefinitely.

**Diagnosis steps:**
1. Check `sync_queue` table for stuck items:
   ```sql
   SELECT * FROM sync_queue WHERE status != 'completed' ORDER BY created_at;
   ```
2. Check if connectivity is detected:
   ```dart
   // In app: ref.read(connectivityProvider)
   ```
3. Check retry count — items with `retry_count >= 5` are marked `failed`:
   ```sql
   SELECT * FROM sync_queue WHERE retry_count >= 5;
   ```
4. Check Firestore security rules — a rule rejection shows in Cloud Function logs

**Common causes:**
- Connectivity state stale (listener not re-established after app resume)
- Firestore security rule rejecting the write (auth token expired)
- Sync service not started (missing initialization in app bootstrap)
- Exponential backoff timer not resetting after reconnect

### 2. Data Visible in Firestore But Not in Local UI

**Symptoms:** Other users see the expense but this device doesn't.

**Diagnosis steps:**
1. Check if Firestore listener is active for the collection:
   ```dart
   // Verify listener exists in FirestoreListenerManager
   ```
2. Check if the listener's `onData` callback is writing to sqflite
3. Check if the sqflite DAO emits stream updates after write
4. Check if the provider is watching the correct stream

**Common causes:**
- Listener disposed too early (screen popped before sync complete)
- Listener not re-established after auth token refresh
- sqflite DAO not using `notifyListeners` pattern
- Provider watching wrong group/collection

### 3. Duplicate Entries After Sync

**Symptoms:** Same expense appears twice.

**Diagnosis steps:**
1. Check if IDs are truly duplicated or just visually similar
2. Check sync queue — was the same operation enqueued twice?
   ```sql
   SELECT entity_id, COUNT(*) FROM sync_queue GROUP BY entity_id HAVING COUNT(*) > 1;
   ```
3. Check if Firestore listener re-processed an existing document

**Common causes:**
- Missing idempotency check in listener callback (should be UPSERT, not INSERT)
- Sync queue item not marked `completed` after successful Firestore write
- Race condition between sync queue processing and listener receiving the write-back

### 4. Conflict Detection Issues

**Symptoms:** Edits from another device silently overwritten.

**Diagnosis steps:**
1. Check `version` field on both local and remote document
2. Check conflict resolution logic:
   - Delete always wins
   - Last-write-wins for non-critical fields (description, notes)
   - User prompt for critical fields (amount, splits)
3. Check if `conflict` status is being set correctly:
   ```sql
   SELECT * FROM expenses WHERE sync_status = 'conflict';
   ```

**Common causes:**
- Version field not incremented on local edit
- Conflict detection comparing wrong fields
- User conflict resolution UI not shown (missing provider state)

### 5. Stale Data After Reconnect

**Symptoms:** App shows old balances after going online.

**Diagnosis steps:**
1. Check if Firestore listeners resume after connectivity change
2. Check if balance recalculation triggered on sync
3. Check timestamp of last successful sync

**Common causes:**
- Connectivity listener not firing on WiFi↔cellular transitions
- Firestore SDK cache not invalidated
- Balance provider not re-computing after sync

## Sync Queue States

```
pending → processing → completed
                    → failed (after 5 retries)
                    → conflict (version mismatch detected)
```

## Key Tables for Debugging

```sql
-- Pending sync items
SELECT * FROM sync_queue WHERE status = 'pending' ORDER BY created_at;

-- Failed items
SELECT * FROM sync_queue WHERE status = 'failed';

-- Conflicts
SELECT * FROM sync_queue WHERE status = 'conflict';

-- Items with entities that have mismatched sync status
SELECT e.id, e.sync_status, sq.status as queue_status
FROM expenses e
LEFT JOIN sync_queue sq ON sq.entity_id = e.id AND sq.entity_type = 'expense'
WHERE e.sync_status != 'synced';
```

## Reference

- Sync architecture: `docs/architecture/06_SYNC_ARCHITECTURE.md`
- Algorithms (conflict resolution): `docs/architecture/10_ALGORITHMS.md`
