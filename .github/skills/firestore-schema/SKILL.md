---
name: firestore-schema
description: "Guide for managing Firestore collection/document structure, schema evolution, backward compatibility, and data migration strategies for the One By Two app."
---

# Firestore Schema Management

## Current Collection Hierarchy

```text
firestore-root/
├── users/{userId}
│   ├── notifications/{notificationId}
│   └── drafts/{draftId}
├── groups/{groupId}
│   ├── members/{userId}
│   ├── expenses/{expenseId}
│   │   ├── splits/{splitId}
│   │   ├── payers/{payerId}
│   │   └── items/{itemId}
│   ├── settlements/{settlementId}
│   ├── balances/{balancePairId}     # Cloud Functions write-only
│   └── activity/{activityId}        # Cloud Functions write-only
├── friends/{friendPairId}            # ID: min(a,b)_max(a,b)
│   ├── expenses/{expenseId}
│   ├── settlements/{settlementId}
│   ├── balance/{balanceDocId}        # Cloud Functions write-only
│   └── activity/{activityId}
├── invites/{inviteCode}
├── userGroups/{userId}/groups/{groupId}
└── userFriends/{userId}/friends/{friendUserId}
```

---

## Schema Evolution Rules

### NEVER Remove Fields — Only Add New Ones

Removing fields breaks older app versions that still read those fields. Always keep old fields in place, even if deprecated.

### Add `schemaVersion` Field to Every Document Type

Every document must include a `schemaVersion` integer field. This enables conditional migration logic in `fromFirestore()` and Cloud Functions.

### Read-Time Migration (Lazy)

The `fromFirestore()` factory on every model must provide sensible default values for any field that may be missing in older documents. This ensures the app gracefully handles documents written before a field existed.

```dart
factory ExpenseModel.fromFirestore(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  return ExpenseModel(
    id: doc.id,
    description: data['description'] ?? '',
    amount: data['amount'] ?? 0,
    currency: data['currency'] ?? 'INR',
    splitType: data['splitType'] ?? 'equal',
    // New field added in v2 — default for old docs
    receiptUrl: data['receiptUrl'],
    schemaVersion: data['schemaVersion'] ?? 1,
  );
}
```

### Write-Time Upgrade (Opportunistic)

When any field on a document is updated, also bump `schemaVersion` and populate any missing fields with their correct defaults. This progressively migrates old documents without a dedicated batch job.

### Batch Migration (Rare)

Only for breaking changes that cannot be handled lazily. Use a Cloud Function to batch-update documents:

```typescript
export const migrateExpensesV2 = functions.https.onRequest(async (req, res) => {
  const batch = firestore.batch();
  const snapshot = await firestore
    .collectionGroup('expenses')
    .where('schemaVersion', '<', 2)
    .limit(500)
    .get();

  snapshot.docs.forEach(doc => {
    batch.update(doc.ref, {
      currency: 'INR',
      schemaVersion: 2,
    });
  });

  await batch.commit();
  res.json({ migrated: snapshot.size });
});
```

---

## Adding a New Collection — Checklist

- [ ] Define document schema (all fields, types, defaults)
- [ ] Add `schemaVersion` field
- [ ] Create Firestore indexes (if needed for queries)
- [ ] Write security rules (read/write/create/delete)
- [ ] Create Dart model class (`@JsonSerializable`)
- [ ] Create Dart entity class (`@freezed`)
- [ ] Create mapper (entity ↔ model)
- [ ] Create Firestore data source
- [ ] Update `docs/architecture/02_DATABASE_SCHEMA.md`
- [ ] Write security rules tests (positive + negative)

---

## Adding a New Field — Checklist

- [ ] Add field with sensible default (backward compatible)
- [ ] Update model class + `fromJson`/`toJson`
- [ ] Update entity class (freezed)
- [ ] Update mapper
- [ ] Add lazy migration in `fromFirestore()` for old docs
- [ ] Update schema doc

---

## ID Generation Strategies

| Strategy | Format | When to Use |
|----------|--------|-------------|
| Auto-generated | Firestore `.doc()` — 20 chars, URL-safe | Only when online-safe (server-confirmed writes) |
| Client UUID | `Uuid().v4()` | Always use for offline-safe writes |
| Deterministic | `${min(a,b)}_${max(a,b)}` | Balance pairs, friend pairs |
| Invite codes | 8-char alphanumeric (base36, uppercase) | Invite links |

### Examples

```dart
// Offline-safe expense ID
final expenseId = const Uuid().v4();

// Deterministic friend pair ID
String friendPairId(String a, String b) {
  final sorted = [a, b]..sort();
  return '${sorted[0]}_${sorted[1]}';
}

// Invite code
String generateInviteCode() {
  final random = Random.secure();
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
}
```

---

## Denormalization Patterns

Denormalized data **must** be kept in sync via Cloud Functions triggers. Never rely on the client to update denormalized copies.

| Denormalized Field | Location | Source of Truth | Update Trigger |
|-------------------|----------|-----------------|----------------|
| `memberCount` | `groups/{gid}` | `groups/{gid}/members` subcollection | `onWrite` members |
| `myBalance` | `userGroups/{uid}/groups/{gid}` | `groups/{gid}/balances` | `onWrite` balances |
| `lastActivityAt` | `userGroups/{uid}/groups/{gid}` | `groups/{gid}/activity` | `onWrite` activity |
| `member.name` | `groups/{gid}/members/{uid}` | `users/{uid}.displayName` | `onUpdate` user profile |

### Rules

1. The client **reads** denormalized data for display and sorting.
2. The client **never writes** to denormalized fields directly.
3. Cloud Functions **own** all denormalized field updates.
4. If a Cloud Function fails, the denormalized data becomes stale — design UIs to tolerate short staleness.
5. Log all denormalization updates with tag `CF.Denorm` for debugging.
