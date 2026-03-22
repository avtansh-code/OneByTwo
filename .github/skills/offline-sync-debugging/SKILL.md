---
name: offline-sync-debugging
description: "Systematic debugging guide for Firestore offline sync issues. Covers the 5 most common sync problems with diagnostic steps and solutions."
---

# Offline Sync Debugging

## How Firestore Offline Sync Works

Firestore's offline persistence is enabled by default on mobile (Flutter). Here's the key architecture:

1. **Local disk-backed cache:** The SDK maintains a local copy of all documents the client has read or written.
2. **Write queue:** Writes go to the local cache first, then are queued for server sync. The SDK handles retry automatically.
3. **Optimistic reads:** Reads return from cache immediately, then merge server updates when available.
4. **Metadata flags:**
   - `metadata.isFromCache` → `true` if the data was served from the local cache (no server confirmation)
   - `metadata.hasPendingWrites` → `true` if the document has local writes that haven't synced to the server yet
5. **Snapshot listeners:** `snapshots()` streams receive events for both local and remote changes, enabling real-time UI updates.

### Key Implications for One By Two

- Expenses created offline are immediately visible to the creating user
- Other group members won't see the expense until it syncs
- Balance recalculations (Cloud Functions) only trigger after sync
- Conflict resolution depends on server timestamps and version fields

---

## The 5 Common Sync Issues

### Issue 1: Data Not Syncing to Server

**Symptoms:**

- `hasPendingWrites` stays `true` indefinitely
- Other users don't see the changes
- No error thrown on the client

**Diagnostic Steps:**

1. **Check network connectivity:**

   ```dart
   final result = await Connectivity().checkConnectivity();
   debugPrint('Connectivity: $result');
   ```

2. **Check pending writes count:**

   ```dart
   final snapshots = await FirebaseFirestore.instance
       .collection('groups/$groupId/expenses')
       .get();
   final pendingCount = snapshots.docs
       .where((d) => d.metadata.hasPendingWrites)
       .length;
   debugPrint('Pending writes: $pendingCount');
   ```

3. **Check for security rule rejections:**
   - Pending writes that violate security rules will silently fail
   - Check Firebase console → Firestore → Usage → Denied reads/writes
   - Or check device logs for `PERMISSION_DENIED`

4. **Check Firestore queue in logs:**

   ```bash
   grep "PERMISSION_DENIED" app.log
   grep "Sync.Queue" app.log | jq '.'
   ```

**Solutions:**

| Cause | Solution |
|-------|----------|
| Network issue | Wait for reconnect — SDK handles automatically. No action needed. |
| Security rules rejection | Fix `firestore.rules`, test with emulator, redeploy |
| Corrupted local cache | `FirebaseFirestore.instance.clearPersistence()` — **caution:** loses all unsynced local data |
| SDK bug (rare) | Update `cloud_firestore` package, check GitHub issues |

---

### Issue 2: Remote Changes Not Appearing Locally

**Symptoms:**

- Another user added an expense, but it doesn't appear on this device
- Data appears after app restart but not in real-time

**Diagnostic Steps:**

1. **Is a snapshot listener active?**

   ```dart
   // This should be active for real-time updates:
   FirebaseFirestore.instance
       .collection('groups/$groupId/expenses')
       .orderBy('createdAt', descending: true)
       .snapshots()  // ← Must use snapshots(), not get()
       .listen((snapshot) { ... });
   ```

2. **Is the query filtering out the data?**
   - Check `where` clauses — are they too restrictive?
   - Does the new document match the query's conditions?

3. **Is the listener disposed prematurely?**
   - Check widget lifecycle — is the `StreamSubscription` cancelled on `dispose()`?
   - With Riverpod, check `ref.onDispose()` cleanup

4. **Check metadata:**

   ```dart
   .snapshots(includeMetadataChanges: true)
   .listen((snapshot) {
     debugPrint('From cache: ${snapshot.metadata.isFromCache}');
     debugPrint('Docs: ${snapshot.docs.length}');
   });
   ```

