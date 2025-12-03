import '../../models/entities/session_entity.dart';

/// Session Repository interface for dependency injection
abstract class ISessionRepository {
  /// Create a new session
  Future<int> createSession(SessionEntity session);

  /// Update an existing session
  Future<void> updateSession(int id, SessionEntity session);

  /// Get a session by ID
  Future<SessionEntity?> getSession(int id);

  /// Get recent sessions
  Future<List<SessionEntity>> getRecentSessions({int? limit});

  /// Delete a session
  Future<void> deleteSession(int id);

  /// Get session count in date range
  Future<int> getSessionCount(DateTime start, DateTime end);

  /// Get sessions in date range
  Future<List<SessionEntity>> getSessionsInRange(DateTime start, DateTime end);
}
