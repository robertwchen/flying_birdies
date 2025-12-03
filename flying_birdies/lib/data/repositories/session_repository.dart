import 'dart:async';
import '../../core/interfaces/i_session_repository.dart';
import '../../core/logger.dart';
import '../../core/exceptions.dart';
import '../../models/entities/session_entity.dart';
import '../database_helper.dart';

/// Session repository implementation
class SessionRepository implements ISessionRepository {
  final DatabaseHelper _dbHelper;
  final ILogger _logger;

  final StreamController<void> _cacheInvalidationController =
      StreamController<void>.broadcast();

  Stream<void> get cacheInvalidationStream =>
      _cacheInvalidationController.stream;

  SessionRepository(this._dbHelper, this._logger);

  @override
  Future<int> createSession(SessionEntity session) async {
    try {
      final db = await _dbHelper.database;
      final id = await db.insert('sessions', session.toMap());

      _logger.info('Created session', context: {'sessionId': id});
      _cacheInvalidationController.add(null);

      return id;
    } catch (e, stackTrace) {
      _logger.error('Failed to create session',
          error: e, stackTrace: stackTrace);
      throw DatabaseException(
        'Failed to create session',
        'insert',
        context: 'userId: ${session.userId}',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> updateSession(int id, SessionEntity session) async {
    try {
      final db = await _dbHelper.database;
      final count = await db.update(
        'sessions',
        session.toMap(),
        where: 'id = ?',
        whereArgs: [id],
      );

      if (count == 0) {
        throw DatabaseException(
          'Session not found',
          'update',
          context: 'sessionId: $id',
        );
      }

      _logger.info('Updated session', context: {'sessionId': id});
      _cacheInvalidationController.add(null);
    } catch (e, stackTrace) {
      if (e is DatabaseException) rethrow;

      _logger.error('Failed to update session',
          error: e, stackTrace: stackTrace);
      throw DatabaseException(
        'Failed to update session',
        'update',
        context: 'sessionId: $id',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<SessionEntity?> getSession(int id) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'sessions',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isEmpty) {
        return null;
      }

      return SessionEntity.fromMap(maps.first);
    } catch (e, stackTrace) {
      _logger.error('Failed to get session', error: e, stackTrace: stackTrace);
      throw DatabaseException(
        'Failed to get session',
        'query',
        context: 'sessionId: $id',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<List<SessionEntity>> getRecentSessions({int? limit}) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'sessions',
        orderBy: 'start_time DESC',
        limit: limit,
      );

      return maps.map((map) => SessionEntity.fromMap(map)).toList();
    } catch (e, stackTrace) {
      _logger.error('Failed to get recent sessions',
          error: e, stackTrace: stackTrace);
      throw DatabaseException(
        'Failed to get recent sessions',
        'query',
        context: 'limit: $limit',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> deleteSession(int id) async {
    try {
      final db = await _dbHelper.database;
      final count = await db.delete(
        'sessions',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (count == 0) {
        throw DatabaseException(
          'Session not found',
          'delete',
          context: 'sessionId: $id',
        );
      }

      _logger.info('Deleted session', context: {'sessionId': id});
      _cacheInvalidationController.add(null);
    } catch (e, stackTrace) {
      if (e is DatabaseException) rethrow;

      _logger.error('Failed to delete session',
          error: e, stackTrace: stackTrace);
      throw DatabaseException(
        'Failed to delete session',
        'delete',
        context: 'sessionId: $id',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<int> getSessionCount(DateTime start, DateTime end) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery('''
        SELECT COUNT(DISTINCT id) as count
        FROM sessions
        WHERE start_time >= ? AND start_time <= ?
      ''', [
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ]);

      return (result.first['count'] as int?) ?? 0;
    } catch (e, stackTrace) {
      _logger.error('Failed to get session count',
          error: e, stackTrace: stackTrace);
      throw DatabaseException(
        'Failed to get session count',
        'query',
        context: 'start: $start, end: $end',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<List<SessionEntity>> getSessionsInRange(
      DateTime start, DateTime end) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'sessions',
        where: 'start_time >= ? AND start_time <= ?',
        whereArgs: [
          start.millisecondsSinceEpoch,
          end.millisecondsSinceEpoch,
        ],
        orderBy: 'start_time DESC',
      );

      return maps.map((map) => SessionEntity.fromMap(map)).toList();
    } catch (e, stackTrace) {
      _logger.error('Failed to get sessions in range',
          error: e, stackTrace: stackTrace);
      throw DatabaseException(
        'Failed to get sessions in range',
        'query',
        context: 'start: $start, end: $end',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  void dispose() {
    _cacheInvalidationController.close();
  }
}
