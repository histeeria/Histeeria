import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../utils/app_logger.dart';

/// Logging interceptor for API requests
///
/// Production-ready logging:
/// - Automatically disabled in release builds
/// - No sensitive data logged (tokens, passwords)
/// - Only logs errors in production
class LoggingInterceptor extends Interceptor {
  final bool logRequests;
  final bool logResponses;
  final bool logErrors;

  LoggingInterceptor({
    bool? logRequests,
    bool? logResponses,
    bool? logErrors,
  })  : logRequests = logRequests ?? kDebugMode,
        logResponses = logResponses ?? kDebugMode,
        logErrors = logErrors ?? true; // Always log errors

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (logRequests && kDebugMode) {
      // Sanitize data before logging
      final sanitizedData = _sanitizeData(options.data);
      final sanitizedHeaders = _sanitizeHeaders(options.headers);
      
      AppLogger.networkRequest(
        options.method,
        options.path,
        {'data': sanitizedData, 'headers': sanitizedHeaders},
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (logResponses && kDebugMode) {
      AppLogger.networkResponse(
        response.statusCode ?? 0,
        response.requestOptions.path,
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (logErrors) {
      AppLogger.error(
        'API Error: ${err.requestOptions.method} ${err.requestOptions.path}',
        err.message,
        err.stackTrace,
        'API',
      );
    }
    handler.next(err);
  }

  /// Remove sensitive data before logging
  dynamic _sanitizeData(dynamic data) {
    if (data is Map) {
      final sanitized = Map<String, dynamic>.from(data);
      sanitized.remove('password');
      sanitized.remove('token');
      sanitized.remove('access_token');
      sanitized.remove('refresh_token');
      sanitized.remove('code');
      sanitized.remove('otp');
      sanitized.remove('verification_code');
      return sanitized;
    }
    return data;
  }

  /// Remove sensitive headers before logging
  Map<String, dynamic> _sanitizeHeaders(Map<String, dynamic> headers) {
    final sanitized = Map<String, dynamic>.from(headers);
    if (sanitized.containsKey('Authorization')) {
      sanitized['Authorization'] = '***REDACTED***';
    }
    return sanitized;
  }
}
