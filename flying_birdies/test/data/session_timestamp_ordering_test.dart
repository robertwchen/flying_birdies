import 'package:flutter_test/flutter_test.dart';
import 'package:flying_birdies/core/logger.dart';
import 'package:flying_birdies/data/database_helper.dart';
import 'package:flying_birdies/data/repositories/session_repository.dart';
import 'package:flying_birdies/models/entities/session_entity.dart';
import '../helpers/test_database_helper.dart';

/// Property 14: Session Timestamp Ordering
/// Sessions retrieved from database must be ordered by timestamp
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Property 14: Session Timestamp Ordering', () {
    late DatabaseHelper dbHelper;
    late SessionRepository repository;
    late ILogger logger;

    setUp(() async {
      // Create isolated test database
      dbHelper = await TestDatabaseHelper.createTestDatabase();
      logger = ConsoleLogger('SessionTimestampOrderingTest');
      repository = SessionRepository(dbHelper, logger);
    });

    tearDown(() async {
      await TestDatabaseHelper.cleanupTestDatabase(dbHelper);
    });

    test('getRecentSessions returns sessions in descending timestamp order',
        () async {
      // Create sessions with different timestamps
      final now = DateTime.now();
      final sessions = [
        SessionEntity(
          userId: 'user1',
          startTime: now.subtract(const Duration(hours: 3)),
          deviceId: 'device1',
          strokeFocus: 'forehand',
          createdAt: now.subtract(const Duration(hours: 3)),
        ),
        SessionEntity(
          userId: 'user1',
          startTime: now.subtract(const Duration(hours: 1)),
          deviceId: 'device1',
          strokeFocus: 'backhand',
          createdAt: now.subtract(const Duration(hours: 1)),
        ),
        SessionEntity(
          userId: 'user1',
          startTime: now.subtract(const Duration(hours: 2)),
          deviceId: 'device1',
          strokeFocus: 'smash',
          createdAt: now.subtract(const Duration(hours: 2)),
        ),
      ];

      // Insert sessions in random order
      for (final session in sessions) {
        await repository.createSession(session);
      }

      // Retrieve recent sessions
      final retrieved = await repository.getRecentSessions();

      // Verify they are ordered by start_time DESC
      expect(retrieved.length, equals(3));
      expect(retrieved[0].strokeFocus, equals('backhand')); // Most recent
      expect(retrieved[1].strokeFocus, equals('smash'));
      expect(retrieved[2].strokeFocus, equals('forehand')); // Oldest

      // Verify timestamps are in descending order
      for (int i = 0; i < retrieved.length - 1; i++) {
        expect(
          retrieved[i].startTime.isAfter(retrieved[i + 1].startTime) ||
              retrieved[i]
                  .startTime
                  .isAtSameMomentAs(retrieved[i + 1].startTime),
          isTrue,
          reason:
              'Session at index $i should have timestamp >= session at index ${i + 1}',
        );
      }
    });

    test('getRecentSessions with limit respects ordering', () async {
      final now = DateTime.now();

      // Create 5 sessions
      for (int i = 0; i < 5; i++) {
        await repository.createSession(SessionEntity(
          userId: 'user1',
          startTime: now.subtract(Duration(hours: i)),
          deviceId: 'device1',
          strokeFocus: 'stroke_$i',
          createdAt: now.subtract(Duration(hours: i)),
        ));
      }

      // Get top 3 most recent
      final retrieved = await repository.getRecentSessions(limit: 3);

      expect(retrieved.length, equals(3));
      expect(retrieved[0].strokeFocus, equals('stroke_0')); // Most recent
      expect(retrieved[1].strokeFocus, equals('stroke_1'));
      expect(retrieved[2].strokeFocus, equals('stroke_2'));
    });

    test('empty database returns empty list in correct order', () async {
      final retrieved = await repository.getRecentSessions();
      expect(retrieved, isEmpty);
    });

    test('single session maintains ordering', () async {
      final now = DateTime.now();
      await repository.createSession(SessionEntity(
        userId: 'user1',
        startTime: now,
        deviceId: 'device1',
        strokeFocus: 'forehand',
        createdAt: now,
      ));

      final retrieved = await repository.getRecentSessions();
      expect(retrieved.length, equals(1));
      expect(retrieved[0].strokeFocus, equals('forehand'));
    });
  });
}
