import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flying_birdies/state/connection_state_notifier.dart';

/// Feature: backend-refactor-frontend-integration, Property 10: Connection State Stream Emission
/// For any connection state change, the connection state stream should emit an event
/// with the new state.
/// Validates: Requirements 4.4
void main() {
  group('Connection State Stream Emission Property Tests', () {
    test('Property 10: Every state change emits a stream event', () async {
      for (var i = 0; i < 100; i++) {
        final notifier = ConnectionStateNotifier();
        final receivedEvents = <ConnectionEvent>[];

        final subscription = notifier.connectionEventStream.listen((event) {
          receivedEvents.add(event);
        });

        final states = [
          DeviceConnectionState.connecting,
          DeviceConnectionState.connected,
          DeviceConnectionState.disconnecting,
          DeviceConnectionState.disconnected,
        ];

        final testState = states[i % states.length];
        final deviceId = 'device_$i';
        final deviceName = 'Test Device $i';

        notifier.updateConnectionState(
          testState,
          deviceId: deviceId,
          deviceName: deviceName,
        );

        // Wait for stream to process
        await Future.delayed(const Duration(milliseconds: 10));

        // Verify event was emitted
        expect(receivedEvents.length, equals(1));
        expect(receivedEvents.first.state, equals(testState));
        expect(receivedEvents.first.deviceId, equals(deviceId));
        expect(receivedEvents.first.deviceName, equals(deviceName));
        expect(receivedEvents.first.timestamp, isNotNull);

        await subscription.cancel();
        notifier.dispose();
      }
    });

    test('Property 10: Multiple state changes emit multiple events', () async {
      final notifier = ConnectionStateNotifier();
      final receivedEvents = <ConnectionEvent>[];

      final subscription = notifier.connectionEventStream.listen((event) {
        receivedEvents.add(event);
      });

      // Emit 100 state changes
      for (var i = 0; i < 100; i++) {
        final state = i % 2 == 0
            ? DeviceConnectionState.connected
            : DeviceConnectionState.disconnected;

        notifier.updateConnectionState(
          state,
          deviceId: 'device_$i',
        );
      }

      // Wait for all events to process
      await Future.delayed(const Duration(milliseconds: 100));

      // Should have received 100 events
      expect(receivedEvents.length, equals(100));

      // Verify alternating states
      for (var i = 0; i < 100; i++) {
        final expectedState = i % 2 == 0
            ? DeviceConnectionState.connected
            : DeviceConnectionState.disconnected;
        expect(receivedEvents[i].state, equals(expectedState));
        expect(receivedEvents[i].deviceId, equals('device_$i'));
      }

      await subscription.cancel();
      notifier.dispose();
    });

    test('Property 10: Multiple subscribers all receive events', () async {
      for (var i = 0; i < 100; i++) {
        final notifier = ConnectionStateNotifier();
        final subscriber1Events = <ConnectionEvent>[];
        final subscriber2Events = <ConnectionEvent>[];
        final subscriber3Events = <ConnectionEvent>[];

        final sub1 = notifier.connectionEventStream.listen((event) {
          subscriber1Events.add(event);
        });

        final sub2 = notifier.connectionEventStream.listen((event) {
          subscriber2Events.add(event);
        });

        final sub3 = notifier.connectionEventStream.listen((event) {
          subscriber3Events.add(event);
        });

        final state = DeviceConnectionState.connected;
        notifier.updateConnectionState(state, deviceId: 'device_$i');

        await Future.delayed(const Duration(milliseconds: 10));

        // All subscribers should receive the event
        expect(subscriber1Events.length, equals(1));
        expect(subscriber2Events.length, equals(1));
        expect(subscriber3Events.length, equals(1));

        expect(subscriber1Events.first.state, equals(state));
        expect(subscriber2Events.first.state, equals(state));
        expect(subscriber3Events.first.state, equals(state));

        await sub1.cancel();
        await sub2.cancel();
        await sub3.cancel();
        notifier.dispose();
      }
    });

    test('Property 10: Events include timestamp', () async {
      for (var i = 0; i < 100; i++) {
        final notifier = ConnectionStateNotifier();
        final receivedEvents = <ConnectionEvent>[];

        final subscription = notifier.connectionEventStream.listen((event) {
          receivedEvents.add(event);
        });

        final beforeUpdate = DateTime.now();
        notifier.updateConnectionState(
          DeviceConnectionState.connected,
          deviceId: 'device_$i',
        );
        final afterUpdate = DateTime.now();

        await Future.delayed(const Duration(milliseconds: 10));

        expect(receivedEvents.length, equals(1));
        final event = receivedEvents.first;

        // Timestamp should be between before and after
        expect(
          event.timestamp
              .isAfter(beforeUpdate.subtract(const Duration(seconds: 1))),
          isTrue,
        );
        expect(
          event.timestamp.isBefore(afterUpdate.add(const Duration(seconds: 1))),
          isTrue,
        );

        await subscription.cancel();
        notifier.dispose();
      }
    });

    test('Property 10: Stream is broadcast and supports multiple listeners',
        () async {
      final notifier = ConnectionStateNotifier();

      // Should be able to add multiple listeners without error
      final sub1 = notifier.connectionEventStream.listen((_) {});
      final sub2 = notifier.connectionEventStream.listen((_) {});
      final sub3 = notifier.connectionEventStream.listen((_) {});

      // Emit events
      for (var i = 0; i < 100; i++) {
        notifier.updateConnectionState(
          DeviceConnectionState.connected,
          deviceId: 'device_$i',
        );
      }

      await Future.delayed(const Duration(milliseconds: 100));

      // Clean up
      await sub1.cancel();
      await sub2.cancel();
      await sub3.cancel();
      notifier.dispose();
    });
  });
}
