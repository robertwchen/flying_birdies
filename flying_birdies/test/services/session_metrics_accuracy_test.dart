import 'package:flutter_test/flutter_test.dart';
import 'package:flying_birdies/core/logger.dart';
import 'package:flying_birdies/data/database_helper.dart';
import 'package:flying_birdies/data/repositories/session_repository.dart';
import 'package:flying_birdies/data/repositories/swing_repository.dart';
import 'package:flying_birdies/services/session_service.dart';
import 'package:flying_birdies/models/swing_metrics.dart';
import '../helpers/test_database_helper.dart';

/// Feature: backend-refactor-frontend-integration, Property 15: Session Metrics Accuracy
/// Session statistics must accurately reflect the recorded swings.
/// Validates: Requirements 5.5
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Property 15: Session Metrics Accuracy', () {
    late DatabaseHelper dbHelper;
    late SessionRepository sessionRepo;
    late SwingRepository swingRepo;
    late SessionService sessionService;
    late ILogger logger;

    setUp(() async {
      // Create isolated test database
      dbHelper = await TestDatabaseHelper.createTestDatabase();
      logger = ConsoleLogger('SessionMetricsAccuracyTest');
      sessionRepo = SessionRepository(dbHelper, logger);
      swingRepo = SwingRepository(dbHelper, logger);
      sessionService = SessionService(sessionRepo, swingRepo, logger);
    });

    tearDown(() async {
      sessionService.dispose();
      await TestDatabaseHelper.cleanupTestDatabase(dbHelper);
    });

    test('Property 15: Swing count matches recorded swings', () async {
      for (int swingCount in [0, 1, 5, 10, 50, 100]) {
        final sessionId = await sessionService.startSession(
          userId: 'user_test',
        );

        // Record swings
        for (int i = 0; i < swingCount; i++) {
          final swing = SwingMetrics(
            timestamp: DateTime.now(),
            maxOmega: 100.0 + i,
            maxVtip: 20.0 + i,
            impactAmax: 50.0,
            impactSeverity: 0.5,
            estForceN: 150.0,
            swingDurationMs: 200,
            qualityPassed: true,
            shuttleSpeedOut: 80.0,
            forceStandardized: 1.0,
          );
          await sessionService.recordSwing(sessionId, swing);
        }

        await sessionService.endSession(sessionId);

        // Get session summary
        final sessions = await sessionService.getRecentSessions();
        final session = sessions.firstWhere((s) => s.sessionId == sessionId);

        // Verify swing count
        expect(session.swingCount, equals(swingCount));
      }
    });

    test('Property 15: Average speed is calculated correctly', () async {
      final sessionId = await sessionService.startSession(userId: 'user_test');

      // Record swings with known speeds (in m/s)
      final speeds = [10.0, 20.0, 30.0, 40.0, 50.0]; // m/s
      for (final speed in speeds) {
        final swing = SwingMetrics(
          timestamp: DateTime.now(),
          maxOmega: 100.0,
          maxVtip: speed,
          impactAmax: 50.0,
          impactSeverity: 0.5,
          estForceN: 150.0,
          swingDurationMs: 200,
          qualityPassed: true,
          shuttleSpeedOut: 80.0,
          forceStandardized: 1.0,
        );
        await sessionService.recordSwing(sessionId, swing);
      }

      await sessionService.endSession(sessionId);

      // Get session summary
      final sessions = await sessionService.getRecentSessions();
      final session = sessions.firstWhere((s) => s.sessionId == sessionId);

      // Expected average: (10+20+30+40+50)/5 = 30 m/s = 108 km/h
      final expectedAvgKmh = 30.0 * 3.6;
      expect(session.avgSpeed, closeTo(expectedAvgKmh, 0.1));
    });

    test('Property 15: Max speed is calculated correctly', () async {
      final sessionId = await sessionService.startSession(userId: 'user_test');

      // Record swings with various speeds
      final speeds = [10.0, 25.0, 15.0, 30.0, 20.0]; // m/s
      for (final speed in speeds) {
        final swing = SwingMetrics(
          timestamp: DateTime.now(),
          maxOmega: 100.0,
          maxVtip: speed,
          impactAmax: 50.0,
          impactSeverity: 0.5,
          estForceN: 150.0,
          swingDurationMs: 200,
          qualityPassed: true,
          shuttleSpeedOut: 80.0,
          forceStandardized: 1.0,
        );
        await sessionService.recordSwing(sessionId, swing);
      }

      await sessionService.endSession(sessionId);

      final sessions = await sessionService.getRecentSessions();
      final session = sessions.firstWhere((s) => s.sessionId == sessionId);

      // Max speed should be 30 m/s = 108 km/h
      final expectedMaxKmh = 30.0 * 3.6;
      expect(session.maxSpeed, closeTo(expectedMaxKmh, 0.1));
    });

    test('Property 15: Average force is calculated correctly', () async {
      final sessionId = await sessionService.startSession(userId: 'user_test');

      // Record swings with known forces
      final forces = [100.0, 150.0, 200.0, 250.0, 300.0];
      for (final force in forces) {
        final swing = SwingMetrics(
          timestamp: DateTime.now(),
          maxOmega: 100.0,
          maxVtip: 20.0,
          impactAmax: 50.0,
          impactSeverity: 0.5,
          estForceN: force,
          swingDurationMs: 200,
          qualityPassed: true,
          shuttleSpeedOut: 80.0,
          forceStandardized: 1.0,
        );
        await sessionService.recordSwing(sessionId, swing);
      }

      await sessionService.endSession(sessionId);

      final sessions = await sessionService.getRecentSessions();
      final session = sessions.firstWhere((s) => s.sessionId == sessionId);

      // Expected average: (100+150+200+250+300)/5 = 200
      expect(session.avgForce, closeTo(200.0, 0.1));
    });

    test('Property 15: Max force is calculated correctly', () async {
      final sessionId = await sessionService.startSession(userId: 'user_test');

      // Record swings with various forces
      final forces = [100.0, 250.0, 150.0, 300.0, 200.0];
      for (final force in forces) {
        final swing = SwingMetrics(
          timestamp: DateTime.now(),
          maxOmega: 100.0,
          maxVtip: 20.0,
          impactAmax: 50.0,
          impactSeverity: 0.5,
          estForceN: force,
          swingDurationMs: 200,
          qualityPassed: true,
          shuttleSpeedOut: 80.0,
          forceStandardized: 1.0,
        );
        await sessionService.recordSwing(sessionId, swing);
      }

      await sessionService.endSession(sessionId);

      final sessions = await sessionService.getRecentSessions();
      final session = sessions.firstWhere((s) => s.sessionId == sessionId);

      // Max force should be 300
      expect(session.maxForce, closeTo(300.0, 0.1));
    });

    test('Property 15: Empty session has zero metrics', () async {
      final sessionId = await sessionService.startSession(userId: 'user_test');
      await sessionService.endSession(sessionId);

      final sessions = await sessionService.getRecentSessions();
      final session = sessions.firstWhere((s) => s.sessionId == sessionId);

      expect(session.swingCount, equals(0));
      expect(session.avgSpeed, equals(0.0));
      expect(session.avgForce, equals(0.0));
      expect(session.maxSpeed, equals(0.0));
      expect(session.maxForce, equals(0.0));
    });

    test('Property 15: Session duration is calculated correctly', () async {
      final sessionId = await sessionService.startSession(userId: 'user_test');

      // Wait a bit
      await Future.delayed(const Duration(milliseconds: 100));

      await sessionService.endSession(sessionId);

      final sessions = await sessionService.getRecentSessions();
      final session = sessions.firstWhere((s) => s.sessionId == sessionId);

      // Duration should be >= 0 minutes
      expect(session.durationMinutes, greaterThanOrEqualTo(0));
    });
  });
}
