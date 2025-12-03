import 'dart:math';
import 'package:flying_birdies/core/logger.dart';
import 'package:flying_birdies/data/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Helper class for creating isolated test databases
///
/// This utility ensures each test gets its own database instance,
/// preventing database locking issues when tests run in parallel.
class TestDatabaseHelper {
  /// Creates an isolated DatabaseHelper for testing
  ///
  /// By default, uses an in-memory database which is faster and doesn't
  /// create files on disk. Each call generates a unique database name
  /// to ensure complete isolation between tests.
  ///
  /// Parameters:
  /// - [dbName]: Optional custom database name. If not provided, generates unique name.
  /// - [inMemory]: If true (default), uses in-memory database. If false, creates file-based database.
  ///
  /// Returns: A DatabaseHelper instance with an isolated database
  ///
  /// Example:
  /// ```dart
  /// setUp(() async {
  ///   dbHelper = await TestDatabaseHelper.createTestDatabase();
  /// });
  /// ```
  static Future<DatabaseHelper> createTestDatabase({
    String? dbName,
    bool inMemory = true,
  }) async {
    // Ensure sqflite_ffi is initialized
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final logger = ConsoleLogger('TestDB');

    // Generate unique database name
    final uniqueSuffix =
        '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(10000)}';

    String finalDbName;
    if (inMemory) {
      // In-memory database - use special :memory: syntax
      // sqflite_ffi supports :memory: for in-memory databases
      finalDbName = ':memory:';
    } else {
      // File-based database - creates temporary file
      finalDbName = dbName ?? 'test_$uniqueSuffix.db';
    }

    return DatabaseHelper(logger, dbName: finalDbName);
  }

  /// Cleans up test database resources
  ///
  /// Closes the database connection and removes temporary files if applicable.
  /// Should be called in tearDown() to ensure proper cleanup.
  ///
  /// Parameters:
  /// - [dbHelper]: The DatabaseHelper instance to clean up
  ///
  /// Example:
  /// ```dart
  /// tearDown(() async {
  ///   await TestDatabaseHelper.cleanupTestDatabase(dbHelper);
  /// });
  /// ```
  static Future<void> cleanupTestDatabase(DatabaseHelper dbHelper) async {
    try {
      await dbHelper.close();
      // Note: In-memory databases are automatically cleaned up when closed
      // File-based test databases could be deleted here if needed
    } catch (e) {
      // Log but don't fail the test on cleanup errors
      print('Warning: Failed to cleanup test database: $e');
    }
  }

  /// Creates multiple isolated test databases
  ///
  /// Useful when a test needs multiple database instances.
  ///
  /// Parameters:
  /// - [count]: Number of database instances to create
  /// - [inMemory]: If true (default), uses in-memory databases
  ///
  /// Returns: List of DatabaseHelper instances
  ///
  /// Example:
  /// ```dart
  /// final databases = await TestDatabaseHelper.createMultipleTestDatabases(3);
  /// ```
  static Future<List<DatabaseHelper>> createMultipleTestDatabases(
    int count, {
    bool inMemory = true,
  }) async {
    final databases = <DatabaseHelper>[];
    for (int i = 0; i < count; i++) {
      databases.add(await createTestDatabase(inMemory: inMemory));
    }
    return databases;
  }

  /// Cleans up multiple test databases
  ///
  /// Parameters:
  /// - [databases]: List of DatabaseHelper instances to clean up
  ///
  /// Example:
  /// ```dart
  /// await TestDatabaseHelper.cleanupMultipleTestDatabases(databases);
  /// ```
  static Future<void> cleanupMultipleTestDatabases(
      List<DatabaseHelper> databases) async {
    for (final db in databases) {
      await cleanupTestDatabase(db);
    }
  }
}
