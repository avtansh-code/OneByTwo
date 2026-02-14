---
name: logging
description: Guide for implementing and using the logging system in the One By Two app. Use this when adding log statements, implementing logging infrastructure, configuring log outputs, or ensuring PII compliance in logs.
---

## Logging Architecture

The app uses a centralized `AppLogger` singleton that dispatches to multiple outputs (console, file, Crashlytics, ring buffer). See `docs/architecture/07_LOW_LEVEL_DESIGN.md` (Section 7) for full details.

## How to Log

```dart
import 'package:one_by_two/core/logging/app_logger.dart';

class ExpenseRepository {
  static const _tag = 'Repo.Expense';

  Future<Result<Expense>> addExpense(Expense expense) async {
    AppLogger.instance.info(_tag, 'Creating expense', {
      'expenseId': expense.id,
      'groupId': expense.groupId,
      'amountPaise': expense.amountPaise,
      'splitType': expense.splitType.name,
    });

    try {
      await _dao.insert(expense);
      AppLogger.instance.debug(_tag, 'Saved to local DB', {
        'expenseId': expense.id,
      });

      await _syncQueue.enqueue(expense);
      AppLogger.instance.debug(_tag, 'Enqueued for sync', {
        'expenseId': expense.id,
      });

      return Result.success(expense);
    } catch (e, stack) {
      AppLogger.instance.error(_tag, 'Failed to create expense',
        e, stack, {'expenseId': expense.id});
      return Result.failure(StorageException(e.toString()));
    }
  }
}
```

## Tag Naming Convention

Use layer-prefixed tags: `{Layer}.{Component}`

| Layer | Prefix | Examples |
|-------|--------|----------|
| Bootstrap | `Boot` | `Boot.Init`, `Boot.Migration` |
| Auth | `Auth` | `Auth.Login`, `Auth.Token` |
| Use Cases | `UC` | `UC.AddExpense`, `UC.Settle` |
| Repositories | `Repo` | `Repo.Expense`, `Repo.Group` |
| DAOs | `DAO` | `DAO.Expense`, `DAO.SyncQueue` |
| Firestore | `FS` | `FS.Expense`, `FS.Listener` |
| Sync Engine | `Sync` | `Sync.Queue`, `Sync.Conflict` |
| Network | `Net` | `Net.Status`, `Net.CF` |
| FCM | `FCM` | `FCM.Token`, `FCM.Message` |
| UI/Providers | `UI` | `UI.ExpenseList`, `UI.Navigate` |
| File Storage | `Storage` | `Storage.Upload`, `Storage.Cache` |
| Logger itself | `Logger` | `Logger.Rotate`, `Logger.Export` |

Define the tag as a `static const _tag` at the top of each class.

## What to Log at Each Level

| Level | When | Example |
|-------|------|---------|
| `verbose` | Ultra-detailed trace (SQL, provider rebuilds) | `DAO.Expense: SELECT * FROM expenses WHERE group_id = ?` |
| `debug` | Developer context (state changes, cache hits) | `Sync.Queue: processing item expense:e123, attempt 1` |
| `info` | Key business events | `UC.AddExpense: expense created, id=e123, group=g1, amount=5000` |
| `warning` | Recoverable issues | `Sync.Queue: retry 3/5 for expense:e123, error=timeout` |
| `error` | Failures | `Repo.Expense: Firestore write failed, groupId=g1, error=permission-denied` |
| `fatal` | Unrecoverable | `Boot.Init: database corruption detected` |

## What to Include in Log Data

**Always include:**
- Entity IDs (`expenseId`, `groupId`, `userId`)
- Operation type (`create`, `update`, `delete`)
- Duration for async operations (`durationMs`)
- Retry count for retryable operations
- Error type and message for failures

**Never include (PII):**
- Phone numbers
- Email addresses
- User names (use userId instead)
- OTP codes
- Auth tokens
- Any user-entered text content (expense descriptions, notes)

## Log File Rotation

- **Max file size:** 5 MB per file
- **Max files:** 3 (app.log + app.1.log + app.2.log)
- **Max total disk:** 15 MB
- **Format:** JSON Lines (one JSON object per line)
- **Location:** `{appDocumentsDir}/logs/`
- **Rotation:** On write, if current file > 5MB → rotate

## Environment Configuration

| Environment | Console Level | File Level | Crashlytics |
|-------------|---------------|------------|-------------|
| Dev | `verbose` | `debug` | Off |
| Staging | `debug` | `debug` | On (warning+) |
| Production | Off | `info` | On (warning+) |

## Implementing a New LogOutput

```dart
class MyCustomOutput implements LogOutput {
  @override
  void write(LogEntry entry) {
    // Process the entry
  }

  @override
  Future<void> dispose() async {
    // Clean up resources
  }
}
```

Register in `AppLogger` initialization:

```dart
AppLogger.init(
  minLevel: LogLevel.debug,
  outputs: [
    ConsoleOutput(),
    FileOutput(rotator: LogFileRotator(...)),
    CrashlyticsOutput(),
    MyCustomOutput(),
  ],
);
```

## Testing Logging

```dart
test('expense creation logs info event', () {
  final testOutput = TestLogOutput(); // Captures log entries in a list
  AppLogger.initForTest(outputs: [testOutput]);

  final repo = ExpenseRepository(dao: mockDao, syncQueue: mockQueue);
  await repo.addExpense(testExpense);

  expect(testOutput.entries, contains(
    isA<LogEntry>()
      .having((e) => e.level, 'level', LogLevel.info)
      .having((e) => e.tag, 'tag', 'Repo.Expense')
      .having((e) => e.message, 'message', contains('Creating expense')),
  ));
});

test('PII sanitizer redacts phone numbers', () {
  final sanitizer = PiiSanitizer();
  expect(sanitizer.sanitize('User 9876543210 logged in'),
    'User ***PHONE*** logged in');
});
```

## Cloud Functions Logging

```typescript
import { logger } from 'firebase-functions/v2';

// Use structured logging (maps to Google Cloud Logging)
logger.info('Balance recalculated', {
  groupId: 'g123',
  memberCount: 5,
  durationMs: 340,
});

logger.error('Notification send failed', {
  userId: 'u456',  // ID only, never name/phone
  error: err.message,
});
```

## Reference

- Architecture: `docs/architecture/01_ARCHITECTURE_OVERVIEW.md` (Section 4.2)
- LLD: `docs/architecture/07_LOW_LEVEL_DESIGN.md` (Section 7)
- Class diagrams: `docs/architecture/03_CLASS_DIAGRAMS.md` (core/logging/)
