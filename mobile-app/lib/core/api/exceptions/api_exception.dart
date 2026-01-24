/// Base exception class for API-related errors
abstract class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic originalError;

  const ApiException(this.message, {this.statusCode, this.originalError});

  @override
  String toString() => message;
}

/// Exception thrown when network request fails
class NetworkException extends ApiException {
  const NetworkException(
    super.message, {
    super.statusCode,
    super.originalError,
  });
}

/// Exception thrown when server returns an error response
class ServerException extends ApiException {
  const ServerException(super.message, {super.statusCode, super.originalError});
}

/// Exception thrown when request times out
class TimeoutException extends ApiException {
  const TimeoutException(
    super.message, {
    super.statusCode,
    super.originalError,
  });
}

/// Exception thrown when authentication fails
class AuthenticationException extends ApiException {
  const AuthenticationException(
    super.message, {
    super.statusCode,
    super.originalError,
  });
}

/// Exception thrown when authorization fails (403)
class AuthorizationException extends ApiException {
  const AuthorizationException(
    super.message, {
    super.statusCode,
    super.originalError,
  });
}

/// Exception thrown when resource is not found (404)
class NotFoundException extends ApiException {
  const NotFoundException(
    super.message, {
    super.statusCode,
    super.originalError,
  });
}

/// Exception thrown when request validation fails (400)
class ValidationException extends ApiException {
  final Map<String, List<String>>? errors;

  const ValidationException(
    super.message, {
    super.statusCode,
    super.originalError,
    this.errors,
  });
}

/// Exception thrown when rate limit is exceeded (429)
class RateLimitException extends ApiException {
  final Duration? retryAfter;

  const RateLimitException(
    super.message, {
    super.statusCode,
    super.originalError,
    this.retryAfter,
  });
}

/// Exception thrown when server error occurs (500+)
class InternalServerException extends ApiException {
  const InternalServerException(
    super.message, {
    super.statusCode,
    super.originalError,
  });
}

/// Exception thrown when request is cancelled
class CancellationException extends ApiException {
  const CancellationException(
    super.message, {
    super.statusCode,
    super.originalError,
  });
}
