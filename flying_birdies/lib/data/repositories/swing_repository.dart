import 'dart:async';
import '../../core/interfaces/i_swing_repository.dart';
import '../../core/logger.dart';
import '../../core/exceptions.dart';
import '../../models/entities/swing_entity.dart';
import '../database_helper.dart';

/// Swing repository implementation
class SwingRepository implements ISwingRepository {
  final DatabaseHelper _dbHelper;
  final ILogger _logger;

  final StreamController<void> _cacheInvalidationController =
      StreamController<void>.broadcast();

  Stream<void> get cacheInvalidationStream =>
      _cacheInvalidationController.stream;

  SwingRepository(this._dbHelper, this._logger);

  @override
  Future<int> createSwing(SwingEntity swing) async {
    try {
      final db = await _dbHelper.database;
      final id = await db.insert('swings', swing.toMap());

      _logger.debug('Created swing',
          context: {'swingId': id, 'sessionId': swing.sessionId});
      _cacheInvalidationController.add(null);

      return id;
    } catch (e, stackTrace) {
      _logger.error('Failed to create swing', error: e, stackTrace: stackTrace);
      throw DatabaseException(
        'Failed to create swing',
        'insert',
        context: 'sessionId: ${swing.sessionId}',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<List<SwingEntity>> getSwingsForSession(int sessionId) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'swings',
        where: 'session_id = ?',
        whereArgs: [sessionId],
        orderBy: 'timestamp ASC',
      );

      return maps.map((map) => SwingEntity.fromMap(map)).toList();
    } catch (e, stackTrace) {
      _logger.error('Failed to get swings for session',
          error: e, stackTrace: stackTrace);
      throw DatabaseException(
        'Failed to get swings for session',
        'query',
        context: 'sessionId: $sessionId',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<List<SwingEntity>> getSwingsInRange(
      DateTime start, DateTime end) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'swings',
        where: 'timestamp >= ? AND timestamp <= ?',
        whereArgs: [
          start.millisecondsSinceEpoch,
          end.millisecondsSinceEpoch,
        ],
        orderBy: 'timestamp ASC',
      );

      return maps.map((map) => SwingEntity.fromMap(map)).toList();
    } catch (e, stackTrace) {
      _logger.error('Failed to get swings in range',
          error: e, stackTrace: stackTrace);
      throw DatabaseException(
        'Failed to get swings in range',
        'query',
        context: 'start: $start, end: $end',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<List<SwingEntity>> getUnsyncedSwings() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'swings',
        where: 'synced = ?',
        whereArgs: [0],
        orderBy: 'timestamp ASC',
      );

      return maps.map((map) => SwingEntity.fromMap(map)).toList();
    } catch (e, stackTrace) {
      _logger.error('Failed to get unsynced swings',
          error: e, stackTrace: stackTrace);
      throw DatabaseException(
        'Failed to get unsynced swings',
        'query',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> markSwingsSynced(List<int> swingIds) async {
    if (swingIds.isEmpty) return;

    try {
      final db = await _dbHelper.database;
      await db.update(
        'swings',
        {'synced': 1},
        where: 'id IN (${swingIds.map((_) => '?').join(',')})',
        whereArgs: swingIds,
      );

      _logger
          .info('Marked swings as synced', context: {'count': swingIds.length});
      _cacheInvalidationController.add(null);
    } catch (e, stackTrace) {
      _logger.error('Failed to mark swings as synced',
          error: e, stackTrace: stackTrace);
      throw DatabaseException(
        'Failed to mark swings as synced',
        'update',
        context: 'swingIds: ${swingIds.length}',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getStatsInRange(
      DateTime start, DateTime end) async {
    try {
      final db = await _dbHelper.database;
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
    } catch (e, stackTrace) {
      _logger.error('Failed to get stats in range',
          error: e, stackTrace: stackTrace);
      throw DatabaseException(
        'Failed to get stats in range',
        'query',
        context: 'start: $start, end: $end',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getDailyStats(
      DateTime start, DateTime end) async {
    try {
      final db = await _dbHelper.database;
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
    } catch (e, stackTrace) {
      _logger.error('Failed to get daily stats',
          error: e, stackTrace: stackTrace);
      throw DatabaseException(
        'Failed to get daily stats',
        'query',
        context: 'start: $start, end: $end',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<Set<int>> getActiveDaysInMonth(int year, int month) async {
    try {
      final db = await _dbHelper.database;
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
    } catch (e, stackTrace) {
      _logger.error('Failed to get active days in month',
          error: e, stackTrace: stackTrace);
      throw DatabaseException(
        'Failed to get active days in month',
        'query',
        context: 'year: $year, month: $month',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<int> getCurrentStreak() async {
    try {
      final db = await _dbHelper.database;
      final today = DateTime.now();
      final startOfToday = DateTime(today.year, today.month, today.day);

      int streak = 0;
      DateTime checkDate = startOfToday;

      while (true) {
        final start = checkDate;
        final end = DateTime(
            checkDate.year, checkDate.month, checkDate.day, 23, 59, 59);

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
    } catch (e, stackTrace) {
      _logger.error('Failed to get current streak',
          error: e, stackTrace: stackTrace);
      throw DatabaseException(
        'Failed to get current streak',
        'query',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> cleanupOldSwings({int daysToKeep = 7}) async {
    try {
      final db = await _dbHelper.database;
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));

      final count = await db.delete(
        'swings',
        where: 'timestamp < ?',
        whereArgs: [cutoffDate.millisecondsSinceEpoch],
      );

      _logger.info('Cleaned up old swings',
          context: {'deletedCount': count, 'daysToKeep': daysToKeep});
      _cacheInvalidationController.add(null);
    } catch (e, stackTrace) {
      _logger.error('Failed to cleanup old swings',
          error: e, stackTrace: stackTrace);
      throw DatabaseException(
        'Failed to cleanup old swings',
        'delete',
        context: 'daysToKeep: $daysToKeep',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  void dispose() {
    _cacheInvalidationController.close();
  }
}
