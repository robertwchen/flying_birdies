/// Base exception class for all app-specific exceptions
abstract class AppException implements Exception {
  final String message;
  final String? context;
  final dynamic originalError;
  final StackTrace? stackTrace;

  AppException(
    this.message, {
    this.context,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('$runtimeType: $message');
    if (context != null) {
      buffer.write('\nContext: $context');
    }
    if (originalError != null) {
      buffer.write('\nOriginal error: $originalError');
    }
    return buffer.toString();
  }
}

/// Exception thrown when database operations fail
class DatabaseException extends AppException {
  final String operation;

  DatabaseException(
    String message,
    this.operation, {
    String? context,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message,
          context: context,
          originalError: originalError,
          stackTrace: stackTrace,
        );

  @override
  String toString() {
    return 'DatabaseException: $message (operation: $operation)'
        '${context != null ? '\nContext: $context' : ''}'
        '${originalError != null ? '\nOriginal error: $originalError' : ''}';
  }
}

/// Exception thrown when BLE operations fail
class BleException extends AppException {
  final String operation;

  BleException(
    String message,
    this.operation, {
    String? context,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message,
          context: context,
          originalError: originalError,
          stackTrace: stackTrace,
        );

  @override
  String toString() {
    return 'BleException: $message (operation: $operation)'
        '${context != null ? '\nContext: $context' : ''}'
        '${originalError != null ? '\nOriginal error: $originalError' : ''}';
  }
}

/// Exception thrown when sync operations fail
class SyncException extends AppException {
  final bool isRetryable;

  SyncException(
    String message, {
    this.isRetryable = true,
    String? context,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message,
          context: context,
          originalError: originalError,
          stackTrace: stackTrace,
        );

  @override
  String toString() {
    return 'SyncException: $message (retryable: $isRetryable)'
        '${context != null ? '\nContext: $context' : ''}'
        '${originalError != null ? '\nOriginal error: $originalError' : ''}';
  }
}

/// Exception thrown when analytics operations fail
class AnalyticsException extends AppException {
  AnalyticsException(
    String message, {
    String? context,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message,
          context: context,
          originalError: originalError,
          stackTrace: stackTrace,
        );
}
