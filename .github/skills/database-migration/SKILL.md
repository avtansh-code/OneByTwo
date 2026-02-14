---
name: database-migration
description: Guide for managing sqflite database schema migrations in the One By Two app. Use this when adding tables, columns, indexes, or modifying the local database schema.
---

## Migration System Overview

The app uses sqflite with an integer version-based migration system. Each schema change increments the DB version and adds a migration function.

See `docs/architecture/07_LOW_LEVEL_DESIGN.md` (Section 1: Database Migration Manager) for full details.

## Migration File Structure

```
lib/data/local/
├── database_helper.dart       # Opens DB, runs migrations
├── migrations/
│   ├── migration_registry.dart # Maps version → migration function
│   ├── v1_initial.dart         # Initial schema (all tables)
│   ├── v2_add_tags.dart        # Example: add tags table
│   └── v3_add_export.dart      # Example: add export history
└── dao/
    ├── expense_dao.dart
    ├── group_dao.dart
    └── ...
```

## Writing a New Migration

### Step 1: Create migration file

```dart
// lib/data/local/migrations/v2_add_tags.dart

import 'package:sqflite/sqflite.dart';

Future<void> migrateV2(Database db) async {
  await db.execute('''
    CREATE TABLE tags (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      color INTEGER,
      created_at TEXT NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE expense_tags (
      expense_id TEXT NOT NULL,
      tag_id TEXT NOT NULL,
      PRIMARY KEY (expense_id, tag_id),
      FOREIGN KEY (expense_id) REFERENCES expenses(id),
      FOREIGN KEY (tag_id) REFERENCES tags(id)
    )
  ''');

  await db.execute('CREATE INDEX idx_expense_tags_expense ON expense_tags(expense_id)');
}
```

### Step 2: Register in migration registry

```dart
// lib/data/local/migrations/migration_registry.dart

import 'v1_initial.dart';
import 'v2_add_tags.dart';

final migrations = <int, Future<void> Function(Database)>{
  1: migrateV1,
  2: migrateV2,
};

const currentDbVersion = 2;
```

### Step 3: Update database_helper.dart

```dart
await openDatabase(
  path,
  version: currentDbVersion,
  onCreate: (db, version) async {
    // Run all migrations sequentially for fresh install
    for (var v = 1; v <= version; v++) {
      await migrations[v]!(db);
    }
  },
  onUpgrade: (db, oldVersion, newVersion) async {
    // Run only the needed migrations for existing users
    for (var v = oldVersion + 1; v <= newVersion; v++) {
      await migrations[v]!(db);
    }
  },
);
```

## Migration Rules

1. **Never modify existing migrations** — they've already run on user devices
2. **Always add new migrations** — even for small changes (add column, add index)
3. **SQLite limitations:**
   - Cannot `DROP COLUMN` (before SQLite 3.35.0 / Android API 34)
   - Cannot `ALTER COLUMN` type
   - Cannot add `NOT NULL` column without a default
   - Workaround: Create new table → copy data → drop old → rename
4. **Every migration must be idempotent** — wrap DDL in try-catch or use `IF NOT EXISTS`
5. **Test migrations** both:
   - Fresh install (runs all migrations 1→N)
   - Upgrade path (each V→V+1 individually)
6. **Never delete data** in a migration without user consent
7. **Add indexes** for any column used in WHERE, ORDER BY, or JOIN

## Common Migration Patterns

### Add a column with default
```dart
await db.execute("ALTER TABLE expenses ADD COLUMN tag TEXT DEFAULT ''");
```

### Add an index
```dart
await db.execute('CREATE INDEX IF NOT EXISTS idx_expenses_category ON expenses(category)');
```

### Rename table (SQLite workaround)
```dart
await db.execute('ALTER TABLE old_name RENAME TO new_name');
```

### Add NOT NULL column to existing table
```dart
// Step 1: Add nullable column
await db.execute('ALTER TABLE expenses ADD COLUMN priority INTEGER');
// Step 2: Backfill with default
await db.execute('UPDATE expenses SET priority = 0 WHERE priority IS NULL');
```

## Testing Migrations

```dart
test('migration v1 to v2 preserves existing data', () async {
  // 1. Create v1 database with test data
  final db = await openDatabase(inMemoryDatabasePath, version: 1,
    onCreate: (db, v) => migrateV1(db));
  await db.insert('expenses', testExpense);

  // 2. Close and reopen with v2
  await db.close();
  final db2 = await openDatabase(inMemoryDatabasePath, version: 2,
    onUpgrade: (db, old, new_) => migrateV2(db));

  // 3. Verify old data preserved
  final expenses = await db2.query('expenses');
  expect(expenses.length, 1);

  // 4. Verify new table exists
  final tags = await db2.query('tags');
  expect(tags, isEmpty); // new table, no data yet

  await db2.close();
});
```

## Reference

- Database schema: `docs/architecture/02_DATABASE_SCHEMA.md`
- LLD (migration manager): `docs/architecture/07_LOW_LEVEL_DESIGN.md`
