import 'package:flutter_test/flutter_test.dart';
import 'package:flying_birdies/core/logger.dart';
import 'package:flying_birdies/data/database_helper.dart';
import 'package:flying_birdies/data/repositories/session_repository.dart';
import 'package:flying_birdies/data/repositories/swing_repository.dart';
import 'package:flying_birdies/models/entities/session_entity.dart';
import 'package:flying_birdies/models/entities/swing_entity.dart';
import '../helpers/test_database_helper.dart';

/// Property 29: Cache Invalidation Events
/// Repositories must emit cache invalidation events on data modifications
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Property 29: Cache Invalidation Events', () {
    late DatabaseHelper dbHelper;
    late SessionRepository sessionRepo;
    late SwingRepository swingRepo;
    late ILogger logger;

    setUp(() async {
      // Create isolated test database
      dbHelper = await TestDatabaseHelper.createTestDatabase();
      logger = ConsoleLogger('CacheInvalidationEventsTest');
      sessionRepo = SessionRepository(dbHelper, logger);
      swingRepo = SwingRepository(dbHelper, logger);
    });

    tearDown(() async {
      await TestDatabaseHelper.cleanupTestDatabase(dbHelper);
    });

    test('SessionRepository emits event on createSession', () async {
      final now = DateTime.now();
      final events = <void>[];

      // Listen to cache invalidation stream
      final subscription = sessionRepo.cacheInvalidationStream.listen((event) {
        events.add(event);
      });

      // Create session
      await sessionRepo.createSession(SessionEntity(
        userId: 'user1',
        startTime: now,
        deviceId: 'device1',
        strokeFocus: 'forehand',
        createdAt: now,
      ));

      // Wait for event propagation
      await Future.delayed(const Duration(milliseconds: 100));

      expect(events.length, equals(1));
      await subscription.cancel();
    });

    test('SessionRepository emits event on updateSession', () async {
      final now = DateTime.now();
      final events = <void>[];

      // Create initial session
      final sessionId = await sessionRepo.createSession(SessionEntity(
        userId: 'user1',
        startTime: now,
        deviceId: 'device1',
        strokeFocus: 'forehand',
        createdAt: now,
      ));

      // Listen to cache invalidation stream
      final subscription = sessionRepo.cacheInvalidationStream.listen((event) {
        events.add(event);
      });

      // Update session
      await sessionRepo.updateSession(
        sessionId,
        SessionEntity(
          id: sessionId,
          userId: 'user1',
          startTime: now,
          endTime: now.add(const Duration(hours: 1)),
          deviceId: 'device1',
          strokeFocus: 'backhand',
          createdAt: now,
        ),
      );

      // Wait for event propagation
      await Future.delayed(const Duration(milliseconds: 100));

      expect(events.length, equals(1));
      await subscription.cancel();
    });

    test('SessionRepository emits event on deleteSession', () async {
      final now = DateTime.now();
      final events = <void>[];

      // Create initial session
      final sessionId = await sessionRepo.createSession(SessionEntity(
        userId: 'user1',
        startTime: now,
        deviceId: 'device1',
        strokeFocus: 'forehand',
        createdAt: now,
      ));

      // Listen to cache invalidation stream
      final subscription = sessionRepo.cacheInvalidationStream.listen((event) {
        events.add(event);
      });

      // Delete session
      await sessionRepo.deleteSession(sessionId);

      // Wait for event propagation
      await Future.delayed(const Duration(milliseconds: 100));

      expect(events.length, equals(1));
      await subscription.cancel();
    });

    test('SwingRepository emits event on createSwing', () async {
      final now = DateTime.now();
      final events = <void>[];

      // Create session first
      final sessionId = await sessionRepo.createSession(SessionEntity(
        userId: 'user1',
        startTime: now,
        deviceId: 'device1',
        strokeFocus: 'forehand',
        createdAt: now,
      ));

      // Listen to cache invalidation stream
      final subscription = swingRepo.cacheInvalidationStream.listen((event) {
        events.add(event);
      });

      // Create swing
      await swingRepo.createSwing(SwingEntity(
        sessionId: sessionId,
        timestamp: now,
        maxOmega: 100.0,
        maxVtip: 50.0,
        impactAmax: 20.0,
        impactSeverity: 0.5,
        estForceN: 150.0,
        swingDurationMs: 200,
        qualityPassed: true,
      ));

      // Wait for event propagation
      await Future.delayed(const Duration(milliseconds: 100));

      expect(events.length, equals(1));
      await subscription.cancel();
    });

    test('SwingRepository emits event on markSwingsSynced', () async {
      final now = DateTime.now();
      final events = <void>[];

      // Create session and swing
      final sessionId = await sessionRepo.createSession(SessionEntity(
        userId: 'user1',
        startTime: now,
        deviceId: 'device1',
        strokeFocus: 'forehand',
        createdAt: now,
      ));

      final swingId = await swingRepo.createSwing(SwingEntity(
        sessionId: sessionId,
        timestamp: now,
        maxOmega: 100.0,
        maxVtip: 50.0,
        impactAmax: 20.0,
        impactSeverity: 0.5,
        estForceN: 150.0,
        swingDurationMs: 200,
        qualityPassed: true,
      ));

      // Listen to cache invalidation stream
      final subscription = swingRepo.cacheInvalidationStream.listen((event) {
        events.add(event);
      });

      // Mark swings as synced
      await swingRepo.markSwingsSynced([swingId]);

      // Wait for event propagation
      await Future.delayed(const Duration(milliseconds: 100));

      expect(events.length, equals(1));
      await subscription.cancel();
    });

    test('SwingRepository emits event on cleanupOldSwings', () async {
      final now = DateTime.now();
      final events = <void>[];

      // Create session and old swing
      final sessionId = await sessionRepo.createSession(SessionEntity(
        userId: 'user1',
        startTime: now.subtract(const Duration(days: 10)),
        deviceId: 'device1',
        strokeFocus: 'forehand',
        createdAt: now.subtract(const Duration(days: 10)),
      ));

      await swingRepo.createSwing(SwingEntity(
        sessionId: sessionId,
        timestamp: now.subtract(const Duration(days: 10)),
        maxOmega: 100.0,
        maxVtip: 50.0,
        impactAmax: 20.0,
        impactSeverity: 0.5,
        estForceN: 150.0,
        swingDurationMs: 200,
        qualityPassed: true,
      ));

      // Listen to cache invalidation stream
      final subscription = swingRepo.cacheInvalidationStream.listen((event) {
        events.add(event);
      });

      // Cleanup old swings
      await swingRepo.cleanupOldSwings(daysToKeep: 7);

      // Wait for event propagation
      await Future.delayed(const Duration(milliseconds: 100));

      expect(events.length, equals(1));
      await subscription.cancel();
    });

    test('multiple operations emit multiple events', () async {
      final now = DateTime.now();
      final events = <void>[];

      // Listen to cache invalidation stream
      final subscription = sessionRepo.cacheInvalidationStream.listen((event) {
        events.add(event);
      });

      // Perform multiple operations
      final id1 = await sessionRepo.createSession(SessionEntity(
        userId: 'user1',
        startTime: now,
        deviceId: 'device1',
        strokeFocus: 'forehand',
        createdAt: now,
      ));

      await sessionRepo.createSession(SessionEntity(
        userId: 'user2',
        startTime: now,
        deviceId: 'device2',
        strokeFocus: 'backhand',
        createdAt: now,
      ));

      await sessionRepo.deleteSession(id1);

      // Wait for event propagation
      await Future.delayed(const Duration(milliseconds: 100));

      expect(events.length, equals(3)); // 2 creates + 1 delete
      await subscription.cancel();
    });

    test('read operations do not emit events', () async {
      final now = DateTime.now();
      final events = <void>[];

      // Create initial session
      await sessionRepo.createSession(SessionEntity(
        userId: 'user1',
        startTime: now,
        deviceId: 'device1',
        strokeFocus: 'forehand',
        createdAt: now,
      ));

      // Listen to cache invalidation stream
      final subscription = sessionRepo.cacheInvalidationStream.listen((event) {
        events.add(event);
      });

      // Perform read operations
      await sessionRepo.getRecentSessions();
      await sessionRepo.getSessionCount(
        now.subtract(const Duration(days: 1)),
        now.add(const Duration(days: 1)),
      );

      // Wait to ensure no events are emitted
      await Future.delayed(const Duration(milliseconds: 100));

      expect(events.length, equals(0));
      await subscription.cancel();
    });
  });
}
