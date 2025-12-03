import '../../models/entities/swing_entity.dart';

/// Swing Repository interface for dependency injection
abstract class ISwingRepository {
  /// Create a new swing
  Future<int> createSwing(SwingEntity swing);

  /// Get all swings for a session
  Future<List<SwingEntity>> getSwingsForSession(int sessionId);

  /// Get swings in a date range
  Future<List<SwingEntity>> getSwingsInRange(DateTime start, DateTime end);

  /// Get unsynced swings
  Future<List<SwingEntity>> getUnsyncedSwings();

  /// Mark swings as synced
  Future<void> markSwingsSynced(List<int> swingIds);

  /// Get aggregate stats for date range
  Future<Map<String, dynamic>> getStatsInRange(DateTime start, DateTime end);

  /// Get daily stats for date range
  Future<List<Map<String, dynamic>>> getDailyStats(
      DateTime start, DateTime end);

  /// Get active training days in a month
  Future<Set<int>> getActiveDaysInMonth(int year, int month);

  /// Get current streak (consecutive days with swings)
  Future<int> getCurrentStreak();

  /// Clean up old swings
  Future<void> cleanupOldSwings({int daysToKeep = 7});
}
