import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../core/logger.dart';
import '../core/exceptions.dart' as app_exceptions;

/// Database helper for managing SQLite database
class DatabaseHelper {
  final ILogger _logger;
  final String _dbName;
  Database? _database;

  DatabaseHelper(
    this._logger, {
    String dbName = 'strikepro.db',
  }) : _dbName = dbName;

  /// Get database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize database
  Future<Database> _initDatabase() async {
    try {
      // Support in-memory databases for testing (starts with :memory:)
      final String path;
      if (_dbName.startsWith(':memory:')) {
        path = _dbName;
      } else {
        // Use getDatabasesPath for all platforms (works in tests with sqflite_ffi)
        final dbPath = await getDatabasesPath();
        path = join(dbPath, _dbName);
      }

      _logger.info('Initializing database at: $path');

      return await openDatabase(
        path,
        version: 2, // Incremented for cloud_session_id column
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize database',
          error: e, stackTrace: stackTrace);
      throw app_exceptions.DatabaseException(
        'Failed to initialize database',
        'init',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Create database schema
  Future<void> _onCreate(Database db, int version) async {
    _logger.info('Creating database schema version $version');

    try {
      // Sessions table
      await db.execute('''
        CREATE TABLE sessions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT,
          start_time INTEGER NOT NULL,
          end_time INTEGER,
          device_id TEXT,
          stroke_focus TEXT,
          cloud_session_id TEXT,
          synced INTEGER DEFAULT 0,
          created_at INTEGER NOT NULL
        )
      ''');

      // Swings table
      await db.execute('''
        CREATE TABLE swings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          session_id INTEGER NOT NULL,
          timestamp INTEGER NOT NULL,
          max_omega REAL NOT NULL,
          max_vtip REAL NOT NULL,
          impact_amax REAL NOT NULL,
          impact_severity REAL NOT NULL,
          est_force_n REAL NOT NULL,
          swing_duration_ms INTEGER NOT NULL,
          quality_passed INTEGER NOT NULL,
          shuttle_speed_out REAL,
          force_standardized REAL,
          synced INTEGER DEFAULT 0,
          FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
        )
      ''');

      // Indexes for performance
      await db.execute('CREATE INDEX idx_swings_session ON swings(session_id)');
      await db
          .execute('CREATE INDEX idx_swings_timestamp ON swings(timestamp)');
      await db.execute('CREATE INDEX idx_swings_synced ON swings(synced)');
      await db.execute('CREATE INDEX idx_sessions_user ON sessions(user_id)');
      await db.execute('CREATE INDEX idx_sessions_synced ON sessions(synced)');
      await db.execute(
          'CREATE INDEX idx_sessions_cloud_id ON sessions(cloud_session_id)');

      _logger.info('Database schema created successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to create database schema',
          error: e, stackTrace: stackTrace);
      throw app_exceptions.DatabaseException(
        'Failed to create database schema',
        'create_schema',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    _logger.info('Upgrading database from version $oldVersion to $newVersion');

    try {
      if (oldVersion < 2) {
        // Check if columns already exist before adding them
        final columns = await _getTableColumns(db, 'sessions');

        if (!columns.contains('cloud_session_id')) {
          await db
              .execute('ALTER TABLE sessions ADD COLUMN cloud_session_id TEXT');
          _logger.info('Added cloud_session_id column to sessions table');
        } else {
          _logger.info('cloud_session_id column already exists, skipping');
        }

        if (!columns.contains('synced')) {
          await db.execute(
              'ALTER TABLE sessions ADD COLUMN synced INTEGER DEFAULT 0');
          _logger.info('Added synced column to sessions table');
        } else {
          _logger.info('synced column already exists, skipping');
        }

        // Create indexes if they don't exist (SQLite ignores if exists)
        try {
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_sessions_synced ON sessions(synced)');
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_sessions_cloud_id ON sessions(cloud_session_id)');
        } catch (e) {
          _logger.warning('Index creation skipped (may already exist)',
              context: {'error': e.toString()});
        }
      }

      _logger.info('Database upgrade completed successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to upgrade database',
          error: e, stackTrace: stackTrace);
      throw app_exceptions.DatabaseException(
        'Failed to upgrade database',
        'upgrade',
        context: 'oldVersion: $oldVersion, newVersion: $newVersion',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Execute a transaction
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    try {
      final db = await database;
      return await db.transaction(action);
    } catch (e, stackTrace) {
      _logger.error('Transaction failed', error: e, stackTrace: stackTrace);
      throw app_exceptions.DatabaseException(
        'Transaction failed',
        'transaction',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Get list of columns in a table
  Future<List<String>> _getTableColumns(Database db, String tableName) async {
    final result = await db.rawQuery('PRAGMA table_info($tableName)');
    return result.map((row) => row['name'] as String).toList();
  }

  /// Close database
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      _logger.info('Database closed');
    }
  }
}
