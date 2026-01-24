import 'package:dio/dio.dart';
import '../../config/api_config.dart';
import '../../services/token_storage_service.dart';
import '../../utils/app_logger.dart';

/// Authentication interceptor
///
/// Automatically adds JWT token to all authenticated requests
/// and handles token refresh when needed.
class AuthInterceptor extends Interceptor {
  final TokenStorageService _tokenStorage = TokenStorageService();
  final Dio _dio;
  bool _isRefreshing = false;
  final List<({RequestOptions options, ErrorInterceptorHandler handler})>
  _pendingRequests = [];

  AuthInterceptor(this._dio);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    AppLogger.debug('${options.method} ${options.path}', 'AuthInterceptor');
    
    // Skip auth for public endpoints
    if (_isPublicEndpoint(options.path)) {
      handler.next(options);
      return;
    }
    
    try {
      final token = await _tokenStorage.getAccessToken();
      
      if (token != null && token.isNotEmpty) {
        options.headers[ApiConfig.authorizationHeader] =
            '${ApiConfig.bearerPrefix}$token';
        AppLogger.debug('Token added to request', 'AuthInterceptor');
      } else {
        AppLogger.warning('No access token found for ${options.path}', 'AuthInterceptor');
      }
    } catch (e) {
      AppLogger.error('Failed to get access token', e, null, 'AuthInterceptor');
    }
    
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Handle 401 Unauthorized - token expired
    if (err.response?.statusCode == 401) {
      final requestOptions = err.requestOptions;

      // Skip refresh for auth endpoints
      if (_isPublicEndpoint(requestOptions.path)) {
        handler.next(err);
        return;
      }

      // Queue request if already refreshing
      if (_isRefreshing) {
        return _queueRequest(requestOptions, handler);
      }

      _isRefreshing = true;

      try {
        // Attempt to refresh token
        final newToken = await _refreshToken();

        if (newToken != null) {
          // Retry original request with new token
          final opts = requestOptions;
          opts.headers[ApiConfig.authorizationHeader] =
              '${ApiConfig.bearerPrefix}$newToken';

          final response = await _dio.fetch(opts);
          handler.resolve(response);

          // Process queued requests
          _processQueuedRequests(newToken);
        } else {
          // Refresh failed - clear tokens and reject
          await _tokenStorage.clearAll();
          handler.reject(err);
        }
      } catch (e) {
        // Refresh failed - clear tokens
        await _tokenStorage.clearAll();
        handler.reject(err);
      } finally {
        _isRefreshing = false;
        _pendingRequests.clear();
      }
    } else {
      handler.next(err);
    }
  }

  /// Check if endpoint is public (doesn't require auth)
  /// 
  /// List matches backend public routes in auth/handlers.go SetupRoutes()
  bool _isPublicEndpoint(String path) {
    final publicPaths = [
      // Auth public routes
      '/auth/register',
      '/auth/login',
      '/auth/forgot-password',
      '/auth/reset-password',
      '/auth/verify-email',
      '/auth/send-signup-otp',
      '/auth/verify-signup-otp',
      '/auth/check-username',
      // OAuth routes (initiation - exchange requires auth)
      '/auth/google/login',
      '/auth/github/login',
      '/auth/linkedin/login',
      '/auth/google/callback',
      '/auth/github/callback',
      '/auth/linkedin/callback',
      // Public endpoints
      '/search',
      '/hashtags',
      '/profile/', // Public profile endpoint (GET /profile/:username)
    ];

    return publicPaths.any((publicPath) => path.contains(publicPath));
  }

  /// Refresh access token using current access token
  /// 
  /// Backend expects current access token in Authorization header (not refresh token in body)
  /// Backend extracts user_id from JWT token to generate a new token
  Future<String?> _refreshToken() async {
    try {
      // Get current access token (not refresh token)
      final currentToken = await _tokenStorage.getAccessToken();
      if (currentToken == null || currentToken.isEmpty) {
        return null;
      }

      // Use Dio instance to make refresh request with current token in Authorization header
      final dio = Dio();
      final baseUrl = ApiConfig.baseUrl;
      final response = await dio.post(
        '$baseUrl/auth/refresh',
        options: Options(
          headers: {
            'Content-Type': ApiConfig.contentType,
            'Accept': ApiConfig.accept,
            ApiConfig.authorizationHeader: '${ApiConfig.bearerPrefix}$currentToken',
          },
        ),
      );

      // Backend returns: {"success": true, "token": "...", "expires_at": "..."} (flat structure)
      if (response.statusCode == 200 && response.data['success'] == true) {
        final newAccessToken = response.data['token'] as String?;
        if (newAccessToken != null) {
          await _tokenStorage.saveAccessToken(newAccessToken);
          return newAccessToken;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Queue request while token is being refreshed
  void _queueRequest(RequestOptions options, ErrorInterceptorHandler handler) {
    _pendingRequests.add((options: options, handler: handler));
  }

  /// Process all queued requests with new token
  void _processQueuedRequests(String newToken) {
    for (final pending in _pendingRequests) {
      pending.options.headers[ApiConfig.authorizationHeader] =
          '${ApiConfig.bearerPrefix}$newToken';

      _dio
          .fetch(pending.options)
          .then(
            (response) => pending.handler.resolve(response),
            onError: (error) => pending.handler.reject(
              error is DioException
                  ? error
                  : DioException(requestOptions: pending.options, error: error),
            ),
          );
    }
  }
}
