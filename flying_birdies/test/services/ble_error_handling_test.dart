import 'package:flutter_test/flutter_test.dart';
import 'package:flying_birdies/services/ble_service.dart';
import 'package:flying_birdies/core/logger.dart';
import 'package:flying_birdies/core/exceptions.dart';

/// Feature: backend-refactor-frontend-integration, Property 22: BLE Error Handling
/// All BLE operations must throw BleException with proper context on failure.
/// Validates: Requirements 7.2
void main() {
  group('Property 22: BLE Error Handling', () {
    late BleService bleService;
    late ILogger logger;

    setUp(() {
      logger = ConsoleLogger('BleErrorHandlingTest');
      bleService = BleService(logger);
    });

    tearDown(() {
      bleService.dispose();
    });

    test(
        'Property 22: startDataCollection throws BleException when not connected',
        () async {
      // Attempt to start data collection without connection
      expect(
        () => bleService.startDataCollection(),
        throwsA(isA<BleException>()),
      );
    }, skip: 'Requires platform-specific BLE initialization');

    test('Property 22: BleException contains operation context', () async {
      try {
        await bleService.startDataCollection();
        fail('Should have thrown BleException');
      } on BleException catch (e) {
        // Verify exception has proper structure
        expect(e.message, isNotEmpty);
        expect(e.operation, equals('startDataCollection'));
        expect(e.toString(), contains('BleException'));
      }
    }, skip: 'Requires platform-specific BLE initialization');

    test('Property 22: Multiple failed operations throw consistent exceptions',
        () async {
      for (int i = 0; i < 100; i++) {
        try {
          await bleService.startDataCollection();
          fail('Should have thrown BleException');
        } on BleException catch (e) {
          expect(e.operation, equals('startDataCollection'));
          expect(e.message, contains('no device connected'));
        }
      }
    }, skip: 'Requires platform-specific BLE initialization');

    test('Property 22: Exception message is descriptive', () async {
      try {
        await bleService.startDataCollection();
        fail('Should have thrown BleException');
      } on BleException catch (e) {
        // Message should explain the problem
        expect(e.message.toLowerCase(), contains('device'));
        expect(e.message.toLowerCase(), contains('connect'));
      }
    }, skip: 'Requires platform-specific BLE initialization');

    test('Property 22: stopDataCollection is safe when not connected', () {
      // Should not throw even when not connected
      expect(() => bleService.stopDataCollection(), returnsNormally);

      // Call multiple times
      for (int i = 0; i < 100; i++) {
        expect(() => bleService.stopDataCollection(), returnsNormally);
      }
    }, skip: 'Requires platform-specific BLE initialization');

    test('Property 22: Scan timeout is handled gracefully', () async {
      // Scan with very short timeout
      final deviceStream = bleService.scanForDevices(
        timeout: const Duration(milliseconds: 1),
      );

      final devices = <dynamic>[];
      await for (final device in deviceStream) {
        devices.add(device);
      }

      // Should complete without throwing
      // (may or may not find devices in 1ms)
    }, skip: 'Requires platform-specific BLE initialization');

    test('Property 22: Permission request handles errors', () async {
      // Request permissions (may succeed or fail depending on platform)
      try {
        final result = await bleService.requestPermissions();
        expect(result, isA<bool>());
      } on BleException catch (e) {
        // If it throws, should be BleException
        expect(e.operation, equals('permissions'));
      }
    });

    test('Property 22: Dispose is safe to call multiple times', () {
      // Should not throw
      expect(() => bleService.dispose(), returnsNormally);
      expect(() => bleService.dispose(), returnsNormally);
      expect(() => bleService.dispose(), returnsNormally);
    });

    test('Property 22: Operations after dispose are safe', () {
      bleService.dispose();

      // These should not crash
      expect(() => bleService.stopDataCollection(), returnsNormally);
      expect(bleService.isConnected, isFalse);
      expect(bleService.currentState, isNotNull);
    });
  });
}
