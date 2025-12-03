import 'package:flutter_test/flutter_test.dart';
import 'package:flying_birdies/models/entities/session_entity.dart';
import 'package:flying_birdies/models/entities/swing_entity.dart';

/// Feature: backend-refactor-frontend-integration, Property 27: Domain Model Returns
/// For any database query, the repository should return domain model objects
/// rather than raw Map<String, dynamic>.
/// Validates: Requirements 9.3
void main() {
  group('Domain Model Returns Property Tests', () {
    test('Property 27: SessionEntity converts to/from Map correctly', () {
      for (var i = 0; i < 100; i++) {
        final entity = SessionEntity(
          id: i + 1,
          userId: 'user_$i',
          startTime: DateTime.now().subtract(Duration(hours: i)),
          endTime: i % 2 == 0 ? DateTime.now() : null,
          deviceId: 'device_$i',
          strokeFocus: 'Overhead Forehand',
          cloudSessionId: i % 3 == 0 ? 'cloud_$i' : null,
          synced: i % 2 == 0,
          createdAt: DateTime.now().subtract(Duration(days: i)),
        );

        // Convert to map (database representation)
        final map = entity.toMap();

        // Verify map contains expected keys
        expect(map, isA<Map<String, dynamic>>());
        expect(map['id'], equals(i + 1));
        expect(map['user_id'], equals('user_$i'));
        expect(map['device_id'], equals('device_$i'));

        // Convert back to entity (domain model)
        final reconstructed = SessionEntity.fromMap(map);

        // Verify domain model is returned, not raw map
        expect(reconstructed, isA<SessionEntity>());
        expect(reconstructed, isNot(isA<Map>()));

        // Verify all fields match
        expect(reconstructed.id, equals(entity.id));
        expect(reconstructed.userId, equals(entity.userId));
        // DateTime comparison - milliseconds precision only
        expect(reconstructed.startTime.millisecondsSinceEpoch,
            equals(entity.startTime.millisecondsSinceEpoch));
        expect(reconstructed.endTime?.millisecondsSinceEpoch,
            equals(entity.endTime?.millisecondsSinceEpoch));
        expect(reconstructed.deviceId, equals(entity.deviceId));
        expect(reconstructed.strokeFocus, equals(entity.strokeFocus));
        expect(reconstructed.cloudSessionId, equals(entity.cloudSessionId));
        expect(reconstructed.synced, equals(entity.synced));
      }
    });

    test('Property 27: SwingEntity converts to/from Map correctly', () {
      for (var i = 0; i < 100; i++) {
        final entity = SwingEntity(
          id: i + 1,
          sessionId: (i % 10) + 1,
          timestamp: DateTime.now().subtract(Duration(minutes: i)),
          maxOmega: 10.0 + i * 0.1,
          maxVtip: 20.0 + i * 0.2,
          impactAmax: 30.0 + i * 0.3,
          impactSeverity: 5.0 + i * 0.05,
          estForceN: 100.0 + i,
          swingDurationMs: 200 + i,
          qualityPassed: i % 2 == 0,
          shuttleSpeedOut: i % 3 == 0 ? 25.0 + i * 0.1 : null,
          forceStandardized: i % 3 == 0 ? 120.0 + i : null,
          synced: i % 4 == 0,
        );

        // Convert to map
        final map = entity.toMap();

        // Verify map structure
        expect(map, isA<Map<String, dynamic>>());
        expect(map['id'], equals(i + 1));
        expect(map['session_id'], equals((i % 10) + 1));

        // Convert back to entity
        final reconstructed = SwingEntity.fromMap(map);

        // Verify domain model is returned
        expect(reconstructed, isA<SwingEntity>());
        expect(reconstructed, isNot(isA<Map>()));

        // Verify all fields match
        expect(reconstructed.id, equals(entity.id));
        expect(reconstructed.sessionId, equals(entity.sessionId));
        // DateTime comparison - milliseconds precision only
        expect(reconstructed.timestamp.millisecondsSinceEpoch,
            equals(entity.timestamp.millisecondsSinceEpoch));
        expect(reconstructed.maxOmega, equals(entity.maxOmega));
        expect(reconstructed.maxVtip, equals(entity.maxVtip));
        expect(reconstructed.impactAmax, equals(entity.impactAmax));
        expect(reconstructed.impactSeverity, equals(entity.impactSeverity));
        expect(reconstructed.estForceN, equals(entity.estForceN));
        expect(reconstructed.swingDurationMs, equals(entity.swingDurationMs));
        expect(reconstructed.qualityPassed, equals(entity.qualityPassed));
        expect(reconstructed.shuttleSpeedOut, equals(entity.shuttleSpeedOut));
        expect(
            reconstructed.forceStandardized, equals(entity.forceStandardized));
        expect(reconstructed.synced, equals(entity.synced));
      }
    });

    test('Property 27: Entities support equality comparison', () {
      for (var i = 0; i < 100; i++) {
        final entity1 = SessionEntity(
          id: i + 1,
          userId: 'user_$i',
          startTime: DateTime(2024, 1, 1, 10, 0),
          deviceId: 'device_$i',
        );

        final entity2 = SessionEntity(
          id: i + 1,
          userId: 'user_$i',
          startTime: DateTime(2024, 1, 1, 10, 0),
          deviceId: 'device_$i',
        );

        // Same values should be equal
        expect(entity1, equals(entity2));
        expect(entity1.hashCode, equals(entity2.hashCode));

        // Different values should not be equal
        final entity3 = SessionEntity(
          id: i + 2,
          userId: 'user_$i',
          startTime: DateTime(2024, 1, 1, 10, 0),
          deviceId: 'device_$i',
        );

        expect(entity1, isNot(equals(entity3)));
      }
    });

    test('Property 27: Entities support copyWith for immutability', () {
      for (var i = 0; i < 100; i++) {
        final original = SessionEntity(
          id: i + 1,
          userId: 'user_$i',
          startTime: DateTime.now(),
          deviceId: 'device_$i',
          synced: false,
        );

        // Create modified copy
        final modified = original.copyWith(
          synced: true,
          cloudSessionId: 'cloud_$i',
        );

        // Original should be unchanged
        expect(original.synced, isFalse);
        expect(original.cloudSessionId, isNull);

        // Modified should have new values
        expect(modified.synced, isTrue);
        expect(modified.cloudSessionId, equals('cloud_$i'));

        // Other fields should match
        expect(modified.id, equals(original.id));
        expect(modified.userId, equals(original.userId));
        expect(modified.deviceId, equals(original.deviceId));
      }
    });

    test('Property 27: Entities handle null values correctly', () {
      for (var i = 0; i < 100; i++) {
        // Create entity with null optional fields
        final entity = SessionEntity(
          startTime: DateTime.now(),
          userId: i % 2 == 0 ? 'user_$i' : null,
          endTime: i % 3 == 0 ? DateTime.now() : null,
          deviceId: i % 4 == 0 ? 'device_$i' : null,
          strokeFocus: i % 5 == 0 ? 'Overhead' : null,
          cloudSessionId: i % 6 == 0 ? 'cloud_$i' : null,
        );

        // Convert to map and back
        final map = entity.toMap();
        final reconstructed = SessionEntity.fromMap(map);

        // Verify nulls are preserved
        expect(reconstructed.userId, equals(entity.userId));
        // DateTime comparison - milliseconds precision only
        expect(reconstructed.endTime?.millisecondsSinceEpoch,
            equals(entity.endTime?.millisecondsSinceEpoch));
        expect(reconstructed.deviceId, equals(entity.deviceId));
        expect(reconstructed.strokeFocus, equals(entity.strokeFocus));
        expect(reconstructed.cloudSessionId, equals(entity.cloudSessionId));
      }
    });

    test('Property 27: Entities have meaningful toString', () {
      for (var i = 0; i < 100; i++) {
        final entity = SessionEntity(
          id: i + 1,
          userId: 'user_$i',
          startTime: DateTime.now(),
          deviceId: 'device_$i',
        );

        final stringRep = entity.toString();

        // Should contain class name and key fields
        expect(stringRep, contains('SessionEntity'));
        expect(stringRep, contains('id: ${i + 1}'));
        expect(stringRep, contains('user_$i'));
        expect(stringRep, contains('device_$i'));
      }
    });
  });
}
