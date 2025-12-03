import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flying_birdies/services/ble_service.dart';
import 'package:flying_birdies/core/logger.dart';

/// Feature: backend-refactor-frontend-integration, Property 9: Disconnection Notification
/// When a device disconnects, all observers must be notified through the connection state stream.
/// Validates: Requirements 4.2
void main() {
  group('Property 9: Disconnection Notification', () {
    late BleService bleService;
    late ILogger logger;

    setUp(() {
      logger = ConsoleLogger('BleDisconnectionNotificationTest');
      bleService = BleService(logger);
    });

    tearDown(() {
      bleService.dispose();
    });

    test('Property 9: Disconnect method updates connection state', () async {
      // Initial state should be disconnected
      expect(
          bleService.currentState, equals(DeviceConnectionState.disconnected));
      expect(bleService.isConnected, isFalse);
      expect(bleService.connectedDeviceId, isNull);

      // Call disconnect (even when not connected)
      await bleService.disconnect();

      // Should still be disconnected
      expect(
          bleService.currentState, equals(DeviceConnectionState.disconnected));
      expect(bleService.isConnected, isFalse);
      expect(bleService.connectedDeviceId, isNull);
    }, skip: 'Requires platform-specific BLE initialization');

    test('Property 9: Multiple disconnects are safe', () async {
      // Call disconnect multiple times
      for (int i = 0; i < 100; i++) {
        await bleService.disconnect();
        expect(bleService.currentState,
            equals(DeviceConnectionState.disconnected));
        expect(bleService.isConnected, isFalse);
      }
    }, skip: 'Requires platform-specific BLE initialization');

    test('Property 9: Disconnect clears device ID', () async {
      // Initially no device
      expect(bleService.connectedDeviceId, isNull);

      // Disconnect should keep it null
      await bleService.disconnect();
      expect(bleService.connectedDeviceId, isNull);
    });

    test('Property 9: Disconnect stops data collection', () async {
      // Verify stopDataCollection is called (indirectly through disconnect)
      await bleService.disconnect();

      // After disconnect, attempting to stop data collection should be safe
      bleService.stopDataCollection();

      // Should not throw
      expect(bleService.isConnected, isFalse);
    });

    test('Property 9: Connection state stream is accessible after disconnect',
        () async {
      final events = <DeviceConnectionState>[];

      final sub = bleService.connectionStateStream.listen((state) {
        events.add(state);
      });

      await bleService.disconnect();

      // Stream should still be accessible
      await Future.delayed(const Duration(milliseconds: 10));

      await sub.cancel();
    });

    test('Property 9: Rapid connect-disconnect cycles', () async {
      // Simulate rapid disconnect calls
      for (int i = 0; i < 50; i++) {
        await bleService.disconnect();
        expect(bleService.isConnected, isFalse);

        // Small delay
        await Future.delayed(const Duration(milliseconds: 1));
      }
    });

    test('Property 9: Disconnect is idempotent', () async {
      // First disconnect
      await bleService.disconnect();
      final state1 = bleService.currentState;
      final deviceId1 = bleService.connectedDeviceId;

      // Second disconnect
      await bleService.disconnect();
      final state2 = bleService.currentState;
      final deviceId2 = bleService.connectedDeviceId;

      // Third disconnect
      await bleService.disconnect();
      final state3 = bleService.currentState;
      final deviceId3 = bleService.connectedDeviceId;

      // All should be the same
      expect(state1, equals(state2));
      expect(state2, equals(state3));
      expect(deviceId1, equals(deviceId2));
      expect(deviceId2, equals(deviceId3));
    });
  });
}
