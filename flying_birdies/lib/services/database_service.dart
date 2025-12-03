import 'dart:async';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/swing_metrics.dart';

/// Local database service using SQLite
/// Stores last 7 days of swings locally for offline access
class DatabaseService {
  static final DatabaseService instance = DatabaseService._();
  DatabaseService._();

  static Database? _database;

  /// Get database instance (singleton)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize database
  Future<Database> _initDatabase() async {
    String dbPath;

    // Handle desktop platforms differently
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final appDir = await getApplicationDocumentsDirectory();
      dbPath = appDir.path;
    } else {
      // Mobile platforms (Android, iOS)
      dbPath = await getDatabasesPath();
    }

    final path = join(dbPath, 'strikepro.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create database schema
  Future<void> _onCreate(Database db, int version) async {
    // Sessions table
    await db.execute('''
      CREATE TABLE sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT,
        start_time INTEGER NOT NULL,
        end_time INTEGER,
        device_id TEXT,
        stroke_focus TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    // Swings table (with v8 metrics)
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
        FOREIGN KEY (session_id) REFERENCES sessions(id)
      )
    ''');

    // Indexes for performance
    await db.execute('CREATE INDEX idx_swings_session ON swings(session_id)');
    await db.execute('CREATE INDEX idx_swings_timestamp ON swings(timestamp)');
    await db.execute('CREATE INDEX idx_swings_synced ON swings(synced)');
    await db.execute('CREATE INDEX idx_sessions_user ON sessions(user_id)');
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle migrations here
    if (oldVersion < newVersion) {
      // Add migration logic
    }
  }

  /// Create a new session
  Future<int> createSession({
    required String? userId,
    required DateTime startTime,
    String? deviceId,
    String? strokeFocus,
  }) async {
    final db = await database;
    return await db.insert(
      'sessions',
      {
        'user_id': userId,
        'start_time': startTime.millisecondsSinceEpoch,
        'end_time': null,
        'device_id': deviceId,
        'stroke_focus': strokeFocus,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  /// End a session
  Future<void> endSession(int sessionId, DateTime endTime) async {
    final db = await database;
    await db.update(
      'sessions',
      {'end_time': endTime.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  /// Save a swing to database
  Future<int> saveSwing({
    required int sessionId,
    required SwingMetrics swing,
  }) async {
    final db = await database;
    return await db.insert(
      'swings',
      {
        'session_id': sessionId,
        'timestamp': swing.timestamp.millisecondsSinceEpoch,
        'max_omega': swing.maxOmega,
        'max_vtip': swing.maxVtip,
        'impact_amax': swing.impactAmax,
        'impact_severity': swing.impactSeverity,
        'est_force_n': swing.estForceN,
        'swing_duration_ms': swing.swingDurationMs,
        'quality_passed': swing.qualityPassed ? 1 : 0,
        'shuttle_speed_out': swing.shuttleSpeedOut, // v8 addition
        'force_standardized': swing.forceStandardized, // v8 addition
        'synced': 0, // Not synced yet
      },
    );
  }

  /// Get swings for a session
  Future<List<SwingMetrics>> getSwingsForSession(int sessionId) async {
    final db = await database;
    final maps = await db.query(
      'swings',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );

    return maps.map((map) => _swingFromMap(map)).toList();
  }

  /// Get swings in date range
  Future<List<SwingMetrics>> getSwingsInRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    final maps = await db.query(
      'swings',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ],
      orderBy: 'timestamp ASC',
    );

    return maps.map((map) => _swingFromMap(map)).toList();
  }

  /// Get unsynced swings (for sync to backend)
  Future<List<Map<String, dynamic>>> getUnsyncedSwings() async {
    final db = await database;
    return await db.query(
      'swings',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'timestamp ASC',
    );
  }

  /// Mark swings as synced
  Future<void> markSwingsSynced(List<int> swingIds) async {
    final db = await database;
    await db.update(
      'swings',
      {'synced': 1},
      where: 'id IN (${swingIds.map((_) => '?').join(',')})',
      whereArgs: swingIds,
    );
  }

  /// Get sessions for a user
  Future<List<Map<String, dynamic>>> getSessions({
    String? userId,
    int? limit,
  }) async {
    final db = await database;
    return await db.query(
      'sessions',
      where: userId != null ? 'user_id = ?' : null,
      whereArgs: userId != null ? [userId] : null,
      orderBy: 'start_time DESC',
      limit: limit,
    );
  }

  /// Get aggregate stats for date range
  Future<Map<String, dynamic>> getStatsInRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT
        COUNT(*) as count,
        AVG(max_vtip) as avg_vtip,
        MAX(max_vtip) as max_vtip,
        AVG(est_force_n) as avg_force,
        MAX(est_force_n) as max_force,
        AVG(impact_amax) as avg_accel,
        MAX(impact_amax) as max_accel,
        AVG(max_omega) as avg_omega,
        MAX(max_omega) as max_omega
      FROM swings
      WHERE timestamp >= ? AND timestamp <= ?
    ''', [
      start.millisecondsSinceEpoch,
      end.millisecondsSinceEpoch,
    ]);

    if (result.isEmpty) {
      return {
        'count': 0,
        'avg_vtip': 0.0,
        'max_vtip': 0.0,
        'avg_force': 0.0,
        'max_force': 0.0,
        'avg_accel': 0.0,
        'max_accel': 0.0,
        'avg_omega': 0.0,
        'max_omega': 0.0,
      };
    }

    return result.first;
  }

  /// Get daily stats for a date range (for charts)
  Future<List<Map<String, dynamic>>> getDailyStats(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT
        DATE(timestamp / 1000, 'unixepoch') as date,
        COUNT(*) as count,
        AVG(max_vtip) as avg_vtip,
        MAX(max_vtip) as max_vtip,
        AVG(est_force_n) as avg_force,
        MAX(est_force_n) as max_force,
        AVG(impact_amax) as avg_accel,
        MAX(impact_amax) as max_accel,
        AVG(max_omega) as avg_omega,
        MAX(max_omega) as max_omega
      FROM swings
      WHERE timestamp >= ? AND timestamp <= ?
      GROUP BY date
      ORDER BY date ASC
    ''', [
      start.millisecondsSinceEpoch,
      end.millisecondsSinceEpoch,
    ]);

    return result;
  }

  /// Get active training days in a month
  Future<Set<int>> getActiveDaysInMonth(int year, int month) async {
    final db = await database;
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);

    final result = await db.rawQuery('''
      SELECT DISTINCT strftime('%d', timestamp / 1000, 'unixepoch') as day
      FROM swings
      WHERE timestamp >= ? AND timestamp <= ?
    ''', [
      start.millisecondsSinceEpoch,
      end.millisecondsSinceEpoch,
    ]);

    return result.map((r) => int.parse(r['day'] as String)).toSet();
  }

  /// Get session count for a date range
  Future<int> getSessionCount(DateTime start, DateTime end) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(DISTINCT session_id) as count
      FROM swings
      WHERE timestamp >= ? AND timestamp <= ?
    ''', [
      start.millisecondsSinceEpoch,
      end.millisecondsSinceEpoch,
    ]);

    return (result.first['count'] as int?) ?? 0;
  }

  /// Get current streak (consecutive days with swings)
  Future<int> getCurrentStreak() async {
    final db = await database;
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);

    int streak = 0;
    DateTime checkDate = startOfToday;

    while (true) {
      final start = checkDate;
      final end =
          DateTime(checkDate.year, checkDate.month, checkDate.day, 23, 59, 59);

      final result = await db.rawQuery('''
        SELECT COUNT(*) as count
        FROM swings
        WHERE timestamp >= ? AND timestamp <= ?
      ''', [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch]);

      final count = (result.first['count'] as int?) ?? 0;
      if (count == 0) break;

      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));

      // Safety limit
      if (streak > 365) break;
    }

    return streak;
  }

  /// Clean up old swings (keep last 7 days)
  Future<void> cleanupOldSwings() async {
    final db = await database;
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    await db.delete(
      'swings',
      where: 'timestamp < ?',
      whereArgs: [sevenDaysAgo.millisecondsSinceEpoch],
    );
  }

  /// Clear ALL data (for testing)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('swings');
    await db.delete('sessions');
  }

  /// Convert map to SwingMetrics
  SwingMetrics _swingFromMap(Map<String, dynamic> map) {
    return SwingMetrics(
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      maxOmega: map['max_omega'] as double,
      maxVtip: map['max_vtip'] as double,
      impactAmax: map['impact_amax'] as double,
      impactSeverity: map['impact_severity'] as double,
      estForceN: map['est_force_n'] as double,
      swingDurationMs: map['swing_duration_ms'] as int,
      qualityPassed: (map['quality_passed'] as int) == 1,
      shuttleSpeedOut: map['shuttle_speed_out'] as double?, // v8 addition
      forceStandardized: map['force_standardized'] as double?, // v8 addition
    );
  }

  /// Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
