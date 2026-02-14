import 'package:flutter_test/flutter_test.dart';
import 'package:one_by_two/data/local/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    // Initialize FFI for testing
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DatabaseHelper', () {
    late DatabaseHelper dbHelper;

    setUp(() {
      // Reset singleton and use in-memory database for each test
      DatabaseHelper.resetInstance();
      dbHelper = DatabaseHelper()
        ..customPath = inMemoryDatabasePath;
    });

    tearDown(() async {
      // Clean up after each test
      await dbHelper.close();
      DatabaseHelper.resetInstance();
    });

    test('creates singleton instance', () {
      final instance1 = DatabaseHelper();
      final instance2 = DatabaseHelper();
      expect(identical(instance1, instance2), true);
    });

    test('initializes database with all tables', () async {
      final db = await dbHelper.database;

      // Check that database was created
      expect(db, isNotNull);
      expect(db.isOpen, true);

      // Verify all tables exist by querying sqlite_master
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
      );

      final tableNames = tables.map((t) => t['name']! as String).toList();

      // Expected tables from Migration V1
      final expectedTables = [
        'activity_log',
        'expense_attachments',
        'expense_drafts',
        'expense_items',
        'expense_payers',
        'expense_splits',
        'expenses',
        'friends',
        'group_balances',
        'group_members',
        'groups',
        'notifications',
        'settlements',
        'sync_queue',
        'users',
      ];

      for (final expectedTable in expectedTables) {
        expect(
          tableNames,
          contains(expectedTable),
          reason: 'Table $expectedTable should exist',
        );
      }
    });

    test('verifies foreign key constraints are enabled', () async {
      final db = await dbHelper.database;

      final result = await db.rawQuery('PRAGMA foreign_keys');
      expect(result.first['foreign_keys'], 1);
    });

    test('verifies indexes are created', () async {
      final db = await dbHelper.database;

      // Check that indexes exist
      final indexes = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND name LIKE 'idx_%' ORDER BY name",
      );

      final indexNames = indexes.map((i) => i['name']! as String).toList();

      // Sample of expected indexes
      final expectedIndexes = [
        'idx_expenses_group',
        'idx_expenses_friend',
        'idx_expense_payers_expense',
        'idx_expense_splits_expense',
        'idx_settlements_group',
        'idx_group_members_group',
        'idx_sync_queue_status',
      ];

      for (final expectedIndex in expectedIndexes) {
        expect(
          indexNames,
          contains(expectedIndex),
          reason: 'Index $expectedIndex should exist',
        );
      }
    });

    test('verifies expenses table schema', () async {
      final db = await dbHelper.database;

      final columns = await db.rawQuery('PRAGMA table_info(expenses)');
      final columnNames = columns.map((c) => c['name']! as String).toList();

      // Key columns for expenses
      expect(columnNames, contains('id'));
      expect(columnNames, contains('group_id'));
      expect(columnNames, contains('friend_pair_id'));
      expect(columnNames, contains('context_type'));
      expect(columnNames, contains('description'));
      expect(columnNames, contains('amount'));
      expect(columnNames, contains('date'));
      expect(columnNames, contains('category'));
      expect(columnNames, contains('split_type'));
      expect(columnNames, contains('is_deleted'));
      expect(columnNames, contains('version'));
      expect(columnNames, contains('sync_status'));
      expect(columnNames, contains('created_at'));
      expect(columnNames, contains('updated_at'));
    });

    test('verifies settlements table schema', () async {
      final db = await dbHelper.database;

      final columns = await db.rawQuery('PRAGMA table_info(settlements)');
      final columnNames = columns.map((c) => c['name']! as String).toList();

      // Key columns for settlements
      expect(columnNames, contains('id'));
      expect(columnNames, contains('group_id'));
      expect(columnNames, contains('friend_pair_id'));
      expect(columnNames, contains('context_type'));
      expect(columnNames, contains('from_user_id'));
      expect(columnNames, contains('to_user_id'));
      expect(columnNames, contains('amount'));
      expect(columnNames, contains('date'));
      expect(columnNames, contains('is_deleted'));
      expect(columnNames, contains('version'));
      expect(columnNames, contains('sync_status'));
    });
  });
}
