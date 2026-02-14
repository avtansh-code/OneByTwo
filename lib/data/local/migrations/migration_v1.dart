import 'package:sqflite/sqflite.dart';
import 'migration.dart';

/// Migration V1 - Initial database schema
/// 
/// Creates all tables needed for Sprint 1-4:
/// - users: User profile data
/// - groups: Group metadata
/// - group_members: Group membership
/// - expenses: Expense records (group + friend context)
/// - expense_payers: Who paid
/// - expense_splits: How it's split per person
/// - expense_items: Itemized bill items
/// - expense_attachments: Receipt photos/files
/// - settlements: Settlement records (group + friend context)
/// - group_balances: Pairwise balances in group context
/// - friends: 1:1 friend relationships
/// - activity_log: Activity/audit trail
/// - sync_queue: Offline sync queue
/// - notifications: Local notification cache
/// - expense_drafts: Auto-save drafts
class MigrationV1 extends Migration {
  @override
  int get version => 1;

  @override
  Future<void> up(Database db) async {
    await _createUsersTable(db);
    await _createGroupsTable(db);
    await _createGroupMembersTable(db);
    await _createFriendsTable(db);
    await _createExpensesTable(db);
    await _createExpensePayersTable(db);
    await _createExpenseSplitsTable(db);
    await _createExpenseItemsTable(db);
    await _createExpenseAttachmentsTable(db);
    await _createSettlementsTable(db);
    await _createGroupBalancesTable(db);
    await _createActivityLogTable(db);
    await _createNotificationsTable(db);
    await _createSyncQueueTable(db);
    await _createExpenseDraftsTable(db);
    await _createIndexes(db);
  }

  @override
  Future<void> down(Database db) async {
    // Drop all tables in reverse order (respecting foreign keys)
    await db.execute('DROP TABLE IF EXISTS expense_drafts');
    await db.execute('DROP TABLE IF EXISTS sync_queue');
    await db.execute('DROP TABLE IF EXISTS notifications');
    await db.execute('DROP TABLE IF EXISTS activity_log');
    await db.execute('DROP TABLE IF EXISTS group_balances');
    await db.execute('DROP TABLE IF EXISTS settlements');
    await db.execute('DROP TABLE IF EXISTS expense_attachments');
    await db.execute('DROP TABLE IF EXISTS expense_items');
    await db.execute('DROP TABLE IF EXISTS expense_splits');
    await db.execute('DROP TABLE IF EXISTS expense_payers');
    await db.execute('DROP TABLE IF EXISTS expenses');
    await db.execute('DROP TABLE IF EXISTS friends');
    await db.execute('DROP TABLE IF EXISTS group_members');
    await db.execute('DROP TABLE IF EXISTS groups');
    await db.execute('DROP TABLE IF EXISTS users');
  }

  // ========== TABLE CREATION ==========

