import 'package:flutter_test/flutter_test.dart';
import 'package:flying_birdies/core/exceptions.dart';

/// Feature: backend-refactor-frontend-integration, Property 24: Error Context
/// For any error that occurs, the error object should include context information
/// such as operation type and relevant identifiers.
/// Validates: Requirements 7.5
void main() {
  group('Error Context Property Tests', () {
    test('Property 24: All exceptions include operation type and identifiers',
        () {
      // Test that every exception type includes proper context
      for (var i = 0; i < 100; i++) {
        final sessionId = i + 1;
        final userId = 'user_$i';
        final deviceId = 'device_$i';

        // Test DatabaseException context
        final dbException = DatabaseException(
          'Database operation failed',
          'insert',
          context: 'sessionId: $sessionId, userId: $userId',
          originalError: Exception('Connection timeout'),
        );

        expect(dbException.context, isNotNull);
        expect(dbException.context, contains('sessionId'));
        expect(dbException.context, contains(sessionId.toString()));
        expect(dbException.operation, equals('insert'));
        expect(dbException.originalError, isNotNull);

        // Test BleException context
        final bleException = BleException(
          'Connection failed',
          'connect',
          context: 'deviceId: $deviceId, attempt: $i',
          originalError: Exception('Timeout'),
        );

        expect(bleException.context, isNotNull);
        expect(bleException.context, contains('deviceId'));
        expect(bleException.context, contains(deviceId));
        expect(bleException.operation, equals('connect'));

        // Test SyncException context
        final syncException = SyncException(
          'Sync failed',
          context: 'sessionId: $sessionId, retryCount: $i',
          originalError: Exception('Network error'),
        );

        expect(syncException.context, isNotNull);
        expect(syncException.context, contains('sessionId'));
        expect(syncException.context, contains('retryCount'));

        // Test AnalyticsException context
        final analyticsException = AnalyticsException(
          'Processing failed',
          context: 'readingIndex: $i, timestamp: ${DateTime.now()}',
          originalError: Exception('Invalid data'),
        );

        expect(analyticsException.context, isNotNull);
        expect(analyticsException.context, contains('readingIndex'));
      }
    });

    test('Exception toString includes all context information', () {
      for (var i = 0; i < 100; i++) {
        final exception = DatabaseException(
          'Test error $i',
          'test_operation',
          context: 'id: $i, type: test',
          originalError: Exception('Original $i'),
        );

        final exceptionString = exception.toString();

        // Verify all context is in string representation
        expect(exceptionString, contains('Test error $i'));
        expect(exceptionString, contains('test_operation'));
        expect(exceptionString, contains('id: $i'));
        expect(exceptionString, contains('type: test'));
        expect(exceptionString, contains('Original $i'));
      }
    });

    test('Exceptions with null context still provide operation info', () {
      for (var i = 0; i < 100; i++) {
        final exception = DatabaseException(
          'Error without context',
          'operation_$i',
        );

        // Even without context, operation type should be available
        expect(exception.operation, equals('operation_$i'));
        expect(exception.message, isNotEmpty);

        final exceptionString = exception.toString();
        expect(exceptionString, contains('operation_$i'));
      }
    });

    test('Original error is preserved through exception chain', () {
      for (var i = 0; i < 100; i++) {
        final originalError = Exception('Root cause $i');
        final exception = SyncException(
          'Sync failed',
          context: 'attempt: $i',
          originalError: originalError,
        );

        expect(exception.originalError, equals(originalError));
        expect(exception.toString(), contains('Root cause $i'));
      }
    });

    test('Stack traces are preserved when provided', () {
      for (var i = 0; i < 100; i++) {
        try {
          // Generate a stack trace
          throw Exception('Test $i');
        } catch (e, stackTrace) {
          final exception = BleException(
            'BLE error',
            'test_operation',
            context: 'iteration: $i',
            originalError: e,
            stackTrace: stackTrace,
          );

          expect(exception.stackTrace, isNotNull);
          expect(exception.stackTrace, equals(stackTrace));
        }
      }
    });
  });
}
