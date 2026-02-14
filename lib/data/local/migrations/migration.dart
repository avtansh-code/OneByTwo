import 'package:sqflite/sqflite.dart';

/// Base class for database migrations
/// 
/// Each migration represents a database schema change and must implement:
/// - version: The database version this migration brings the DB to
/// - up: Apply the migration (create tables, add columns, etc.)
/// - down: Rollback the migration (for downgrades)
abstract class Migration {
  /// The database version this migration brings the DB to
  int get version;

  /// Apply the migration
  Future<void> up(Database db);

  /// Rollback the migration (for downgrades)
  Future<void> down(Database db);
}
