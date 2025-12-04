import 'dart:async';
import '../core/interfaces/i_session_service.dart';
import '../core/interfaces/i_session_repository.dart';
import '../core/interfaces/i_swing_repository.dart';
import '../core/logger.dart';
import '../core/exceptions.dart';
import '../models/entities/session_entity.dart';
import '../models/entities/swing_entity.dart';
import '../models/swing_metrics.dart';
import '../models/session_summary.dart';

/// Session Service for managing training sessions
class SessionService implements ISessionService {
  final ISessionRepository _sessionRepo;
  final ISwingRepository _swingRepo;
  final ILogger _logger;

  final StreamController<SessionEvent> _sessionEventController =
      StreamController<SessionEvent>.broadcast();

  SessionService(this._sessionRepo, this._swingRepo, this._logger);

  @override
  Stream<SessionEvent> get sessionEventStream => _sessionEventController.stream;

  @override
  Future<int> startSession({
    required String? userId,
    String? deviceId,
    String? strokeFocus,
  }) async {
    try {
      _logger.info('Starting new session', context: {
        'userId': userId,
        'deviceId': deviceId,
        'strokeFocus': strokeFocus,
      });

      final now = DateTime.now();
      final session = SessionEntity(
        userId: userId,
        startTime: now,
        deviceId: deviceId,
        strokeFocus: strokeFocus,
        createdAt: now,
      );

      final sessionId = await _sessionRepo.createSession(session);

      _logger.info('Session started', context: {'sessionId': sessionId});

      // Emit session started event
      _sessionEventController.add(SessionEvent(
        type: SessionEventType.started,
        sessionId: sessionId,
        timestamp: now,
      ));

      return sessionId;
    } catch (e, stackTrace) {
      _logger.error('Failed to start session',
          error: e, stackTrace: stackTrace);
      throw DatabaseException(
        'Failed to start session',
        'startSession',
        context: 'userId: $userId',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> endSession(int sessionId) async {
    try {
      _logger.info('Ending session', context: {'sessionId': sessionId});

      // Get the session to update it
      final session = await _sessionRepo.getSession(sessionId);
      if (session == null) {
        throw DatabaseException(
          'Session not found',
          'endSession',
          context: 'sessionId: $sessionId',
        );
      }

      // Update session with end time
      final now = DateTime.now();
      final updatedSession = session.copyWith(endTime: now);
      await _sessionRepo.updateSession(sessionId, updatedSession);

      _logger.info('Session ended', context: {'sessionId': sessionId});

      // Emit session ended event
      _sessionEventController.add(SessionEvent(
        type: SessionEventType.ended,
        sessionId: sessionId,
        timestamp: now,
      ));
    } catch (e, stackTrace) {
      if (e is DatabaseException) rethrow;

      _logger.error('Failed to end session', error: e, stackTrace: stackTrace);
      throw DatabaseException(
        'Failed to end session',
        'endSession',
        context: 'sessionId: $sessionId',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> recordSwing(int sessionId, SwingMetrics swing) async {
    try {
      _logger.debug('Recording swing', context: {
        'sessionId': sessionId,
        'maxVtip': swing.maxVtip,
        'estForceN': swing.estForceN,
      });

      final swingEntity = SwingEntity(
        sessionId: sessionId,
        timestamp: swing.timestamp,
        maxOmega: swing.maxOmega,
        maxVtip: swing.maxVtip,
        impactAmax: swing.impactAmax,
        impactSeverity: swing.impactSeverity,
        estForceN: swing.estForceN,
        swingDurationMs: swing.swingDurationMs,
        qualityPassed: swing.qualityPassed,
        shuttleSpeedOut: swing.shuttleSpeedOut,
        forceStandardized: swing.forceStandardized,
      );

      await _swingRepo.createSwing(swingEntity);

      _logger.debug('Swing recorded', context: {'sessionId': sessionId});

      // Emit swing recorded event
      _sessionEventController.add(SessionEvent(
        type: SessionEventType.swingRecorded,
        sessionId: sessionId,
        timestamp: swing.timestamp,
        data: swing,
      ));
    } catch (e, stackTrace) {
      _logger.error('Failed to record swing', error: e, stackTrace: stackTrace);
      throw DatabaseException(
        'Failed to record swing',
        'recordSwing',
        context: 'sessionId: $sessionId',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Private helper to calculate session summary from session and swings
  SessionSummary _calculateSessionSummary(
    SessionEntity session,
    List<SwingEntity> swings,
  ) {
    // Calculate statistics
    int swingCount = swings.length;
    double avgSpeedKmh = 0;
    double maxSpeedKmh = 0;
    double avgForceN = 0;
    double maxForceN = 0;
    double avgAccelMs2 = 0;
    double maxAccelMs2 = 0;

    if (swings.isNotEmpty) {
      // Speed metrics (convert m/s to km/h)
      avgSpeedKmh = swings.map((s) => s.maxVtip * 3.6).reduce((a, b) => a + b) /
          swings.length;
      maxSpeedKmh =
          swings.map((s) => s.maxVtip * 3.6).reduce((a, b) => a > b ? a : b);

      // Force metrics
      avgForceN = swings.map((s) => s.estForceN).reduce((a, b) => a + b) /
          swings.length;
      maxForceN =
          swings.map((s) => s.estForceN).reduce((a, b) => a > b ? a : b);

      // Acceleration metrics
      avgAccelMs2 = swings.map((s) => s.impactAmax).reduce((a, b) => a + b) /
          swings.length;
      maxAccelMs2 =
          swings.map((s) => s.impactAmax).reduce((a, b) => a > b ? a : b);
    }

    // Calculate duration
    int durationMinutes = 0;
    if (session.endTime != null) {
      durationMinutes =
          session.endTime!.difference(session.startTime).inMinutes;
    }

    return SessionSummary(
      sessionId: session.id!,
      startTime: session.startTime,
      endTime: session.endTime,
      strokeFocus: session.strokeFocus,
      swingCount: swingCount,
      avgSpeedKmh: avgSpeedKmh,
      maxSpeedKmh: maxSpeedKmh,
      avgForceN: avgForceN,
      maxForceN: maxForceN,
      avgAccelMs2: avgAccelMs2,
      maxAccelMs2: maxAccelMs2,
      durationMinutes: durationMinutes,
    );
  }

  @override
  Future<List<SessionSummary>> getRecentSessions({int limit = 50}) async {
    try {
      _logger.debug('Getting recent sessions', context: {'limit': limit});

      final sessions = await _sessionRepo.getRecentSessions(limit: limit);
      final summaries = <SessionSummary>[];

      for (final session in sessions) {
        final swings = await _swingRepo.getSwingsForSession(session.id!);
        summaries.add(_calculateSessionSummary(session, swings));
      }

      _logger.debug('Retrieved ${summaries.length} session summaries');
      return summaries;
    } catch (e, stackTrace) {
      _logger.error('Failed to get recent sessions',
          error: e, stackTrace: stackTrace);
      throw DatabaseException(
        'Failed to get recent sessions',
        'getRecentSessions',
        context: 'limit: $limit',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<SessionDetail> getSessionDetail(int sessionId) async {
    try {
      _logger
          .debug('Getting session detail', context: {'sessionId': sessionId});

      final session = await _sessionRepo.getSession(sessionId);
      if (session == null) {
        throw DatabaseException(
          'Session not found',
          'getSessionDetail',
          context: 'sessionId: $sessionId',
        );
      }

      final swingEntities = await _swingRepo.getSwingsForSession(sessionId);

      // Convert swing entities to swing metrics
      final swings = swingEntities.map((entity) {
        return SwingMetrics(
          timestamp: entity.timestamp,
          maxOmega: entity.maxOmega,
          maxVtip: entity.maxVtip,
          impactAmax: entity.impactAmax,
          impactSeverity: entity.impactSeverity,
          estForceN: entity.estForceN,
          swingDurationMs: entity.swingDurationMs,
          qualityPassed: entity.qualityPassed,
          shuttleSpeedOut: entity.shuttleSpeedOut,
          forceStandardized: entity.forceStandardized,
        );
      }).toList();

      // Use shared calculation method
      final summary = _calculateSessionSummary(session, swingEntities);

      _logger.debug('Retrieved session detail with ${swings.length} swings');
      return SessionDetail(summary: summary, swings: swings);
    } catch (e, stackTrace) {
      if (e is DatabaseException) rethrow;

      _logger.error('Failed to get session detail',
          error: e, stackTrace: stackTrace);
      throw DatabaseException(
        'Failed to get session detail',
        'getSessionDetail',
        context: 'sessionId: $sessionId',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  void dispose() {
    _logger.info('Disposing SessionService');
    _sessionEventController.close();
  }
}
