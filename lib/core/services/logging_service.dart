import 'package:flutter/foundation.dart';

/// Logging levels
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// Centralized logging service
class LoggingService {
  static LoggingService? _instance;
  static LoggingService get instance {
    _instance ??= LoggingService._();
    return _instance!;
  }

  LoggingService._();

  LogLevel _minLevel = kDebugMode ? LogLevel.debug : LogLevel.info;

  /// Set minimum log level
  void setMinLevel(LogLevel level) {
    _minLevel = level;
  }

  /// Log debug message
  void debug(String message, [Object? error, StackTrace? stackTrace]) {
    if (_minLevel.index <= LogLevel.debug.index) {
      _log('DEBUG', message, error, stackTrace);
    }
  }

  /// Log info message
  void info(String message, [Object? error, StackTrace? stackTrace]) {
    if (_minLevel.index <= LogLevel.info.index) {
      _log('INFO', message, error, stackTrace);
    }
  }

  /// Log warning message
  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    if (_minLevel.index <= LogLevel.warning.index) {
      _log('WARN', message, error, stackTrace);
    }
  }

  /// Log error message
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (_minLevel.index <= LogLevel.error.index) {
      _log('ERROR', message, error, stackTrace);
    }
  }

  void _log(String level, String message, [Object? error, StackTrace? stackTrace]) {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] $level: $message';

    debugPrint(logMessage);

    if (error != null) {
      debugPrint('Error: $error');
    }

    if (stackTrace != null) {
      debugPrint('StackTrace: $stackTrace');
    }
  }
}





