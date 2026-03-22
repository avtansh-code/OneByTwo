---
name: logging
description: "Guide for implementing structured logging in the One By Two app. Covers AppLogger usage, tag conventions, PII rules, file rotation, and environment-specific configuration."
---

# Logging Guide

## AppLogger Usage

```dart
import 'package:one_by_two/core/logging/app_logger.dart';

class ExpenseRepository {
  static const _tag = 'Repo.Expense';

  Future<Result<Expense>> addExpense(Expense expense) async {
    AppLogger.info(_tag, 'Adding expense', data: {
      'groupId': expense.groupId,
      'amount': expense.amount, // paise, not PII
      'splitType': expense.splitType.name,
    });

    try {
      // ... implementation
      AppLogger.debug(_tag, 'Expense written to Firestore', data: {
        'expenseId': expense.id,
        'hasPendingWrites': true,
      });
      return Result.success(expense);
    } catch (e, stack) {
      AppLogger.error(_tag, 'Failed to add expense', error: e, stackTrace: stack);
      return Result.failure(DataException('Failed to add expense'));
    }
  }
}
```

### API Reference

```dart
AppLogger.verbose(String tag, String message, {Map<String, dynamic>? data});
AppLogger.debug(String tag, String message, {Map<String, dynamic>? data});
AppLogger.info(String tag, String message, {Map<String, dynamic>? data});
AppLogger.warning(String tag, String message, {Map<String, dynamic>? data});
AppLogger.error(String tag, String message, {Object? error, StackTrace? stackTrace, Map<String, dynamic>? data});
AppLogger.fatal(String tag, String message, {Object? error, StackTrace? stackTrace, Map<String, dynamic>? data});
```

---

## Tag Naming Convention

Tags follow the format **`Layer.Component`**:

| Tag Pattern | Layer | Examples |
|------------|-------|----------|
| `Boot.*` | App startup | `Boot.Firebase`, `Boot.Providers`, `Boot.Ready` |
| `Auth.*` | Authentication | `Auth.OTP`, `Auth.Token`, `Auth.SignOut` |
| `Sync.*` | Sync engine | `Sync.Queue`, `Sync.Complete`, `Sync.Conflict` |
| `Repo.*` | Repositories | `Repo.Expense`, `Repo.Group`, `Repo.Balance` |
| `DAO.*` | Data sources | `DAO.Expense`, `DAO.User` |
| `FS.*` | Firestore SDK | `FS.Write`, `FS.Listen`, `FS.Batch` |
| `CF.*` | Cloud Functions | `CF.SimplifyDebts`, `CF.Invite` |
| `UI.*` | User interface | `UI.AddExpense`, `UI.GroupDetail` |
| `Nav.*` | Navigation | `Nav.Push`, `Nav.Pop`, `Nav.Redirect` |
| `FCM.*` | Push notifications | `FCM.Token`, `FCM.Receive`, `FCM.Tap` |
| `Net.*` | Network | `Net.Online`, `Net.Offline` |

### Naming Rules

- Always use `Layer.Component` format (two parts, dot-separated).
- Layer names are short abbreviations (3-4 chars).
- Component names are PascalCase.
- Define tags as `static const _tag` at the top of each class.

---

## Log Levels

| Level | When to Use | Example |
|-------|-------------|---------|
| `verbose` | Very detailed tracing (high volume) | Firestore snapshot metadata, widget rebuild counts |
| `debug` | Developer-useful details | Document ID, query params, cache hits/misses |
| `info` | Key business operations | "Expense created", "User signed in", "Group joined" |
| `warning` | Unexpected but recoverable | "Retry attempt 2 of 5", "Stale cache used" |
| `error` | Operation failed | "Failed to save expense" — always include stack trace |
| `fatal` | App cannot continue | "Firebase initialization failed", "Critical migration error" |

### Level Selection Guide

```text
Is it a failure?
├── Yes → Can the app recover?
│   ├── Yes → error
│   └── No  → fatal
└── No → Is it unexpected?
    ├── Yes → warning
    └── No → Is it a key business event?
        ├── Yes → info
        └── No → Is it useful for debugging?
            ├── Yes → debug
            └── No → verbose
```

---

## PII Rules (CRITICAL)

### ❌ NEVER Log

- Phone numbers
- Email addresses
- Full names / display names
- Auth tokens / refresh tokens
- Passwords
- IP addresses
- Device identifiers (IMEI, IDFA)

### ✅ SAFE to Log

- User IDs (Firebase UID)
- Document IDs (expense ID, group ID)
- Amounts in paise (non-PII financial data)
- Timestamps
- Error messages and stack traces
- Feature flags and configuration values
- Screen names and navigation events

