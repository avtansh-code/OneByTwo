import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'migrations/migration.dart';
import 'migrations/migration_v1.dart';

/// DatabaseHelper - Singleton pattern for database access
/// 
/// Manages the local sqflite database with:
/// - Database initialization and versioning
/// - Migration management
/// - Thread-safe access
class DatabaseHelper {
  /// Get singleton instance
  factory DatabaseHelper() {
    _instance ??= DatabaseHelper._();
    return _instance!;
  }

  // Private constructor
  DatabaseHelper._();

  static const String _databaseName = 'one_by_two.db';
  static const int _databaseVersion = 1;

  // Singleton instance
  static DatabaseHelper? _instance;
  
  // Database instance
  Database? _database;

  // Custom database path for testing
  String? _customPath;

  /// Get custom database path (for testing)
  @visibleForTesting
  String? get customPath => _customPath;

  /// Set custom database path (for testing)
  @visibleForTesting
  set customPath(String path) {
    _customPath = path;
  }

  /// Get database instance, initializing if needed
  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize database
  Future<Database> _initDatabase() async {
    // Get the database path
    final String path;
    if (_customPath != null) {
      // Use custom path for testing
      path = _customPath!;
    } else {
      // Use default app documents directory
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      path = join(appDocDir.path, _databaseName);
    }

    // Open database with migrations
    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onDowngrade: _onDowngrade,
      onConfigure: _onConfigure,
    );
  }

  /// Configure database settings
  Future<void> _onConfigure(Database db) async {
    // Enable foreign key constraints
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Create database schema for initial version
  Future<void> _onCreate(Database db, int version) async {
    // Get all migrations up to current version
    final migrations = _getMigrations();
    
    // Run all migrations in order
    for (final migration in migrations) {
      if (migration.version <= version) {
        await migration.up(db);
      }
    }
  }

  /// Upgrade database schema
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    final migrations = _getMigrations();
    
    // Run migrations from oldVersion + 1 to newVersion
    for (final migration in migrations) {
      if (migration.version > oldVersion && migration.version <= newVersion) {
        await migration.up(db);
      }
    }
  }

  /// Downgrade database schema
  Future<void> _onDowngrade(Database db, int oldVersion, int newVersion) async {
    final migrations = _getMigrations();
    
    // Run down migrations from oldVersion to newVersion + 1
    for (int i = migrations.length - 1; i >= 0; i--) {
      final migration = migrations[i];
      if (migration.version <= oldVersion && migration.version > newVersion) {
        await migration.down(db);
      }
    }
  }

  /// Get list of all migrations
  List<Migration> _getMigrations() {
    return [
      MigrationV1(),
      // Future migrations will be added here:
      // MigrationV2(),
      // MigrationV3(),
    ];
  }

  /// Close database connection
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// Delete database (for testing only)
  Future<void> deleteDatabase() async {
    final String path;
    if (_customPath != null) {
      path = _customPath!;
    } else {
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      path = join(appDocDir.path, _databaseName);
    }
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }

  /// Reset database (drop all tables and recreate)
  Future<void> resetDatabase() async {
    await close();
    await deleteDatabase();
    _database = await _initDatabase();
  }

  /// Reset singleton instance (for testing only)
  @visibleForTesting
  static void resetInstance() {
    _instance = null;
  }
}
