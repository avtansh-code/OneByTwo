import 'package:logger/logger.dart';

import '../../models/user_model.dart';
import '../database_helper.dart';
import 'base_dao.dart';

/// Data Access Object for User operations on local sqflite database
/// 
/// Handles CRUD operations for the `users` table.
/// All operations are synchronous with the local database.
class UserDao extends BaseDao<UserModel> {
  UserDao({
    required DatabaseHelper dbHelper,
    required Logger logger,
  })  : _logger = logger,
        super(dbHelper);

  static const _tag = 'DAO.User';

  final Logger _logger;

  @override
  String get tableName => 'users';

  @override
  UserModel fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String? ?? '',
      avatarUrl: map['avatar_url'] as String?,
      language: map['language'] as String? ?? 'en',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  @override
  Map<String, dynamic> toMap(UserModel entity) {
    return {
      'id': entity.uid,
      'name': entity.name,
      'phone': entity.phone,
      'avatar_url': entity.avatarUrl,
      'language': entity.language,
      'is_current_user': 0, // Will be set separately
      'created_at': entity.createdAt.millisecondsSinceEpoch,
      'updated_at': entity.updatedAt.millisecondsSinceEpoch,
      'sync_status': 'synced', // Will be overridden by BaseDao if needed
    };
  }

  /// Insert or update user profile
  /// 
  /// Returns the number of rows affected (1 on success)
  Future<int> insertUser(UserModel user) async {
    try {
      _logger.i(
        '[$_tag] Inserting user',
        error: {'uid': user.uid},
      );
      return await insert(user);
    } catch (e, stack) {
      _logger.e('[$_tag] Error inserting user', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Get user by ID
  /// 
  /// Returns null if user not found
  Future<UserModel?> getUserById(String uid) async {
    try {
      _logger.d('[$_tag] Getting user by ID', error: {'uid': uid});
      return await getById(uid);
    } catch (e, stack) {
      _logger.e('[$_tag] Error getting user by ID', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Get user by phone number
  /// 
  /// Returns null if user not found
  Future<UserModel?> getUserByPhone(String phone) async {
    try {
      _logger.d('[$_tag] Getting user by phone');
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        tableName,
        where: 'phone = ?',
        whereArgs: [phone],
        limit: 1,
      );

      if (maps.isEmpty) {
        return null;
      }

      return fromMap(maps.first);
    } catch (e, stack) {
      _logger.e('[$_tag] Error getting user by phone', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Update user profile
  /// 
  /// Returns the number of rows affected
  Future<int> updateUser(UserModel user) async {
    try {
      _logger.i(
        '[$_tag] Updating user',
        error: {'uid': user.uid},
      );
      return await update(user, user.uid);
    } catch (e, stack) {
      _logger.e('[$_tag] Error updating user', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Delete user
  /// 
  /// Returns the number of rows affected
  Future<int> deleteUser(String uid) async {
    try {
      _logger.i('[$_tag] Deleting user', error: {'uid': uid});
      // Users table doesn't have soft delete, so this is a hard delete
      return await hardDelete(uid);
    } catch (e, stack) {
      _logger.e('[$_tag] Error deleting user', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Mark user as current user
  /// 
  /// Sets is_current_user = 1 for this user, 0 for all others
  Future<void> setCurrentUser(String uid) async {
    try {
      _logger.i('[$_tag] Setting current user', error: {'uid': uid});
      final db = await dbHelper.database;
      
      // First, unset all users
      await db.update(
        tableName,
        {'is_current_user': 0},
      );
      
      // Then set the current user
      await db.update(
        tableName,
        {'is_current_user': 1},
        where: 'id = ?',
        whereArgs: [uid],
      );
    } catch (e, stack) {
      _logger.e('[$_tag] Error setting current user', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Get current user
  /// 
  /// Returns null if no current user is set
  Future<UserModel?> getCurrentUser() async {
    try {
      _logger.d('[$_tag] Getting current user');
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        tableName,
        where: 'is_current_user = ?',
        whereArgs: [1],
        limit: 1,
      );

      if (maps.isEmpty) {
        return null;
      }

      return fromMap(maps.first);
    } catch (e, stack) {
      _logger.e('[$_tag] Error getting current user', error: e, stackTrace: stack);
      rethrow;
    }
  }
}
