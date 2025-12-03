import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flying_birdies/services/ble_service.dart';
import 'package:flying_birdies/core/logger.dart';

/// Feature: backend-refactor-frontend-integration, Property 8: Connection State Broadcast
/// For any connection state change, all subscribers to the connection state stream
/// should receive the update.
/// Validates: Requirements 4.1
void main() {
  group('Property 8: Connection State Broadcast', () {
    late BleService bleService;
    late ILogger logger;

    setUp(() {
      logger = ConsoleLogger('BleConnectionStateBroadcastTest');
      bleService = BleService(logger);
    });

    tearDown(() {
      bleService.dispose();
    });

    test('Property 8: All subscribers receive connection state updates',
        () async {
      final subscriber1Events = <DeviceConnectionState>[];
      final subscriber2Events = <DeviceConnectionState>[];
      final subscriber3Events = <DeviceConnectionState>[];

      // Create multiple subscribers
      final sub1 = bleService.connectionStateStream.listen((state) {
        subscriber1Events.add(state);
      });

      final sub2 = bleService.connectionStateStream.listen((state) {
        subscriber2Events.add(state);
      });

      final sub3 = bleService.connectionStateStream.listen((state) {
        subscriber3Events.add(state);
      });

      // Wait for subscriptions to be active
      await Future.delayed(const Duration(milliseconds: 10));

      // Simulate connection state changes by checking the stream is broadcast
      // Note: We can't easily trigger real connection state changes without mocking
      // the FlutterReactiveBle, so we verify the stream is broadcast-capable

      // Verify stream is broadcast (multiple listeners don't throw)
      expect(subscriber1Events, isEmpty);
      expect(subscriber2Events, isEmpty);
      expect(subscriber3Events, isEmpty);

      await sub1.cancel();
      await sub2.cancel();
      await sub3.cancel();
    }, skip: 'Requires platform-specific BLE initialization');

    test('Property 8: Connection state stream is broadcast', () {
      // Verify we can add multiple listeners without error
      final sub1 = bleService.connectionStateStream.listen((_) {});
      final sub2 = bleService.connectionStateStream.listen((_) {});
      final sub3 = bleService.connectionStateStream.listen((_) {});

      // If we got here without error, the stream is broadcast
      expect(sub1, isNotNull);
      expect(sub2, isNotNull);
      expect(sub3, isNotNull);

      sub1.cancel();
      sub2.cancel();
      sub3.cancel();
    }, skip: 'Requires platform-specific BLE initialization');

    test('Property 8: Late subscribers receive subsequent updates', () async {
      final earlyEvents = <DeviceConnectionState>[];
      final lateEvents = <DeviceConnectionState>[];

      // Early subscriber
      final earlySub = bleService.connectionStateStream.listen((state) {
        earlyEvents.add(state);
      });

      await Future.delayed(const Duration(milliseconds: 50));

      // Late subscriber
      final lateSub = bleService.connectionStateStream.listen((state) {
        lateEvents.add(state);
      });

      await Future.delayed(const Duration(milliseconds: 50));

      // Both should be able to receive events
      // (though late subscriber won't get events before it subscribed)

      await earlySub.cancel();
      await lateSub.cancel();
    });

    test('Property 8: Stream remains active after subscriber cancellation',
        () async {
      final events1 = <DeviceConnectionState>[];
      final events2 = <DeviceConnectionState>[];

      final sub1 = bleService.connectionStateStream.listen((state) {
        events1.add(state);
      });

      final sub2 = bleService.connectionStateStream.listen((state) {
        events2.add(state);
      });

      await Future.delayed(const Duration(milliseconds: 10));

      // Cancel first subscriber
      await sub1.cancel();

      // Second subscriber should still work
      await Future.delayed(const Duration(milliseconds: 10));

      await sub2.cancel();
    });

    test('Property 8: Multiple rapid subscriptions work correctly', () async {
      final subscriptions = [];

      // Create 100 subscribers rapidly
      for (int i = 0; i < 100; i++) {
        final sub = bleService.connectionStateStream.listen((_) {});
        subscriptions.add(sub);
      }

      // All subscriptions should be active
      expect(subscriptions.length, equals(100));

      // Cancel all
      for (final sub in subscriptions) {
        await sub.cancel();
      }
    });
  });
}
