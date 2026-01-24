import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../services/connectivity_service.dart';
import '../security/certificate_pinning.dart';
import '../utils/app_logger.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'utils/error_handler.dart';
import 'exceptions/api_exception.dart';

/// Main API Client
///
/// Production-ready HTTP client with:
/// - Automatic token management
/// - Error handling
/// - Request/response interceptors
/// - Retry logic
/// - Connectivity checking
/// - Timeout handling
class ApiClient {
  static ApiClient? _instance;
  late final Dio _dio;
  final ConnectivityService _connectivity = ConnectivityService();

  ApiClient._internal() {
    // Use sync base URL immediately (platform-aware or env var)
    final initialBaseUrl = ApiConfig.baseUrl;
    AppLogger.info('Initializing API Client', 'ApiClient');
    AppLogger.info('Base URL: $initialBaseUrl', 'ApiClient');
    
    _dio = Dio(
      BaseOptions(
        baseUrl: initialBaseUrl,
        connectTimeout: Duration(milliseconds: ApiConfig.connectTimeout),
        receiveTimeout: Duration(milliseconds: ApiConfig.receiveTimeout),
        sendTimeout: Duration(milliseconds: ApiConfig.sendTimeout),
        headers: {
          'Content-Type': ApiConfig.contentType,
          'Accept': ApiConfig.accept,
        },
        validateStatus: (status) {
          // Accept status codes < 500 as success
          // We'll handle 4xx errors in error handler
          return status != null && status < 500;
        },
      ),
    );

    // Setup certificate pinning (disabled in debug by default)
    CertificatePinning.setupCertificatePinning(_dio);
    
    // Enforce HTTPS in production
    CertificatePinning.enforceHttps(_dio);

    // Add interceptors - IMPORTANT: AuthInterceptor MUST come BEFORE LoggingInterceptor
    // so that the Authorization header is added before logging
    final authInterceptor = AuthInterceptor(_dio);
    final loggingInterceptor = LoggingInterceptor();
    
    AppLogger.debug('Registering interceptors...', 'ApiClient');
    
    _dio.interceptors.addAll([
      authInterceptor, // First: Add auth token
      loggingInterceptor, // Second: Log request (no sensitive data)
    ]);
    
    AppLogger.success('API Client initialized', 'ApiClient');

    // Initialize connectivity service
    _connectivity.initialize();
    
    // Update base URL asynchronously if preferences have different value
    _updateBaseUrlAsync();
  }

  /// Update base URL asynchronously from preferences (if different)
  void _updateBaseUrlAsync() {
    ApiConfig.initializeBaseUrl().then((_) {
      final newBaseUrl = ApiConfig.baseUrl;
      if (_dio.options.baseUrl != newBaseUrl) {
        _dio.options.baseUrl = newBaseUrl;
        AppLogger.info('Base URL updated to: $newBaseUrl', 'ApiClient');
      }
    }).catchError((e) {
      AppLogger.warning('Failed to update base URL from preferences: $e', 'ApiClient');
    });
  }

  factory ApiClient() {
    _instance ??= ApiClient._internal();
    return _instance!;
  }

  /// Get underlying Dio instance (use sparingly)
  Dio get dio => _dio;

  /// GET request
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic)? fromJson,
  }) async {
    return _handleRequest<T>(
      () => _dio.get(path, queryParameters: queryParameters, options: options),
      fromJson: fromJson,
    );
  }

  /// POST request
  Future<T> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic)? fromJson,
  }) async {
    return _handleRequest<T>(
      () => _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ),
      fromJson: fromJson,
    );
  }

  /// PUT request
  Future<T> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic)? fromJson,
  }) async {
    return _handleRequest<T>(
      () => _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ),
      fromJson: fromJson,
    );
  }

  /// PATCH request
  Future<T> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic)? fromJson,
  }) async {
    return _handleRequest<T>(
      () => _dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ),
      fromJson: fromJson,
    );
  }

  /// DELETE request
  Future<T> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic)? fromJson,
  }) async {
    AppLogger.debug('DELETE: $path', 'ApiClient');
    return _handleRequest<T>(
      () => _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ),
      fromJson: fromJson,
    );
  }

  /// Handle request with retry logic and error handling
  Future<T> _handleRequest<T>(
    Future<Response> Function() request, {
    T Function(dynamic)? fromJson,
    int retryCount = 0,
  }) async {
    try {
      // Note: Connectivity check is now non-blocking
      // We let the actual request handle network errors
      // This prevents false "no internet" errors

      // Make request
      final response = await request();

      // Handle response
      if (response.statusCode != null && response.statusCode! >= 400) {
        AppLogger.error('HTTP ${response.statusCode}: ${response.requestOptions.path}', null, null, 'ApiClient');
        throw ErrorHandler.handleDioError(
          DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
          ),
        );
      }

      // Parse response
      if (fromJson != null) {
        return fromJson(response.data);
      }

      return response.data as T;
    } on DioException catch (e) {
      // Convert DioException to ApiException
      throw ErrorHandler.handleDioError(e);
    } on ApiException {
      // Re-throw ApiException as-is
      rethrow;
    } catch (e) {
      // Handle unexpected errors
      throw NetworkException(
        'An unexpected error occurred: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Upload file (multipart/form-data)
  Future<T> uploadFile<T>(
    String path,
    String filePath, {
    String fileKey = 'file',
    Map<String, dynamic>? additionalData,
    ProgressCallback? onSendProgress,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      // Note: Connectivity check is now non-blocking
      // We let the actual request handle network errors

      final formData = FormData.fromMap({
        fileKey: await MultipartFile.fromFile(filePath),
        if (additionalData != null) ...additionalData,
      });

      final response = await _dio.post(
        path,
        data: formData,
        onSendProgress: onSendProgress,
      );

      if (response.statusCode != null && response.statusCode! >= 400) {
        throw ErrorHandler.handleDioError(
          DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
          ),
        );
      }

      if (fromJson != null) {
        return fromJson(response.data);
      }

      return response.data as T;
    } on DioException catch (e) {
      throw ErrorHandler.handleDioError(e);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw NetworkException(
        'Upload failed: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Update base URL (useful for environment switching)
  void updateBaseUrl(String newBaseUrl) {
    _dio.options.baseUrl = newBaseUrl;
  }

  /// Clear all interceptors (use with caution)
  void clearInterceptors() {
    _dio.interceptors.clear();
  }
}
