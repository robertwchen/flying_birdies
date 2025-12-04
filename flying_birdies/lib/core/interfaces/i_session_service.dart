import 'dart:async';
import '../../models/swing_metrics.dart';
import '../../models/session_summary.dart';

/// Session event types
enum SessionEventType { started, ended, swingRecorded }

/// Session event data
class SessionEvent {
  final SessionEventType type;
  final int sessionId;
  final DateTime timestamp;
  final dynamic data; // SwingMetrics for swingRecorded

  SessionEvent({
    required this.type,
    required this.sessionId,
    required this.timestamp,
    this.data,
  });
}

/// Session detail with swings
class SessionDetail {
  final SessionSummary summary;
  final List<SwingMetrics> swings;

  const SessionDetail({
    required this.summary,
    required this.swings,
  });
}

/// Session Service interface for dependency injection
abstract class ISessionService {
  /// Stream of session events
  Stream<SessionEvent> get sessionEventStream;

  /// Start a new training session
  Future<int> startSession({
    required String? userId,
    String? deviceId,
    String? strokeFocus,
  });

  /// End an active session
  Future<void> endSession(int sessionId);

  /// Record a swing in a session
  Future<void> recordSwing(int sessionId, SwingMetrics swing);

  /// Get recent sessions
  Future<List<SessionSummary>> getRecentSessions({int limit = 50});

  /// Get session detail with all swings
  Future<SessionDetail> getSessionDetail(int sessionId);

  /// Dispose resources
  void dispose();
}
