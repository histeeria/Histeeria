import 'package:dio/dio.dart';
import '../exceptions/api_exception.dart';

/// Error handler utility
///
/// Converts Dio errors and HTTP responses into
/// typed exceptions for better error handling.
class ErrorHandler {
  /// Convert DioException to ApiException
  static ApiException handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return TimeoutException(
          'Connection timeout. The server may be unreachable. Please verify:\n'
          '• Backend server is running on port 8081\n'
          '• Correct IP address in API configuration\n'
          '• Device and server are on the same network',
          statusCode: error.response?.statusCode,
          originalError: error,
        );

      case DioExceptionType.badResponse:
        return _handleResponseError(error.response);

      case DioExceptionType.cancel:
        return CancellationException(
          'Request was cancelled',
          statusCode: error.response?.statusCode,
          originalError: error,
        );

      case DioExceptionType.connectionError:
        return NetworkException(
          'Cannot connect to server. Please verify:\n'
          '• Backend server is running\n'
          '• Correct API base URL in configuration\n'
          '• Network connectivity is available',
          statusCode: error.response?.statusCode,
          originalError: error,
        );

      case DioExceptionType.badCertificate:
        return NetworkException(
          'SSL certificate error. Please try again later.',
          statusCode: error.response?.statusCode,
          originalError: error,
        );

      case DioExceptionType.unknown:
        return NetworkException(
          'An unexpected error occurred. Please try again.',
          statusCode: error.response?.statusCode,
          originalError: error,
        );
    }
  }

  /// Handle HTTP response errors
  static ApiException _handleResponseError(Response? response) {
    if (response == null) {
      return ServerException(
        'Server error: No response received',
        statusCode: null,
      );
    }

    final statusCode = response.statusCode ?? 0;
    final data = response.data;
    String message = 'An error occurred';
    Map<String, List<String>>? validationErrors;

    // Try to extract error message from response
    if (data is Map<String, dynamic>) {
      message =
          data['error'] as String? ??
          data['message'] as String? ??
          'An error occurred';

      // Extract validation errors if present
      if (data['errors'] != null && data['errors'] is Map) {
        validationErrors = Map<String, List<String>>.from(
          (data['errors'] as Map).map(
            (key, value) => MapEntry(
              key.toString(),
              value is List
                  ? value.map((e) => e.toString()).toList()
                  : [value.toString()],
            ),
          ),
        );
      }
    } else if (data is String) {
      message = data;
    }

    switch (statusCode) {
      case 400:
        return ValidationException(
          message,
          statusCode: statusCode,
          originalError: data,
          errors: validationErrors,
        );

      case 401:
        return AuthenticationException(
          message.isNotEmpty
              ? message
              : 'Authentication failed. Please login again.',
          statusCode: statusCode,
          originalError: data,
        );

      case 403:
        return AuthorizationException(
          message.isNotEmpty
              ? message
              : 'You do not have permission to perform this action.',
          statusCode: statusCode,
          originalError: data,
        );

      case 404:
        return NotFoundException(
          message.isNotEmpty ? message : 'Resource not found.',
          statusCode: statusCode,
          originalError: data,
        );

      case 409:
        return ValidationException(
          message.isNotEmpty ? message : 'Conflict: Resource already exists.',
          statusCode: statusCode,
          originalError: data,
          errors: validationErrors,
        );

      case 429:
        // Extract retry-after header if available
        final retryAfter = response.headers.value('retry-after');
        Duration? retryDelay;
        if (retryAfter != null) {
          try {
            retryDelay = Duration(seconds: int.parse(retryAfter));
          } catch (_) {
            // Ignore parsing errors
          }
        }

        return RateLimitException(
          message.isNotEmpty
              ? message
              : 'Too many requests. Please try again later.',
          statusCode: statusCode,
          originalError: data,
          retryAfter: retryDelay,
        );

      case 500:
      case 502:
      case 503:
      case 504:
        return InternalServerException(
          message.isNotEmpty
              ? message
              : 'Server error. Please try again later.',
          statusCode: statusCode,
          originalError: data,
        );

      default:
        return ServerException(
          message,
          statusCode: statusCode,
          originalError: data,
        );
    }
  }

  /// Get user-friendly error message
  static String getErrorMessage(ApiException exception) {
    if (exception is NetworkException) {
      return 'No internet connection. Please check your network.';
    }
    if (exception is TimeoutException) {
      return 'Request timed out. Please try again.';
    }
    if (exception is AuthenticationException) {
      return 'Session expired. Please login again.';
    }
    if (exception is RateLimitException) {
      return 'Too many requests. Please wait a moment.';
    }

    return exception.message;
  }
}
