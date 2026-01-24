import 'package:flutter/foundation.dart';

/// Production-ready logging service
///
/// Features:
/// - Automatically disabled in release builds
/// - No sensitive data logged
/// - Color-coded log levels
/// - Stack trace support for errors
class AppLogger {
  static const bool _enableLogging = kDebugMode; // Only log in debug mode

  /// Log levels
  static const String _info = '📘 INFO';
  static const String _warning = '⚠️  WARNING';
  static const String _error = '❌ ERROR';
  static const String _success = '✅ SUCCESS';
  static const String _debug = '🔍 DEBUG';

  /// Info log
  static void info(String message, [String? tag]) {
    if (!_enableLogging) return;
    final tagStr = tag != null ? '[$tag]' : '';
    debugPrint('$_info $tagStr $message');
  }

  /// Warning log
  static void warning(String message, [String? tag]) {
    if (!_enableLogging) return;
    final tagStr = tag != null ? '[$tag]' : '';
    debugPrint('$_warning $tagStr $message');
  }

  /// Error log
  static void error(String message, [dynamic error, StackTrace? stackTrace, String? tag]) {
    if (!_enableLogging) return;
    final tagStr = tag != null ? '[$tag]' : '';
    debugPrint('$_error $tagStr $message');
    if (error != null) {
      debugPrint('  Error: $error');
    }
    if (stackTrace != null) {
      debugPrint('  Stack trace: $stackTrace');
    }
  }

  /// Success log
  static void success(String message, [String? tag]) {
    if (!_enableLogging) return;
    final tagStr = tag != null ? '[$tag]' : '';
    debugPrint('$_success $tagStr $message');
  }

  /// Debug log
  static void debug(String message, [String? tag]) {
    if (!_enableLogging) return;
    final tagStr = tag != null ? '[$tag]' : '';
    debugPrint('$_debug $tagStr $message');
  }

  /// Network request log
  static void networkRequest(String method, String url, [Map<String, dynamic>? data]) {
    if (!_enableLogging) return;
    debugPrint('🌐 NETWORK REQUEST: $method $url');
    if (data != null && data.isNotEmpty) {
      // Don't log sensitive data (tokens, passwords, etc.)
      final sanitizedData = Map<String, dynamic>.from(data);
      sanitizedData.remove('password');
      sanitizedData.remove('token');
      sanitizedData.remove('access_token');
      sanitizedData.remove('refresh_token');
      debugPrint('  Data: $sanitizedData');
    }
  }

  /// Network response log
  static void networkResponse(int statusCode, String url, [dynamic data]) {
    if (!_enableLogging) return;
    final emoji = statusCode >= 200 && statusCode < 300 ? '✅' : '❌';
    debugPrint('$emoji NETWORK RESPONSE: $statusCode $url');
    // Don't log response data in production for security
  }

  /// Auth event log (never logs sensitive data)
  static void auth(String event, [Map<String, dynamic>? metadata]) {
    if (!_enableLogging) return;
    debugPrint('🔐 AUTH: $event');
    if (metadata != null) {
      // Only log non-sensitive metadata
      final safe = Map<String, dynamic>.from(metadata);
      safe.remove('password');
      safe.remove('token');
      safe.remove('code');
      safe.remove('otp');
      debugPrint('  Metadata: $safe');
    }
  }

  /// Navigation log
  static void navigation(String from, String to) {
    if (!_enableLogging) return;
    debugPrint('🧭 NAVIGATION: $from → $to');
  }

  /// Custom log with emoji
  static void custom(String emoji, String message, [String? tag]) {
    if (!_enableLogging) return;
    final tagStr = tag != null ? '[$tag]' : '';
    debugPrint('$emoji $tagStr $message');
  }
}
