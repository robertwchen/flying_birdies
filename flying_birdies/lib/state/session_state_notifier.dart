import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/interfaces/i_session_service.dart';
import '../models/session_summary.dart';

/// Session event for stream
enum SessionEventType { started, ended, swingRecorded, listUpdated }

class SessionStateEvent {
  final SessionEventType type;
  final int? sessionId;
  final DateTime timestamp;
  final dynamic data;

  SessionStateEvent({
    required this.type,
    this.sessionId,
    required this.timestamp,
    this.data,
  });
}

/// Manages session state and notifies listeners of changes
class SessionStateNotifier extends ChangeNotifier {
  int? _activeSessionId;
  List<SessionSummary> _recentSessions = [];

  final StreamController<SessionStateEvent> _eventController =
      StreamController<SessionStateEvent>.broadcast();

  int? get activeSessionId => _activeSessionId;
  List<SessionSummary> get recentSessions => List.unmodifiable(_recentSessions);
  bool get hasActiveSession => _activeSessionId != null;

  Stream<SessionStateEvent> get sessionEventStream => _eventController.stream;

  /// Start a new session
  void startSession(int sessionId) {
    _activeSessionId = sessionId;

    _eventController.add(SessionStateEvent(
      type: SessionEventType.started,
      sessionId: sessionId,
      timestamp: DateTime.now(),
    ));

    notifyListeners();
  }

  /// End the active session
  void endSession() {
    final sessionId = _activeSessionId;
    _activeSessionId = null;

    if (sessionId != null) {
      _eventController.add(SessionStateEvent(
        type: SessionEventType.ended,
        sessionId: sessionId,
        timestamp: DateTime.now(),
      ));
    }

    notifyListeners();
  }

  /// Record a swing in the active session
  void recordSwing(dynamic swingData) {
    if (_activeSessionId != null) {
      _eventController.add(SessionStateEvent(
        type: SessionEventType.swingRecorded,
        sessionId: _activeSessionId,
        timestamp: DateTime.now(),
        data: swingData,
      ));

      notifyListeners();
    }
  }

  /// Update the list of recent sessions
  void updateRecentSessions(List<SessionSummary> sessions) {
    _recentSessions = sessions;

    _eventController.add(SessionStateEvent(
      type: SessionEventType.listUpdated,
      timestamp: DateTime.now(),
      data: sessions,
    ));

    notifyListeners();
  }

  @override
  void dispose() {
    _eventController.close();
    super.dispose();
  }
}
