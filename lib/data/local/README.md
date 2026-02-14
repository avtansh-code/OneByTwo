# Local Database Setup - Task S1-06

## Overview

This task implements the local SQLite database setup for the One By Two expense-splitting app using sqflite. The database follows an offline-first architecture where the local database is the source of truth for the UI.

## Implementation Summary

### Files Created

1. **`lib/data/local/database_helper.dart`**
   - Singleton pattern for database access
   - Database initialization and versioning
   - Migration management
   - Support for custom paths (for testing)

2. **`lib/data/local/migrations/migration.dart`**
   - Base abstract class for database migrations
   - Defines interface for `up()` and `down()` migrations

3. **`lib/data/local/migrations/migration_v1.dart`**
   - Initial database schema (version 1)
   - Creates all 15 tables needed for Sprint 1-4
   - Creates all required indexes

4. **`lib/data/local/dao/base_dao.dart`**
   - Base Data Access Object class
   - Provides common CRUD operations
   - Supports soft deletes
   - Automatic sync_status management

5. **`test/data/local/database_helper_test.dart`**
   - Comprehensive tests for database setup
   - Verifies all tables and indexes are created
   - Uses in-memory database for fast testing

## Database Schema

### Tables Created (15 total)

1. **users** - User profile data
2. **groups** - Group metadata
3. **group_members** - Group membership
4. **friends** - 1:1 friend relationships
5. **expenses** - Expense records (supports both group and friend context)
6. **expense_payers** - Who paid for each expense
7. **expense_splits** - How expenses are split per person
8. **expense_items** - Itemized bill items
9. **expense_attachments** - Receipt photos/files
10. **settlements** - Settlement records (supports both group and friend context)
11. **group_balances** - Pairwise balances in group context
12. **activity_log** - Activity/audit trail
13. **notifications** - Local notification cache
14. **sync_queue** - Offline sync queue
15. **expense_drafts** - Auto-save drafts

### Key Design Principles

1. **Money Storage**: All amounts stored as INTEGER in paise (1 ₹ = 100 paise)
2. **Sync Status**: Every syncable table has `sync_status` column ('synced', 'pending', 'conflict')
3. **Version Control**: Syncable tables have `version` field for optimistic concurrency
4. **Soft Deletes**: Expenses and settlements use `is_deleted` flag
5. **Dual Context**: Expenses and settlements support both group and friend contexts
6. **Timestamps**: All timestamps stored as INTEGER (milliseconds since epoch)
7. **Foreign Keys**: Enabled and enforced for referential integrity

### Indexes Created

21 indexes for optimizing common queries:
- Expenses: by group_id, friend_pair_id, category, created_by
- Splits: by expense_id, user_id
- Settlements: by group_id, friend_pair_id
- Group members: by group_id, user_id
- Activity log: by group_id, friend_pair_id, timestamp
- Sync queue: by status, created_at
- And more...

## Usage

### Initialize Database

```dart
final dbHelper = DatabaseHelper.instance;
final db = await dbHelper.database;
```

### Create a DAO

```dart
class UserDao extends BaseDao<User> {
  UserDao(DatabaseHelper dbHelper) : super(dbHelper);

  @override
  String get tableName => 'users';

  @override
  User fromMap(Map<String, dynamic> map) {
    return User.fromMap(map);
  }

  @override
  Map<String, dynamic> toMap(User entity) {
    return entity.toMap();
  }
}
```

### Basic CRUD Operations

```dart
final userDao = UserDao(DatabaseHelper.instance);

// Insert
await userDao.insert(user);

// Get by ID
final user = await userDao.getById('user123');

// Update
await userDao.update(updatedUser, 'user123');

// Delete (soft delete if supported)
await userDao.delete('user123');
```

## Testing

Run database tests:

```bash
flutter test test/data/local/database_helper_test.dart
```

All tests pass and verify:
- Singleton pattern works correctly
- All 15 tables are created
- Foreign key constraints are enabled
- All indexes are created
- Table schemas match specification

## Migration System

The migration system supports:
- **Versioning**: Each migration has a version number
- **Up migrations**: Apply schema changes
- **Down migrations**: Rollback schema changes
- **Future-proof**: Easy to add new migrations

To add a new migration:

1. Create `migration_v2.dart` extending `Migration`
2. Implement `version`, `up()`, and `down()`
3. Add to `DatabaseHelper._getMigrations()` list
4. Increment `_databaseVersion` constant

## Next Steps

The following will be implemented in subsequent tasks:
- SQLCipher encryption for data at rest
- Individual DAO classes for each entity
- Repository implementations
- Sync service for Firestore integration

## Dependencies

- `sqflite: ^2.4.1` - SQLite database
- `path_provider: ^2.1.5` - Database path
- `path: ^1.9.0` - Path utilities
- `sqflite_common_ffi: ^2.3.3` (dev) - For testing

## Notes

- Currently using plain sqflite (no encryption)
- SQLCipher integration will be added later once confirmed working
- Database helper includes test support via custom path setter
- All sync_status fields default to 'pending' for new records
- Foreign key constraints are enforced
