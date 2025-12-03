import 'package:flutter_test/flutter_test.dart';
import 'package:flying_birdies/core/logger.dart';
import 'package:flying_birdies/data/database_helper.dart';
import 'package:flying_birdies/data/repositories/session_repository.dart';
import 'package:flying_birdies/data/repositories/swing_repository.dart';
import 'package:flying_birdies/models/entities/session_entity.dart';
import 'package:flying_birdies/models/entities/swing_entity.dart';
import '../helpers/test_database_helper.dart';

/// Property 28: Transaction Rollback
/// Database transactions must rollback completely on error
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Property 28: Transaction Rollback', () {
    late DatabaseHelper dbHelper;
    late SessionRepository sessionRepo;
    late SwingRepository swingRepo;
    late ILogger logger;

    setUp(() async {
      // Create isolated test database
      dbHelper = await TestDatabaseHelper.createTestDatabase();
      logger = ConsoleLogger('TransactionRollbackTest');
      sessionRepo = SessionRepository(dbHelper, logger);
      swingRepo = SwingRepository(dbHelper, logger);
    });

    tearDown() async {
      await TestDatabaseHelper.cleanupTestDatabase(dbHelper);
    });

    test('transaction rollback leaves database unchanged on error', () async {
      final now = DateTime.now();

      // Create initial session
      await sessionRepo.createSession(SessionEntity(
        userId: 'user1',
        startTime: now,
        deviceId: 'device1',
        strokeFocus: 'forehand',
        createdAt: now,
      ));

      // Verify initial state
      final initialSessions = await sessionRepo.getRecentSessions();
      expect(initialSessions.length, equals(1));

      // Attempt transaction that will fail
      try {
        await dbHelper.transaction((txn) async {
          // Insert a valid session
          await txn.insert('sessions', {
            'user_id': 'user2',
            'start_time': now.millisecondsSinceEpoch,
            'device_id': 'device2',
            'stroke_focus': 'backhand',
            'created_at': now.millisecondsSinceEpoch,
          });

          // Force an error by inserting invalid data
          await txn.insert('sessions', {
            'user_id': 'user3',
            'start_time': 'invalid_timestamp', // This will cause an error
            'device_id': 'device3',
            'stroke_focus': 'smash',
            'created_at': now.millisecondsSinceEpoch,
          });
        });
        fail('Transaction should have thrown an error');
      } catch (e) {
        // Expected to fail
      }

      // Verify database state is unchanged (rollback occurred)
      final finalSessions = await sessionRepo.getRecentSessions();
      expect(finalSessions.length, equals(1));
      expect(finalSessions[0].userId, equals('user1'));
    });

    test('transaction rollback with multiple table operations', () async {
      final now = DateTime.now();

      // Create initial session and swing
      final sessionId = await sessionRepo.createSession(SessionEntity(
        userId: 'user1',
        startTime: now,
        deviceId: 'device1',
        strokeFocus: 'forehand',
        createdAt: now,
      ));

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

      // Verify initial state
      final initialSessions = await sessionRepo.getRecentSessions();
      final initialSwings = await swingRepo.getSwingsForSession(sessionId);
      expect(initialSessions.length, equals(1));
      expect(initialSwings.length, equals(1));

      // Attempt transaction affecting both tables
      try {
        await dbHelper.transaction((txn) async {
          // Insert a new session
          final newSessionId = await txn.insert('sessions', {
            'user_id': 'user2',
            'start_time': now.millisecondsSinceEpoch,
            'device_id': 'device2',
            'stroke_focus': 'backhand',
            'created_at': now.millisecondsSinceEpoch,
          });

          // Insert a swing for the new session
          await txn.insert('swings', {
            'session_id': newSessionId,
            'timestamp': now.millisecondsSinceEpoch,
            'max_omega': 110.0,
            'max_vtip': 55.0,
            'impact_amax': 22.0,
            'impact_severity': 0.6,
            'est_force_n': 160.0,
            'swing_duration_ms': 210,
            'quality_passed': 1,
          });

          // Force an error
          throw Exception('Simulated error');
        });
      } catch (e) {
        // Expected to fail
      }

      // Verify both tables are unchanged
      final finalSessions = await sessionRepo.getRecentSessions();
      final finalSwings = await swingRepo.getSwingsForSession(sessionId);
      expect(finalSessions.length, equals(1));
      expect(finalSwings.length, equals(1));
      expect(finalSessions[0].userId, equals('user1'));
    });

    test('successful transaction commits all changes', () async {
      final now = DateTime.now();

      // Execute successful transaction
      await dbHelper.transaction((txn) async {
        await txn.insert('sessions', {
          'user_id': 'user1',
          'start_time': now.millisecondsSinceEpoch,
          'device_id': 'device1',
          'stroke_focus': 'forehand',
          'created_at': now.millisecondsSinceEpoch,
        });

        await txn.insert('sessions', {
          'user_id': 'user2',
          'start_time': now.millisecondsSinceEpoch,
          'device_id': 'device2',
          'stroke_focus': 'backhand',
          'created_at': now.millisecondsSinceEpoch,
        });
      });

      // Verify both inserts were committed
      final sessions = await sessionRepo.getRecentSessions();
      expect(sessions.length, equals(2));
    });
  });
}
