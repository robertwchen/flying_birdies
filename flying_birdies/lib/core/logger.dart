import 'dart:developer' as developer;

/// Logger interface for dependency injection
abstract class ILogger {
  void debug(String message, {Map<String, dynamic>? context});
  void info(String message, {Map<String, dynamic>? context});
  void warning(String message, {Map<String, dynamic>? context});
  void error(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  });
}

/// Console logger implementation using dart:developer
class ConsoleLogger implements ILogger {
  final String name;

  ConsoleLogger(this.name);

  @override
  void debug(String message, {Map<String, dynamic>? context}) {
    _log('DEBUG', message, context: context);
  }

  @override
  void info(String message, {Map<String, dynamic>? context}) {
    _log('INFO', message, context: context);
  }

  @override
  void warning(String message, {Map<String, dynamic>? context}) {
    _log('WARNING', message, context: context);
  }

  @override
  void error(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    _log(
      'ERROR',
      message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  void _log(
    String level,
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    final buffer = StringBuffer('[$level] [$name] $message');

    if (context != null && context.isNotEmpty) {
      buffer.write('\nContext: $context');
    }

    if (error != null) {
      buffer.write('\nError: $error');
    }

    developer.log(
      buffer.toString(),
      name: name,
      error: error,
      stackTrace: stackTrace,
      level: _getLogLevel(level),
    );
  }

  int _getLogLevel(String level) {
    switch (level) {
      case 'DEBUG':
        return 500;
      case 'INFO':
        return 800;
      case 'WARNING':
        return 900;
      case 'ERROR':
        return 1000;
      default:
        return 800;
    }
  }
}
