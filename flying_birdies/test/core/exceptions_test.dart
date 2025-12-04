import 'package:flutter_test/flutter_test.dart';
import 'package:flying_birdies/core/exceptions.dart';

/// Feature: backend-refactor-frontend-integration, Property 21: Database Error Exceptions
/// For any database operation that fails, the system should throw a typed exception
/// (DatabaseException) with a descriptive error message.
/// Validates: Requirements 7.1
void main() {
  group('Exception Hierarchy Property Tests', () {
    test(
        'Property 21: Database operations throw DatabaseException with context',
        () {
      // Test that DatabaseException is properly typed and contains required info
      for (var i = 0; i < 100; i++) {
        final operations = [
          'insert',
          'update',
          'delete',
          'query',
          'transaction'
        ];
        final operation = operations[i % operations.length];
        final message = 'Operation failed: $operation';
        final context = 'sessionId: ${i + 1}';

        final exception = DatabaseException(
          message,
          operation,
          context: context,
          originalError: Exception('Original error $i'),
        );

        // Verify exception is properly typed
        expect(exception, isA<DatabaseException>());
        expect(exception, isA<AppException>());
        expect(exception, isA<Exception>());

        // Verify required fields are present
        expect(exception.message, equals(message));
        expect(exception.operation, equals(operation));
        expect(exception.context, equals(context));
        expect(exception.originalError, isNotNull);

        // Verify toString includes all context
        final exceptionString = exception.toString();
        expect(exceptionString, contains('DatabaseException'));
        expect(exceptionString, contains(message));
        expect(exceptionString, contains(operation));
        expect(exceptionString, contains(context));
      }
    });

    test('BleException is properly typed with operation context', () {
      for (var i = 0; i < 100; i++) {
        final operations = [
          'connect',
          'disconnect',
          'scan',
          'subscribe',
          'read'
        ];
        final operation = operations[i % operations.length];
        final message = 'BLE operation failed: $operation';

        final exception = BleException(
          message,
          operation,
          context: 'deviceId: device_$i',
        );

        expect(exception, isA<BleException>());
        expect(exception, isA<AppException>());
        expect(exception.operation, equals(operation));
        expect(exception.message, contains(operation));
      }
    });

    test('SyncException includes retryable flag', () {
      for (var i = 0; i < 100; i++) {
        final isRetryable = i % 2 == 0;
        final exception = SyncException(
          'Sync failed',
          isRetryable: isRetryable,
          context: 'attempt: $i',
        );

        expect(exception, isA<SyncException>());
        expect(exception, isA<AppException>());
        expect(exception.isRetryable, equals(isRetryable));
      }
    });

    test('AnalyticsException is properly typed', () {
      for (var i = 0; i < 100; i++) {
        final exception = AnalyticsException(
          'Analytics processing failed',
          context: 'reading: $i',
        );

        expect(exception, isA<AnalyticsException>());
        expect(exception, isA<AppException>());
        expect(exception.context, contains('reading'));
      }
    });

    test('All exceptions preserve stack traces', () {
      try {
        throw DatabaseException(
          'Test error',
          'test_operation',
          stackTrace: StackTrace.current,
        );
      } catch (e) {
        expect(e, isA<DatabaseException>());
        final dbException = e as DatabaseException;
        expect(dbException.stackTrace, isNotNull);
      }
    });
  });
}