**Solutions:**

| Cause | Solution |
|-------|----------|
| Using `get()` instead of `snapshots()` | Switch to `snapshots()` for real-time data |
| Query filter too restrictive | Adjust `where` clauses to include the missing documents |
| Listener disposed | Fix lifecycle management — ensure listener survives navigation |
| Missing `includeMetadataChanges` | Add it to debug, but it's not required for data updates |

---

### Issue 3: Duplicate Entries After Sync

**Symptoms:**

- Same expense appears twice in the list
- Duplicates appear after going online from offline

**Diagnostic Steps:**

1. **Check document IDs:**

   ```dart
   // Are you using device-generated UUIDs?
   final id = const Uuid().v4(); // ✅ Good: deterministic per creation
   // Or server-generated IDs?
   final ref = collection.doc(); // ⚠️ Risk: retry creates new doc
   ```

2. **Check for retry logic creating duplicates:**
   - Is there a manual retry mechanism on top of Firestore's built-in queue?
   - Does the UI allow double-tap on "Save"?

3. **Check Cloud Function triggers:**
   - Is `onExpenseCreated` firing twice?
   - Check Cloud Functions logs for duplicate invocations

**Solutions:**

| Cause | Solution |
|-------|----------|
| Server-generated IDs with retry | Use UUID v4 generated on device — same ID = same document |
| Double-tap on save button | Debounce the save action, disable button after first tap |
| Non-idempotent Cloud Functions | Make triggers idempotent — check if work already done before proceeding |
| UI not deduplicating | Use document ID as list key, not list index |

**Prevention pattern:**

```dart
Future<void> addExpense(Expense expense) async {
  // Use a deterministic ID generated on the client
  final docRef = _firestore
      .collection('groups/${expense.groupId}/expenses')
      .doc(expense.id); // ← ID set by client

  // set() with a known ID is idempotent
  await docRef.set(expense.toJson());
}
```

---

### Issue 4: Conflict Detection Not Working

**Symptoms:**

- Two users edit the same expense offline
- When both sync, one overwrites the other with no conflict warning
- Balance calculations are incorrect

**Diagnostic Steps:**

1. **Check `version` field:**

   ```dart
   // Is version being incremented on every write?
   await docRef.update({
     ...updatedFields,
     'version': FieldValue.increment(1),
     'updatedAt': FieldValue.serverTimestamp(),
   });
   ```

2. **Check conflict detection in Cloud Functions:**

   ```typescript
   // Is the trigger comparing versions?
   exports.onExpenseUpdated = onDocumentUpdated(
     'groups/{groupId}/expenses/{expenseId}',
     async (event) => {
       const before = event.data?.before.data();
       const after = event.data?.after.data();
       if (before?.version === after?.version) {
         // No real change, skip
         return;
       }
       // Process the update...
     }
   );
   ```

3. **Check server timestamp usage:**
   - Are you using `FieldValue.serverTimestamp()` or `DateTime.now()`?
   - `DateTime.now()` uses device clock (unreliable offline)

**Solutions:**

| Cause | Solution |
|-------|----------|
| No version field | Add `version: int` field, increment on every update |
| Using device clock | Use `FieldValue.serverTimestamp()` for `updatedAt` |
| No conflict detection | Add version check in Cloud Function trigger |
| Last-write-wins without warning | Implement optimistic locking: reject update if `version != expected` |

**Optimistic locking pattern:**

```dart
Future<Result<void>> updateExpense(Expense expense) async {
  final docRef = _firestore.doc('groups/${expense.groupId}/expenses/${expense.id}');

  return _firestore.runTransaction((txn) async {
    final snapshot = await txn.get(docRef);
    final serverVersion = snapshot.data()?['version'] ?? 0;

    if (serverVersion != expense.version) {
      throw ConflictException(
        'Expense was modified by another user. Please refresh and try again.',
      );
    }

    txn.update(docRef, {
      ...expense.toJson(),
      'version': serverVersion + 1,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  });
}
```

