---
name: code-review
description: Guide for reviewing code changes in the One By Two app. Use this when reviewing PRs, diffs, or code changes to catch bugs, security issues, architecture violations, and correctness problems.
---

## Review Philosophy

Only flag issues that **genuinely matter** — bugs, security vulnerabilities, logic errors, data integrity risks, and architecture violations. Never comment on formatting, import ordering, or stylistic preferences handled by linters.

## Severity Levels

| Severity | Meaning | Examples |
|----------|---------|---------|
| 🔴 Blocker | Data loss, crash, or security breach | Money as `double`, hard-delete, PII logged, missing auth check |
| 🟠 Important | Incorrect behavior or architecture violation | Missing `syncStatus`, domain importing Flutter, uncaught exception |
| 🟡 Suggestion | Improvement, not a defect | Missing `const`, log level mismatch, could use Result pattern |

---

## Critical Checks

### 1. Money & Paise (🔴 Blocker)

All monetary amounts must be integers in paise (1 ₹ = 100 paise).

```dart
// ❌ BLOCKER
final double amount = 150.50;
final split = totalAmount / memberCount;

// ✅ Correct
final int amountPaise = 15050;
final baseSplit = totalAmountPaise ~/ memberCount;
final remainder = totalAmountPaise % memberCount;
```

Any `double` storing money is a blocker.

### 2. Split Calculation Invariants (🔴 Blocker)

Every split must satisfy:
- `sum(splits) == totalAmountPaise` — exact, no drift
- `max(split) - min(split) <= 1` paisa — fairness
- Use Largest Remainder Method for remainder distribution

```dart
// ❌ Remainder discarded
final split = totalPaise ~/ count;

// ✅ Remainder distributed
final base = totalPaise ~/ count;
final remainder = totalPaise % count;
for (var i = 0; i < count; i++) {
  splits[i] = base + (i < remainder ? 1 : 0);
}
```

### 3. Balance Pair Canonical Ordering (🔴 Blocker)

Balance pair IDs must use deterministic ordering: `min(userA, userB)_max(userA, userB)`.

```dart
// ❌ Order depends on caller
final pairId = '${payerId}_${payeeId}';

// ✅ Canonical
String canonicalPairId(String a, String b) =>
  a.compareTo(b) < 0 ? '${a}_${b}' : '${b}_${a}';
```

Sign convention for `BalancePairKey(A, B)` where `A < B`:
- `amount > 0` → A owes B
- `amount < 0` → B owes A

### 4. Soft Deletes Only (🔴 Blocker)

Never hard-delete expenses or settlements.

```dart
// ❌ Hard delete
await db.delete('expenses', where: 'id = ?', whereArgs: [id]);

// ✅ Soft delete
await db.update('expenses', {'is_deleted': 1, 'deleted_at': now},
  where: 'id = ?', whereArgs: [id]);
```

All queries on soft-deletable tables must filter `WHERE is_deleted = 0`.

### 5. Sync Status (🟠 Important)

Every syncable entity needs `syncStatus` (`synced`, `pending`, `conflict`).

- New entity → `syncStatus = pending`
- Entity modified → update `syncStatus` to `pending`
- Must enqueue to sync queue after local write

### 6. Version Field (🟠 Important)

Mutable entities need an integer `version` field. On update, increment version. On conflict, version comparison determines winner.

### 7. Dual Context (🟠 Important)

Expenses/settlements belong to either a group OR friend pair — never both.

```dart
// ❌ Both set
Expense(groupId: 'g1', friendPairId: 'fp1')

// ✅ Mutually exclusive
Expense(groupId: 'g1', friendPairId: null, contextType: 'group')
```

---

## Architecture Checks

### Clean Architecture Boundaries

| Check | Severity |
|-------|----------|
| Domain layer imports Flutter or Firebase | 🔴 |
| Presentation layer directly accesses DAO | 🔴 |
| Widget directly calls Firestore | 🔴 |
| Repository returns raw Firebase types | 🟠 |
| Use case contains UI logic | 🟠 |

