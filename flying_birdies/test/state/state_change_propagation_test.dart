import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flying_birdies/state/connection_state_notifier.dart';
import 'package:flying_birdies/state/session_state_notifier.dart';
import 'package:flying_birdies/state/swing_data_notifier.dart';
import 'package:flying_birdies/models/swing_metrics.dart';

/// Feature: backend-refactor-frontend-integration, Property 1: State Change Propagation
/// For any state change in a service, all subscribed listeners should receive
/// notification of the change within a reasonable time frame.
/// Validates: Requirements 1.3
void main() {
  group('State Change Propagation Property Tests', () {
    test('Property 1: ConnectionStateNotifier propagates all state changes',
        () async {
      for (var i = 0; i < 100; i++) {
        final notifier = ConnectionStateNotifier();
        final receivedNotifications = <DeviceConnectionState>[];
        var listenerCallCount = 0;

        // Add listener
        notifier.addListener(() {
          listenerCallCount++;
          receivedNotifications.add(notifier.state);
        });

        // Cycle through different connection states
        final states = [
          DeviceConnectionState.connecting,
          DeviceConnectionState.connected,
          DeviceConnectionState.disconnecting,
          DeviceConnectionState.disconnected,
        ];

        final testState = states[i % states.length];
        notifier.updateConnectionState(
          testState,
          deviceId: 'device_$i',
          deviceName: 'Device $i',
        );

        // Verify listener was called
        expect(listenerCallCount, equals(1));
        expect(receivedNotifications, contains(testState));
        expect(notifier.state, equals(testState));

        notifier.dispose();
      }
    });

    test('Property 1: SessionStateNotifier propagates session events',
        () async {
      for (var i = 0; i < 100; i++) {
        final notifier = SessionStateNotifier();
        var listenerCallCount = 0;

        notifier.addListener(() {
          listenerCallCount++;
        });

        // Start session
        notifier.startSession(i + 1);
        expect(listenerCallCount, equals(1));
        expect(notifier.activeSessionId, equals(i + 1));
        expect(notifier.hasActiveSession, isTrue);

        // End session
        notifier.endSession();
        expect(listenerCallCount, equals(2));
        expect(notifier.activeSessionId, isNull);
        expect(notifier.hasActiveSession, isFalse);

        notifier.dispose();
      }
    });

    test('Property 1: SwingDataNotifier propagates swing additions', () async {
      for (var i = 0; i < 100; i++) {
        final notifier = SwingDataNotifier();
        var listenerCallCount = 0;

        notifier.addListener(() {
          listenerCallCount++;
        });

        final swing = SwingMetrics(
          timestamp: DateTime.now(),
          maxOmega: 10.0 + i,
          maxVtip: 20.0 + i,
          impactAmax: 30.0 + i,
          impactSeverity: 5.0,
          estForceN: 100.0 + i,
          swingDurationMs: 200,
          qualityPassed: true,
        );

        notifier.addSwing(swing);

        expect(listenerCallCount, equals(1));
        expect(notifier.latestSwing, equals(swing));
        expect(notifier.swingCount, equals(1));

        notifier.dispose();
      }
    });

    test('Property 1: Multiple listeners all receive notifications', () async {
      for (var i = 0; i < 100; i++) {
        final notifier = ConnectionStateNotifier();
        final listener1Calls = <DeviceConnectionState>[];
        final listener2Calls = <DeviceConnectionState>[];
        final listener3Calls = <DeviceConnectionState>[];

        notifier.addListener(() => listener1Calls.add(notifier.state));
        notifier.addListener(() => listener2Calls.add(notifier.state));
        notifier.addListener(() => listener3Calls.add(notifier.state));

        final state = i % 2 == 0
            ? DeviceConnectionState.connected
            : DeviceConnectionState.disconnected;

        notifier.updateConnectionState(state, deviceId: 'device_$i');

        // All listeners should receive the notification
        expect(listener1Calls.length, equals(1));
        expect(listener2Calls.length, equals(1));
        expect(listener3Calls.length, equals(1));

        expect(listener1Calls.first, equals(state));
        expect(listener2Calls.first, equals(state));
        expect(listener3Calls.first, equals(state));

        notifier.dispose();
      }
    });

    test('Property 1: Stream subscribers receive events', () async {
      for (var i = 0; i < 100; i++) {
        final notifier = ConnectionStateNotifier();
        final receivedEvents = <ConnectionEvent>[];

        final subscription = notifier.connectionEventStream.listen((event) {
          receivedEvents.add(event);
        });

        final state = DeviceConnectionState.connected;
        notifier.updateConnectionState(
          state,
          deviceId: 'device_$i',
          deviceName: 'Device $i',
        );

        // Wait for stream to process
        await Future.delayed(const Duration(milliseconds: 10));

        expect(receivedEvents.length, equals(1));
        expect(receivedEvents.first.state, equals(state));
        expect(receivedEvents.first.deviceId, equals('device_$i'));

        await subscription.cancel();
        notifier.dispose();
      }
    });

    test('Property 1: Rapid state changes all propagate', () async {
      final notifier = SessionStateNotifier();
      var notificationCount = 0;

      notifier.addListener(() {
        notificationCount++;
      });

      // Rapidly change state 100 times
      for (var i = 0; i < 100; i++) {
        notifier.startSession(i + 1);
        notifier.endSession();
      }

      // Should have received 200 notifications (100 starts + 100 ends)
      expect(notificationCount, equals(200));

      notifier.dispose();
    });
  });
}