---

### Issue 5: Stale Data After Reconnect

**Symptoms:**

- App shows old data even after going back online
- New data only appears after force-closing and reopening the app
- `isFromCache` stays `true` after reconnection

**Diagnostic Steps:**

1. **Check listener type:**

   ```dart
   // ❌ One-shot get — never updates
   final snapshot = await collection.get();

   // ✅ Real-time listener — updates automatically
   collection.snapshots().listen((snapshot) { ... });
   ```

2. **Check for hardcoded cache source:**

   ```dart
   // ❌ This forces cache-only reads
   final snapshot = await collection.get(GetOptions(source: Source.cache));
   ```

   Search codebase: `grep -r "Source.cache" lib/`

3. **Check listener lifecycle:**
   - Was the listener disposed on network disconnect and not re-created?
   - Are listeners being recreated on route push/pop?

4. **Check Riverpod provider lifecycle:**

   ```dart
   // Is the provider being disposed when it shouldn't be?
   // autoDispose providers are disposed when no listener is active
   final expensesProvider = StreamProvider.autoDispose.family<List<Expense>, String>(
     (ref, groupId) {
       ref.keepAlive(); // ← Consider this if data should persist
       return repo.watchExpenses(groupId);
     },
   );
   ```

**Solutions:**

| Cause | Solution |
|-------|----------|
| Using `get()` for real-time data | Switch to `snapshots()` |
| Hardcoded `Source.cache` | Remove explicit source option — let SDK decide |
| Listener disposed on disconnect | Don't dispose listeners on network change — SDK handles reconnection |
| `autoDispose` too aggressive | Use `ref.keepAlive()` or remove `autoDispose` for critical data |
| Stale provider state | Invalidate the provider: `ref.invalidate(expensesProvider(groupId))` |

---

## Debugging Commands

```bash
# Check for pending writes in logs
grep "hasPendingWrites.*true" app.log | jq '.'

# Check for security rule rejections
grep "PERMISSION_DENIED" app.log | jq '.'

# Check listener lifecycle events
grep "FS.Listen" app.log | jq 'select(.msg | contains("start") or contains("end"))'

# Check sync queue status
grep "Sync.Queue" app.log | jq '.'

# Check network state changes
grep "connectivity" app.log | jq '.'

# Check for duplicate document writes
grep "FS.Write" app.log | jq '.docId' | sort | uniq -d
```

---

## Offline Sync Testing Checklist

### Manual Testing Scenarios

- [ ] Create expense offline → verify it appears locally immediately
- [ ] Go online → verify expense syncs (hasPendingWrites becomes false)
- [ ] Verify other users see the expense after sync
- [ ] Create expense offline → close app → reopen online → verify sync
- [ ] Two users edit same expense offline → verify conflict is detected
- [ ] Delete expense offline → verify deletion syncs correctly
- [ ] Verify balance recalculation triggers after sync

### Automated Testing

- [ ] Test with `FakeFirebaseFirestore` for offline scenarios
- [ ] Test `hasPendingWrites` metadata handling
- [ ] Test conflict detection logic with version mismatches
- [ ] Test idempotent operations (same write twice = same result)

---

## Architecture Guidelines for Offline-First

1. **Always use `snapshots()`** for data that should update in real-time
2. **Generate document IDs on the client** (UUID v4) for idempotent writes
3. **Use `FieldValue.serverTimestamp()`** for all timestamp fields
4. **Increment version fields** on every update for conflict detection
5. **Never use `Source.cache` explicitly** — let the SDK manage cache strategy
6. **Design Cloud Functions to be idempotent** — they may fire multiple times
7. **Show sync status in the UI** — users should know when data is pending sync