### Offline-First Pattern

| Check | Severity |
|-------|----------|
| UI reads from Firestore instead of sqflite | 🔴 |
| Write goes to Firestore without local-first | 🔴 |
| Missing sync queue enqueue after local write | 🟠 |
| UI blocks on network call | 🟠 |

### Result Pattern

Repositories must return `Result<T>`, not throw exceptions.

```dart
// ❌ Throws
Future<Expense> getExpense(String id) async {
  final row = await dao.get(id);
  if (row == null) throw NotFoundException();
  return row;
}

// ✅ Returns Result
Future<Result<Expense>> getExpense(String id) async {
  try {
    final row = await dao.get(id);
    if (row == null) return Result.failure(NotFoundFailure());
    return Result.success(row);
  } catch (e, stack) {
    return Result.failure(StorageFailure(e.toString()));
  }
}
```

---

## Security Checks

### PII in Logs (🔴 Blocker)

```dart
// ❌ PII leaked
AppLogger.instance.info(_tag, 'User logged in', {
  'phone': user.phoneNumber,   // PII!
  'name': user.displayName,    // PII!
});

// ✅ IDs only
AppLogger.instance.info(_tag, 'User logged in', {
  'userId': user.uid,
  'durationMs': stopwatch.elapsedMilliseconds,
});
```

**Banned in logs:** phone numbers, emails, user names, OTP codes, auth tokens, user-entered text.

### Logging Infrastructure

| Check | Severity |
|-------|----------|
| Uses `print()` or `debugPrint()` | 🟠 |
| Missing `static const _tag` in class | 🟡 |
| Error logged without stack trace | 🟡 |
| Missing `durationMs` on async operation | 🟡 |

### Cloud Functions

| Check | Severity |
|-------|----------|
| Missing `request.auth` check in callable | 🔴 |
| Input not validated before processing | 🔴 |
| Using `any` type in TypeScript | 🟠 |
| Missing rate limiting on sensitive op | 🟠 |
| PII in structured log data | 🔴 |

### Firebase Security Rules

| Check | Severity |
|-------|----------|
| Open collection access | 🔴 |
| Client can write balances/activity directly | 🔴 |
| Missing group membership check on read | 🔴 |
| Allows hard-delete of expenses | 🔴 |

---

## Code Quality Checks

### Freezed & Code Generation

| Check | Severity |
|-------|----------|
| Mutable data model (missing `@freezed`) | 🟠 |
| Modified model but `.g.dart` not regenerated | 🔴 |
| Manually edited `*.g.dart` or `*.freezed.dart` | 🔴 |

### Riverpod

| Check | Severity |
|-------|----------|
| Provider missing `@riverpod` annotation | 🟠 |
| Firestore listener not disposed on provider dispose | 🟠 |
| Provider disposing resources it doesn't own | 🟠 |

### Localization

| Check | Severity |
|-------|----------|
| Hardcoded user-facing string | 🟠 |
| Missing `@key` metadata in ARB | 🟡 |
| Key in English ARB but missing from Hindi | 🟡 |

---

## Things to Ignore

Do **not** flag — handled by linters or not actionable:

- Code formatting (`dart format`)
- Import ordering
- Variable naming (unless genuinely confusing)
- TODO/FIXME comments (unless masking shipped bugs)
- Test coverage gaps (unless critical path untested)
- Dependency version bumps (unless security-related)

---

## Review Output Format

```
## Review: <title>

### Verdict: LGTM / Changes Requested / Needs Discussion

### 🔴 Blockers
[file:line] Description
  Why: Impact
  Fix: Suggested change

### 🟠 Important
[file:line] Description

### 🟡 Suggestions
[file:line] Description

### ✅ What Looks Good
- Positive callouts
```

Group issues by file. Lead with blockers, then important, then suggestions.
