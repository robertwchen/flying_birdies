import 'package:flutter_test/flutter_test.dart';
import 'package:flying_birdies/core/logger.dart';
import 'package:flying_birdies/data/database_helper.dart';
import 'package:flying_birdies/data/repositories/session_repository.dart';
import 'package:flying_birdies/data/repositories/swing_repository.dart';
import 'package:flying_birdies/services/session_service.dart';
import 'package:flying_birdies/core/interfaces/i_session_service.dart';
import '../helpers/test_database_helper.dart';

/// Feature: backend-refactor-frontend-integration, Property 12: Session Observer Notification
/// All session lifecycle events must be emitted through the session event stream.
/// Validates: Requirements 5.2
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Property 12: Session Observer Notification', () {
    late DatabaseHelper dbHelper;
    late SessionRepository sessionRepo;
    late SwingRepository swingRepo;
    late SessionService sessionService;
    late ILogger logger;

    setUp(() async {
      // Create isolated test database
      dbHelper = await TestDatabaseHelper.createTestDatabase();
      logger = ConsoleLogger('SessionObserverNotificationTest');
      sessionRepo = SessionRepository(dbHelper, logger);
      swingRepo = SwingRepository(dbHelper, logger);
      sessionService = SessionService(sessionRepo, swingRepo, logger);
    });

    tearDown(() async {
      sessionService.dispose();
      await TestDatabaseHelper.cleanupTestDatabase(dbHelper);
    });

    test('Property 12: startSession emits started event', () async {
      for (int i = 0; i < 100; i++) {
        final events = <SessionEvent>[];
        final sub = sessionService.sessionEventStream.listen((event) {
          events.add(event);
        });

        final sessionId = await sessionService.startSession(
          userId: 'user_$i',
        );

        await Future.delayed(const Duration(milliseconds: 10));

        // Should have received started event
        expect(events.length, equals(1));
        expect(events.first.type, equals(SessionEventType.started));
        expect(events.first.sessionId, equals(sessionId));
        expect(events.first.timestamp, isNotNull);

        await sub.cancel();
      }
    });

    test('Property 12: endSession emits ended event', () async {
      for (int i = 0; i < 100; i++) {
        final sessionId = await sessionService.startSession(
          userId: 'user_$i',
        );

        final events = <SessionEvent>[];
        final sub = sessionService.sessionEventStream.listen((event) {
          events.add(event);
        });

        await sessionService.endSession(sessionId);
        await Future.delayed(const Duration(milliseconds: 10));

        // Should have received ended event
        expect(events.length, equals(1));
        expect(events.first.type, equals(SessionEventType.ended));
        expect(events.first.sessionId, equals(sessionId));

        await sub.cancel();
      }
    });

    test('Property 12: Multiple observers all receive events', () async {
      final observer1Events = <SessionEvent>[];
      final observer2Events = <SessionEvent>[];
      final observer3Events = <SessionEvent>[];

      final sub1 = sessionService.sessionEventStream.listen((event) {
        observer1Events.add(event);
      });

      final sub2 = sessionService.sessionEventStream.listen((event) {
        observer2Events.add(event);
      });

      final sub3 = sessionService.sessionEventStream.listen((event) {
        observer3Events.add(event);
      });

      // Start session
      await sessionService.startSession(userId: 'user1');
      await Future.delayed(const Duration(milliseconds: 10));

      // All observers should receive the event
      expect(observer1Events.length, equals(1));
      expect(observer2Events.length, equals(1));
      expect(observer3Events.length, equals(1));

      expect(observer1Events.first.type, equals(SessionEventType.started));
      expect(observer2Events.first.type, equals(SessionEventType.started));
      expect(observer3Events.first.type, equals(SessionEventType.started));

      await sub1.cancel();
      await sub2.cancel();
      await sub3.cancel();
    });

    test('Property 12: Event stream is broadcast', () {
      // Should be able to add multiple listeners
      final sub1 = sessionService.sessionEventStream.listen((_) {});
      final sub2 = sessionService.sessionEventStream.listen((_) {});
      final sub3 = sessionService.sessionEventStream.listen((_) {});

      expect(sub1, isNotNull);
      expect(sub2, isNotNull);
      expect(sub3, isNotNull);

      sub1.cancel();
      sub2.cancel();
      sub3.cancel();
    });

    test('Property 12: Events include accurate timestamps', () async {
      for (int i = 0; i < 100; i++) {
        final events = <SessionEvent>[];
        final sub = sessionService.sessionEventStream.listen((event) {
          events.add(event);
        });

        final beforeStart = DateTime.now();
        await sessionService.startSession(userId: 'user_$i');
        final afterStart = DateTime.now();

        await Future.delayed(const Duration(milliseconds: 10));

        expect(events.length, equals(1));
        final event = events.first;

        // Timestamp should be between before and after
        expect(
          event.timestamp
              .isAfter(beforeStart.subtract(const Duration(seconds: 1))),
          isTrue,
        );
        expect(
          event.timestamp.isBefore(afterStart.add(const Duration(seconds: 1))),
          isTrue,
        );

        await sub.cancel();
      }
    });

    test('Property 12: Late subscribers receive subsequent events', () async {
      // Start a session before subscribing
      final sessionId = await sessionService.startSession(userId: 'user1');

      // Now subscribe
      final events = <SessionEvent>[];
      final sub = sessionService.sessionEventStream.listen((event) {
        events.add(event);
      });

      // End the session
      await sessionService.endSession(sessionId);
      await Future.delayed(const Duration(milliseconds: 10));

      // Should receive the ended event (but not the started event)
      expect(events.length, equals(1));
      expect(events.first.type, equals(SessionEventType.ended));

      await sub.cancel();
    });

    test('Property 12: Rapid session operations emit all events', () async {
      final events = <SessionEvent>[];
      final sub = sessionService.sessionEventStream.listen((event) {
        events.add(event);
      });

      // Create and end 10 sessions rapidly
      for (int i = 0; i < 10; i++) {
        final sessionId = await sessionService.startSession(userId: 'user_$i');
        await sessionService.endSession(sessionId);
      }

      await Future.delayed(const Duration(milliseconds: 100));

      // Should have 20 events (10 started + 10 ended)
      expect(events.length, equals(20));

      // Verify alternating pattern
      for (int i = 0; i < 10; i++) {
        expect(events[i * 2].type, equals(SessionEventType.started));
        expect(events[i * 2 + 1].type, equals(SessionEventType.ended));
      }

      await sub.cancel();
    });
  });
}