  Future<void> _createUsersTable(Database db) async {
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        avatar_url TEXT,
        language TEXT NOT NULL DEFAULT 'en',
        is_current_user INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'synced'
      )
    ''');
  }

  Future<void> _createGroupsTable(Database db) async {
    await db.execute('''
      CREATE TABLE groups (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'other',
        cover_photo_url TEXT,
        created_by TEXT NOT NULL,
        is_archived INTEGER NOT NULL DEFAULT 0,
        default_split_type TEXT NOT NULL DEFAULT 'equal',
        member_count INTEGER NOT NULL DEFAULT 0,
        is_pinned INTEGER NOT NULL DEFAULT 0,
        my_balance INTEGER NOT NULL DEFAULT 0,
        last_activity_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        FOREIGN KEY (created_by) REFERENCES users(id)
      )
    ''');
  }

  Future<void> _createGroupMembersTable(Database db) async {
    await db.execute('''
      CREATE TABLE group_members (
        id TEXT PRIMARY KEY,
        group_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'member',
        is_guest INTEGER NOT NULL DEFAULT 0,
        guest_name TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        joined_at INTEGER NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        FOREIGN KEY (group_id) REFERENCES groups(id),
        FOREIGN KEY (user_id) REFERENCES users(id),
        UNIQUE (group_id, user_id)
      )
    ''');
  }

  Future<void> _createFriendsTable(Database db) async {
    await db.execute('''
      CREATE TABLE friends (
        id TEXT PRIMARY KEY,
        user_a_id TEXT NOT NULL,
        user_b_id TEXT NOT NULL,
        balance INTEGER NOT NULL DEFAULT 0,
        last_activity_at INTEGER,
        created_at INTEGER NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        FOREIGN KEY (user_a_id) REFERENCES users(id),
        FOREIGN KEY (user_b_id) REFERENCES users(id),
        UNIQUE (user_a_id, user_b_id)
      )
    ''');
  }

  Future<void> _createExpensesTable(Database db) async {
    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        friend_pair_id TEXT,
        context_type TEXT NOT NULL DEFAULT 'group',
        description TEXT NOT NULL,
        amount INTEGER NOT NULL,
        date INTEGER NOT NULL,
        category TEXT NOT NULL DEFAULT 'other',
        split_type TEXT NOT NULL DEFAULT 'equal',
        notes TEXT,
        created_by TEXT NOT NULL,
        updated_by TEXT,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        deleted_by TEXT,
        is_recurring INTEGER NOT NULL DEFAULT 0,
        recurring_frequency TEXT,
        recurring_interval INTEGER,
        recurring_next_date INTEGER,
        recurring_end_date INTEGER,
        version INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        FOREIGN KEY (group_id) REFERENCES groups(id),
        FOREIGN KEY (friend_pair_id) REFERENCES friends(id),
        FOREIGN KEY (created_by) REFERENCES users(id),
        CHECK (
          (context_type = 'group' AND group_id IS NOT NULL AND friend_pair_id IS NULL) OR
          (context_type = 'friend' AND friend_pair_id IS NOT NULL AND group_id IS NULL)
        )
      )
    ''');
  }

  Future<void> _createExpensePayersTable(Database db) async {
    await db.execute('''
      CREATE TABLE expense_payers (
        id TEXT PRIMARY KEY,
        expense_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        amount_paid INTEGER NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        FOREIGN KEY (expense_id) REFERENCES expenses(id),
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');
  }

  Future<void> _createExpenseSplitsTable(Database db) async {
    await db.execute('''
      CREATE TABLE expense_splits (
        id TEXT PRIMARY KEY,
        expense_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        amount_owed INTEGER NOT NULL,
        percentage REAL,
        shares REAL,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        FOREIGN KEY (expense_id) REFERENCES expenses(id),
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');
  }

  Future<void> _createExpenseItemsTable(Database db) async {
    await db.execute('''
      CREATE TABLE expense_items (
        id TEXT PRIMARY KEY,
        expense_id TEXT NOT NULL,
        name TEXT NOT NULL,
        amount INTEGER NOT NULL,
        assigned_to TEXT NOT NULL,
        split_equally INTEGER NOT NULL DEFAULT 1,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        FOREIGN KEY (expense_id) REFERENCES expenses(id)
      )
    ''');
  }

  Future<void> _createExpenseAttachmentsTable(Database db) async {
    await db.execute('''
      CREATE TABLE expense_attachments (
        id TEXT PRIMARY KEY,
        expense_id TEXT NOT NULL,
        url TEXT,
        local_path TEXT,
        file_name TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        uploaded_by TEXT NOT NULL,
        uploaded_at INTEGER NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        FOREIGN KEY (expense_id) REFERENCES expenses(id)
      )
    ''');
  }

  Future<void> _createSettlementsTable(Database db) async {
    await db.execute('''
      CREATE TABLE settlements (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        friend_pair_id TEXT,
        context_type TEXT NOT NULL DEFAULT 'group',
        from_user_id TEXT NOT NULL,
        to_user_id TEXT NOT NULL,
        amount INTEGER NOT NULL,
        date INTEGER NOT NULL,
        notes TEXT,
        created_by TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        version INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        FOREIGN KEY (group_id) REFERENCES groups(id),
        FOREIGN KEY (friend_pair_id) REFERENCES friends(id),
        FOREIGN KEY (from_user_id) REFERENCES users(id),
        FOREIGN KEY (to_user_id) REFERENCES users(id),
        CHECK (
          (context_type = 'group' AND group_id IS NOT NULL AND friend_pair_id IS NULL) OR
          (context_type = 'friend' AND friend_pair_id IS NOT NULL AND group_id IS NULL)
        )
      )
    ''');
  }

  Future<void> _createGroupBalancesTable(Database db) async {
    await db.execute('''
      CREATE TABLE group_balances (
        id TEXT PRIMARY KEY,
        group_id TEXT NOT NULL,
        user_a_id TEXT NOT NULL,
        user_b_id TEXT NOT NULL,
        amount INTEGER NOT NULL DEFAULT 0,
        last_updated INTEGER NOT NULL,
        FOREIGN KEY (group_id) REFERENCES groups(id),
        UNIQUE (group_id, user_a_id, user_b_id)
      )
    ''');
  }

  Future<void> _createActivityLogTable(Database db) async {
    await db.execute('''
      CREATE TABLE activity_log (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        friend_pair_id TEXT,
        context_type TEXT NOT NULL DEFAULT 'group',
        user_id TEXT NOT NULL,
        action TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        details_json TEXT,
        timestamp INTEGER NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        FOREIGN KEY (group_id) REFERENCES groups(id),
        FOREIGN KEY (friend_pair_id) REFERENCES friends(id)
      )
    ''');
  }

  Future<void> _createNotificationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE notifications (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        group_id TEXT,
        friend_pair_id TEXT,
        entity_id TEXT,
        is_read INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'synced'
      )
    ''');
  }

  Future<void> _createSyncQueueTable(Database db) async {
    await db.execute('''
      CREATE TABLE sync_queue (
        id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        context_type TEXT NOT NULL DEFAULT 'group',
        context_id TEXT,
        retry_count INTEGER NOT NULL DEFAULT 0,
        max_retries INTEGER NOT NULL DEFAULT 5,
        status TEXT NOT NULL DEFAULT 'pending',
        error_message TEXT,
        created_at INTEGER NOT NULL,
        last_attempted_at INTEGER
      )
    ''');
  }

  Future<void> _createExpenseDraftsTable(Database db) async {
    await db.execute('''
      CREATE TABLE expense_drafts (
        id TEXT PRIMARY KEY,
        group_id TEXT,
        friend_pair_id TEXT,
        context_type TEXT NOT NULL DEFAULT 'group',
        data_json TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  // ========== INDEXES ==========

  Future<void> _createIndexes(Database db) async {
    // Expenses indexes
    await db.execute(
      'CREATE INDEX idx_expenses_group ON expenses(group_id, is_deleted, date)',
    );
    await db.execute(
      'CREATE INDEX idx_expenses_friend ON expenses(friend_pair_id, is_deleted, date)',
    );
    await db.execute(
      'CREATE INDEX idx_expenses_context ON expenses(context_type, is_deleted, date)',
    );
    await db.execute(
      'CREATE INDEX idx_expenses_category ON expenses(group_id, category, date)',
    );
    await db.execute(
      'CREATE INDEX idx_expenses_friend_category ON expenses(friend_pair_id, category, date)',
    );
    await db.execute(
      'CREATE INDEX idx_expenses_created_by ON expenses(created_by, date)',
    );

    // Expense payers indexes
    await db.execute(
      'CREATE INDEX idx_expense_payers_expense ON expense_payers(expense_id)',
    );

    // Expense splits indexes
    await db.execute(
      'CREATE INDEX idx_expense_splits_expense ON expense_splits(expense_id)',
    );
    await db.execute(
      'CREATE INDEX idx_expense_splits_user ON expense_splits(user_id)',
    );

    // Expense items indexes
    await db.execute(
      'CREATE INDEX idx_expense_items_expense ON expense_items(expense_id)',
    );

    // Settlements indexes
    await db.execute(
      'CREATE INDEX idx_settlements_group ON settlements(group_id, is_deleted)',
    );
    await db.execute(
      'CREATE INDEX idx_settlements_friend ON settlements(friend_pair_id, is_deleted)',
    );

    // Group members indexes
    await db.execute(
      'CREATE INDEX idx_group_members_group ON group_members(group_id, is_active)',
    );
    await db.execute(
      'CREATE INDEX idx_group_members_user ON group_members(user_id, is_active)',
    );

    // Activity log indexes
    await db.execute(
      'CREATE INDEX idx_activity_group ON activity_log(group_id, timestamp)',
    );
    await db.execute(
      'CREATE INDEX idx_activity_friend ON activity_log(friend_pair_id, timestamp)',
    );

    // Notifications indexes
    await db.execute(
      'CREATE INDEX idx_notifications_read ON notifications(is_read, created_at)',
    );

    // Sync queue indexes
    await db.execute(
      'CREATE INDEX idx_sync_queue_status ON sync_queue(status, created_at)',
    );

    // Group balances indexes
    await db.execute(
      'CREATE INDEX idx_group_balances_group ON group_balances(group_id)',
    );

    // Friends indexes
    await db.execute(
      'CREATE INDEX idx_friends_user_a ON friends(user_a_id)',
    );
    await db.execute(
      'CREATE INDEX idx_friends_user_b ON friends(user_b_id)',
    );
  }
}
