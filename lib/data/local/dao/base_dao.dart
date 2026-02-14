import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';

/// Base Data Access Object (DAO) class
/// 
/// Provides common CRUD operations for all entities.
/// Subclasses must implement:
/// - tableName: The name of the table
/// - fromMap: Convert a Map to entity
/// - toMap: Convert entity to Map
/// 
/// All DAOs follow these patterns:
/// - Use parameterized queries to prevent SQL injection
/// - Return null for missing entities
/// - Use soft delete where applicable (is_deleted = 1)
/// - Update sync_status to 'pending' on mutations
abstract class BaseDao<T> {
  BaseDao(this.dbHelper);

  final DatabaseHelper dbHelper;

  /// The name of the table this DAO manages
  String get tableName;

  /// Convert a database map to entity
  T fromMap(Map<String, dynamic> map);

  /// Convert entity to database map
  Map<String, dynamic> toMap(T entity);

  /// Insert a new entity
  /// Returns the number of rows affected (1 on success)
  Future<int> insert(T entity) async {
    final db = await dbHelper.database;
    final map = toMap(entity);
    
    // Ensure sync_status is set to pending for new entities
    if (!map.containsKey('sync_status')) {
      map['sync_status'] = 'pending';
    }
    
    return db.insert(
      tableName,
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Insert multiple entities in a batch
  /// Returns the number of entities inserted
  Future<int> insertBatch(List<T> entities) async {
    if (entities.isEmpty) {
      return 0;
    }
    
    final db = await dbHelper.database;
    final batch = db.batch();
    
    for (final entity in entities) {
      final map = toMap(entity);
      if (!map.containsKey('sync_status')) {
        map['sync_status'] = 'pending';
      }
      batch.insert(
        tableName,
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    final results = await batch.commit(noResult: false);
    return results.length;
  }

  /// Get entity by ID
  /// Returns null if not found
  Future<T?> getById(String id) async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return fromMap(maps.first);
  }

  /// Get all entities
  Future<List<T>> getAll() async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(tableName);
    return maps.map(fromMap).toList();
  }

  /// Update an entity
  /// Returns the number of rows affected
  Future<int> update(T entity, String id) async {
    final db = await dbHelper.database;
    final map = toMap(entity);
    
    // Mark as pending for sync
    map['sync_status'] = 'pending';
    map['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    
    return db.update(
      tableName,
      map,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Update multiple entities in a batch
  Future<int> updateBatch(List<T> entities, List<String> ids) async {
    if (entities.isEmpty || entities.length != ids.length) {
      return 0;
    }
    
    final db = await dbHelper.database;
    final batch = db.batch();
    
    for (int i = 0; i < entities.length; i++) {
      final map = toMap(entities[i]);
      map['sync_status'] = 'pending';
      map['updated_at'] = DateTime.now().millisecondsSinceEpoch;
      
      batch.update(
        tableName,
        map,
        where: 'id = ?',
        whereArgs: [ids[i]],
      );
    }
    
    final results = await batch.commit(noResult: false);
    return results.length;
  }

  /// Delete an entity (soft delete if table supports it)
  /// Returns the number of rows affected
  Future<int> delete(String id) async {
    final db = await dbHelper.database;
    
    // Check if table has is_deleted column (soft delete support)
    if (await _hasColumn(db, tableName, 'is_deleted')) {
      // Soft delete
      return db.update(
        tableName,
        {
          'is_deleted': 1,
          'deleted_at': DateTime.now().millisecondsSinceEpoch,
          'sync_status': 'pending',
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      // Hard delete for tables without soft delete support
      return db.delete(
        tableName,
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  /// Hard delete (permanently remove from database)
  /// Use with caution - this cannot be undone
  Future<int> hardDelete(String id) async {
    final db = await dbHelper.database;
    return db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete multiple entities
  Future<int> deleteBatch(List<String> ids) async {
    if (ids.isEmpty) {
      return 0;
    }
    
    final db = await dbHelper.database;
    final batch = db.batch();
    
    final hasSoftDelete = await _hasColumn(db, tableName, 'is_deleted');
    
    for (final id in ids) {
      if (hasSoftDelete) {
        batch.update(
          tableName,
          {
            'is_deleted': 1,
            'deleted_at': DateTime.now().millisecondsSinceEpoch,
            'sync_status': 'pending',
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      } else {
        batch.delete(
          tableName,
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }
    
    final results = await batch.commit(noResult: false);
    return results.length;
  }

  /// Execute a raw query and return results as entities
  Future<List<T>> rawQuery(String sql, [List<Object?>? arguments]) async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(sql, arguments);
    return maps.map(fromMap).toList();
  }

  /// Execute a raw query and return single entity or null
  Future<T?> rawQuerySingle(String sql, [List<Object?>? arguments]) async {
    final results = await rawQuery(sql, arguments);
    if (results.isEmpty) {
      return null;
    }
    return results.first;
  }

  /// Count rows in table
  Future<int> count([String? where, List<Object?>? whereArgs]) async {
    final db = await dbHelper.database;
    final result = await db.query(
      tableName,
      columns: ['COUNT(*) as count'],
      where: where,
      whereArgs: whereArgs,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Check if a column exists in the table
  Future<bool> _hasColumn(Database db, String table, String column) async {
    final result = await db.rawQuery('PRAGMA table_info($table)');
    return result.any((row) => row['name'] == column);
  }

  /// Delete all rows from table (for testing)
  Future<int> deleteAll() async {
    final db = await dbHelper.database;
    return db.delete(tableName);
  }
}