### PII Sanitizer

Use `PiiSanitizer.sanitize()` when logging strings that **might** contain PII:

```dart
// Auto-masks phone numbers: +91****1234
// Auto-masks emails: a***@example.com
// Auto-masks tokens: eyJ***...
final safe = PiiSanitizer.sanitize(rawString);
AppLogger.debug(_tag, 'User lookup result', data: {'query': safe});
```

### Code Review Rule

Every PR must be checked: **no PII in log statements**. Use the PII audit grep:

```bash
grep -rn "AppLogger\.\|log\.\|print(" lib/ --include="*.dart" | grep -i "phone\|email\|name\|token\|password"
```

---

## Log File Configuration

### Format: JSON Lines

Each log entry is a single JSON object on one line:

```json
{"ts":"2026-03-22T10:30:45.123Z","level":"info","tag":"Repo.Expense","msg":"Adding expense","data":{"groupId":"abc123","amount":250000,"splitType":"equal"}}
```

### File Location

```text
{appDocumentsDir}/logs/app.log       # Current log file
{appDocumentsDir}/logs/app.log.1     # Previous rotation
{appDocumentsDir}/logs/app.log.2     # Oldest rotation
```

### Rotation Policy

- **Max file size:** 5 MB per file
- **Max files:** 3 (current + 2 rotated)
- **Max total:** 15 MB
- **Rotation:** LRU — when `app.log` reaches 5 MB, rotate and delete oldest

### Environment Levels

| Environment | Minimum Level | Console | File | Crashlytics |
|-------------|--------------|---------|------|-------------|
| Debug | `verbose` | ✅ | ✅ | ❌ |
| Staging | `debug` | ❌ | ✅ | ✅ (error+) |
| Production | `info` | ❌ | ✅ | ✅ (error+) |

---

## Multi-Output System

AppLogger dispatches each log entry to multiple outputs simultaneously:

### ConsoleLogOutput

- **When:** Debug builds only
- **Format:** Colored, human-readable
- **Config:** Uses `dart:developer` log() for DevTools integration

### FileLogOutput

- **When:** All environments
- **Format:** JSON Lines
- **Config:** Rotation policy as described above
- **Use:** Debugging production issues via exported logs

### CrashlyticsLogOutput

- **When:** Staging + Production
- **Levels:** `error` and `fatal` only
- **Config:** Uses `FirebaseCrashlytics.instance.recordError()`
- **Extra:** Breadcrumbs from `info`+ logs via `Crashlytics.log()`

### RingBufferLogOutput

- **When:** All environments
- **Format:** In-memory ring buffer
- **Size:** Last 500 entries
- **Use:** "Export logs" feature — user taps button, last 500 entries are formatted and shared

### Adding a New Output

```dart
class MyCustomOutput implements LogOutput {
  @override
  void write(LogEntry entry) {
    // entry.timestamp, entry.level, entry.tag, entry.message, entry.data
    // entry.error, entry.stackTrace
  }
}

// Register in app initialization
AppLogger.addOutput(MyCustomOutput());
```

---

## Common Logging Patterns

### Repository Pattern

```dart
class GroupRepository {
  static const _tag = 'Repo.Group';

  Future<Result<Group>> getGroup(String groupId) async {
    AppLogger.debug(_tag, 'Fetching group', data: {'groupId': groupId});

    try {
      final group = await _dataSource.getGroup(groupId);
      AppLogger.info(_tag, 'Group fetched', data: {
        'groupId': groupId,
        'memberCount': group.memberCount,
      });
      return Result.success(group);
    } on FirebaseException catch (e, stack) {
      AppLogger.error(_tag, 'Firestore error fetching group',
          error: e, stackTrace: stack, data: {'groupId': groupId});
      return Result.failure(DataException('Failed to load group'));
    }
  }
}
```

### Sync Operations

```dart
AppLogger.info('Sync.Queue', 'Processing sync queue', data: {
  'pendingCount': queue.length,
  'oldestEntry': queue.first.createdAt.toIso8601String(),
});

// After each item
AppLogger.debug('Sync.Queue', 'Item synced', data: {
  'itemId': item.id,
  'type': item.type.name,
  'retryCount': item.retryCount,
});

// On conflict
AppLogger.warning('Sync.Conflict', 'Write conflict detected', data: {
  'docPath': item.documentPath,
  'strategy': 'server-wins',
});
```

### Navigation

```dart
AppLogger.debug('Nav.Push', 'Navigating', data: {
  'route': '/groups/$groupId/expenses/$expenseId',
  'source': 'notification_tap',
});
```
