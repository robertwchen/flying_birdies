import 'package:flutter_test/flutter_test.dart';
import 'package:flying_birdies/core/logger.dart';
import 'package:flying_birdies/data/database_helper.dart';
import 'package:flying_birdies/data/repositories/session_repository.dart';
import 'package:flying_birdies/data/repositories/swing_repository.dart';
import 'package:flying_birdies/services/session_service.dart';
import '../helpers/test_database_helper.dart';

/// Feature: backend-refactor-frontend-integration, Property 11: Session Persistence
/// All session data must be persisted to database and retrievable.
/// Validates: Requirements 5.1
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Property 11: Session Persistence', () {
    late DatabaseHelper dbHelper;
    late SessionRepository sessionRepo;
    late SwingRepository swingRepo;
    late SessionService sessionService;
    late ILogger logger;

    setUp(() async {
      // Create isolated test database
      dbHelper = await TestDatabaseHelper.createTestDatabase();
      logger = ConsoleLogger('SessionPersistenceTest');
      sessionRepo = SessionRepository(dbHelper, logger);
      swingRepo = SwingRepository(dbHelper, logger);
      sessionService = SessionService(sessionRepo, swingRepo, logger);
    });

    tearDown(() async {
      sessionService.dispose();
      await TestDatabaseHelper.cleanupTestDatabase(dbHelper);
    });

    test('Property 11: Started session is persisted to database', () async {
      for (int i = 0; i < 100; i++) {
        final sessionId = await sessionService.startSession(
          userId: 'user_$i',
          deviceId: 'device_$i',
          strokeFocus: 'forehand',
        );

        // Verify session exists in database
        final session = await sessionRepo.getSession(sessionId);
        expect(session, isNotNull);
        expect(session!.userId, equals('user_$i'));
        expect(session.deviceId, equals('device_$i'));
        expect(session.strokeFocus, equals('forehand'));
        expect(session.startTime, isNotNull);
        expect(session.endTime, isNull); // Not ended yet
      }
    });

    test('Property 11: Ended session updates database', () async {
      for (int i = 0; i < 100; i++) {
        final sessionId = await sessionService.startSession(
          userId: 'user_$i',
          deviceId: 'device_$i',
        );

        // Small delay to ensure different timestamps
        await Future.delayed(Duration(milliseconds: 2));

        // End the session
        await sessionService.endSession(sessionId);

        // Verify session has end time
        final session = await sessionRepo.getSession(sessionId);
        expect(session, isNotNull);
        expect(session!.endTime, isNotNull);
        expect(session.endTime!.isAfter(session.startTime), isTrue);
      }
    });

    test('Property 11: Session data survives service restart', () async {
      // Create session with first service instance
      final sessionId = await sessionService.startSession(
        userId: 'persistent_user',
        deviceId: 'persistent_device',
        strokeFocus: 'smash',
      );

      // Dispose service
      sessionService.dispose();

      // Create new service instance
      final newService = SessionService(sessionRepo, swingRepo, logger);

      // Retrieve session with new service
      final sessions = await newService.getRecentSessions();
      expect(sessions.any((s) => s.sessionId == sessionId), isTrue);

      final found = sessions.firstWhere((s) => s.sessionId == sessionId);
      expect(found.strokeFocus, equals('smash'));

      newService.dispose();
    });

    test('Property 11: Multiple sessions are all persisted', () async {
      final sessionIds = <int>[];

      // Create 50 sessions
      for (int i = 0; i < 50; i++) {
        final id = await sessionService.startSession(
          userId: 'user_$i',
          deviceId: 'device_$i',
          strokeFocus: 'stroke_$i',
        );
        sessionIds.add(id);
      }

      // Verify all sessions exist
      for (int i = 0; i < 50; i++) {
        final session = await sessionRepo.getSession(sessionIds[i]);
        expect(session, isNotNull);
        expect(session!.userId, equals('user_$i'));
      }
    });

    test('Property 11: Session timestamps are accurate', () async {
      for (int i = 0; i < 100; i++) {
        final beforeStart = DateTime.now();
        final sessionId = await sessionService.startSession(
          userId: 'user_$i',
        );
        final afterStart = DateTime.now();

        final session = await sessionRepo.getSession(sessionId);
        expect(session, isNotNull);

        // Start time should be between before and after
        expect(
          session!.startTime
              .isAfter(beforeStart.subtract(const Duration(seconds: 1))),
          isTrue,
        );
        expect(
          session.startTime
              .isBefore(afterStart.add(const Duration(seconds: 1))),
          isTrue,
        );
      }
    });

    test('Property 11: Session IDs are unique', () async {
      final sessionIds = <int>{};

      // Create 100 sessions
      for (int i = 0; i < 100; i++) {
        final id = await sessionService.startSession(userId: 'user_$i');
        sessionIds.add(id);
      }

      // All IDs should be unique
      expect(sessionIds.length, equals(100));
    });

    test('Property 11: getRecentSessions returns persisted data', () async {
      // Create sessions
      for (int i = 0; i < 10; i++) {
        await sessionService.startSession(
          userId: 'user_$i',
          strokeFocus: 'stroke_$i',
        );
      }

      // Retrieve sessions
      final sessions = await sessionService.getRecentSessions();
      expect(sessions.length, greaterThanOrEqualTo(10));

      // Verify data integrity
      for (final session in sessions) {
        expect(session.sessionId, isNotNull);
        expect(session.startTime, isNotNull);
      }
    });
  });
}
