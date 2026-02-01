import 'dart:io';
import '../utils/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'environment.dart';
import '../services/network_config_service.dart';

/// API Configuration for Histeeria Backend
///
/// This file contains all API-related configuration constants.
/// Uses EnvironmentConfig for environment-based URLs.
/// SECURITY: For production, these values MUST be loaded from environment variables
/// or secure configuration files. Never hardcode sensitive URLs or credentials.
class ApiConfig {
  // Base URLs - Now using environment-based configuration
  // 
  // Setup for Development:
  // - Android Emulator: Use 'http://10.0.2.2:8081/api/v1' via --dart-define=API_BASE_URL=http://10.0.2.2:8081/api/v1
  // - Physical Device: Use your computer's IP, e.g., 'http://192.168.1.100:8081/api/v1'
  // - iOS Simulator: Use 'http://localhost:8081/api/v1' (default)
  //
  // Usage:
  //   flutter run --dart-define=API_BASE_URL=http://192.168.1.100:8081/api/v1
  //   flutter run --dart-define=ENV=production
  // Base URLs - Now using sync version for immediate use, with async background update
  static String get baseUrl => _baseUrlCache ?? baseUrlSync;
  static Future<String> get baseUrlAsync => EnvironmentConfig.baseUrl;
  static Future<String> get wsUrl => EnvironmentConfig.wsUrl;
  
  static String? _baseUrlCache;
  
  /// Initialize base URL cache (call on app start)
  static Future<void> initializeBaseUrl() async {
    _baseUrlCache = await baseUrlAsync;
  }
  
  /// Synchronous base URL (for immediate use)
  /// Uses environment variable, platform defaults, or localhost
  static String get baseUrlSync {
    // Check environment variable first (compile-time) - highest priority
    const envBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (envBaseUrl.isNotEmpty) {
      return envBaseUrl;
    }
    
    // Use WiFi IP for physical devices - Highest accuracy for current user
    const wifiIp = '192.168.100.187';
    const wifiBaseUrl = 'http://$wifiIp:8081/api/v1';

    if (Platform.isAndroid && !kIsWeb) {
      // Return WiFi IP for Android physical device/emulator by default
      return wifiBaseUrl;
    }
    
    // Use platform-specific defaults
    final platformDefault = NetworkConfigService.getPlatformDefaultBaseUrl();
    if (platformDefault != null) {
      return platformDefault;
    }
    
    return wifiBaseUrl;
  }

  // API Endpoints
  static const String auth = '/auth';
  static const String account = '/account';
  static const String posts = '/posts';
  static const String comments = '/comments';
  static const String feed = '/feed';
  static const String statuses = '/statuses';
  static const String messages = '/messages';
  static const String conversations = '/conversations';
  static const String notifications = '/notifications';
  static const String search = '/search';
  static const String relationships = '/relationships';
  static const String hashtags = '/hashtags';

  // Timeouts (in milliseconds)
  static const int connectTimeout = 30000; // 30 seconds
  static const int receiveTimeout = 30000; // 30 seconds
  static const int sendTimeout = 30000; // 30 seconds

  // Retry configuration - Optimized for speed
  static const int maxRetries = 1; // Reduced from 3 (faster failure detection)
  static const Duration retryDelay = Duration(
    milliseconds: 500,
  ); // Reduced from 1s

  // Headers
  static const String contentType = 'application/json';
  static const String accept = 'application/json';
  static const String authorizationHeader = 'Authorization';
  static const String bearerPrefix = 'Bearer ';

  // Token storage keys
  static const String accessTokenKey = 'histeeria_access_token';
  static const String refreshTokenKey = 'histeeria_refresh_token';
  static const String userDataKey = 'histeeria_user_data';

  // Pagination defaults
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Supabase Storage URL - for constructing full image URLs
  // This should match your SUPABASE_URL environment variable
  // Format: https://{project-id}.supabase.co
  static String? _cachedSupabaseStorageUrl;
  
  static String get supabaseStorageUrl {
    // Return cached value if available
    if (_cachedSupabaseStorageUrl != null) {
      return _cachedSupabaseStorageUrl!;
    }
    
    // Try to get from environment variable first
    const envSupabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    if (envSupabaseUrl.isNotEmpty) {
      _cachedSupabaseStorageUrl = envSupabaseUrl;
      return envSupabaseUrl;
    }
    
    // If not in environment, return empty - will be fetched from backend
    return '';
  }
  
  /// Fetch Supabase storage URL from backend
  /// Call this on app startup to cache the URL
  static Future<void> fetchStorageUrl() async {
    if (_cachedSupabaseStorageUrl != null && _cachedSupabaseStorageUrl!.isNotEmpty) {
      return; // Already cached
    }
    
    try {
      final dio = Dio();
      // Remove /api/v1 from baseUrl to get the root URL
      String apiBaseUrl = baseUrl;
      if (apiBaseUrl.endsWith('/api/v1')) {
        apiBaseUrl = apiBaseUrl.substring(0, apiBaseUrl.length - '/api/v1'.length);
      } else if (apiBaseUrl.endsWith('/api')) {
        apiBaseUrl = apiBaseUrl.substring(0, apiBaseUrl.length - '/api'.length);
      }
      
      // Ensure no trailing slash
      apiBaseUrl = apiBaseUrl.replaceAll(RegExp(r'/$'), '');
      
      if (kDebugMode) {
        AppLogger.debug('[ApiConfig] Fetching storage URL from: $apiBaseUrl/config/storage-url');
      }
      
      final response = await dio.get(
        '$apiBaseUrl/config/storage-url',
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );
      
      if (kDebugMode) {
        AppLogger.debug('[ApiConfig] Storage URL response status: ${response.statusCode}');
        AppLogger.debug('[ApiConfig] Storage URL response data: ${response.data}');
      }
      
      if (response.statusCode == 200) {
        if (response.data is Map) {
          final storageUrl = response.data['storage_url'] as String?;
          if (storageUrl != null && storageUrl.isNotEmpty) {
            // Ensure URL doesn't have trailing slash
            _cachedSupabaseStorageUrl = storageUrl.replaceAll(RegExp(r'/$'), '');
            if (kDebugMode) {
              AppLogger.debug('[ApiConfig] ✅ Cached storage URL: $_cachedSupabaseStorageUrl');
            }
            return;
          }
        } else if (response.data is String) {
          // Handle case where backend returns string directly
          final storageUrl = response.data as String;
          if (storageUrl.isNotEmpty) {
            _cachedSupabaseStorageUrl = storageUrl.replaceAll(RegExp(r'/$'), '');
            if (kDebugMode) {
              AppLogger.debug('[ApiConfig] ✅ Cached storage URL (string): $_cachedSupabaseStorageUrl');
            }
            return;
          }
        }
      } else if (response.statusCode == 503) {
        // Backend returned service unavailable - SUPABASE_URL not configured
        if (kDebugMode) {
          AppLogger.debug('[ApiConfig] ⚠️ Backend reports SUPABASE_URL not configured');
        }
      }
    } catch (e) {
      // Log error for debugging but continue - will try to use environment variable
      if (kDebugMode) {
        AppLogger.debug('[ApiConfig] ❌ Failed to fetch storage URL: $e');
      }
    }
    
    // If fetch failed, try environment variable as fallback
    const envSupabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    if (envSupabaseUrl.isNotEmpty) {
      _cachedSupabaseStorageUrl = envSupabaseUrl.replaceAll(RegExp(r'/$'), '');
      if (kDebugMode) {
        AppLogger.debug('[ApiConfig] ✅ Using environment variable SUPABASE_URL: $_cachedSupabaseStorageUrl');
      }
    } else {
      if (kDebugMode) {
        AppLogger.debug('[ApiConfig] ⚠️ No SUPABASE_URL found in environment variables');
      }
    }
  }
  
  /// Construct full Supabase Storage public URL from relative path
  /// Handles URLs like "media/posts/..." and converts to full URL
  static String constructSupabaseStorageUrl(String relativePath) {
    if (relativePath.startsWith('http://') || relativePath.startsWith('https://')) {
      return relativePath; // Already a full URL
    }
    
    // Try to fetch URL if not cached yet (async fallback)
    if (_cachedSupabaseStorageUrl == null || _cachedSupabaseStorageUrl!.isEmpty) {
      // Trigger async fetch (won't block, but will cache for next time)
      fetchStorageUrl().catchError((_) {});
    }
    
    final supabaseUrl = supabaseStorageUrl;
    if (supabaseUrl.isEmpty) {
      // If we still don't have Supabase URL, try to construct from baseUrl
      // This is a fallback - ideally the backend should provide it
      final base = baseUrl.replaceAll('/api/v1', '').replaceAll('/api', '');
      if (base.isNotEmpty && !base.contains('localhost') && !base.contains('127.0.0.1')) {
        // Try to extract Supabase URL from base URL if possible
        // This is a last resort fallback
        return relativePath; // Return relative path - backend should handle it
      }
      return relativePath;
    }
    
    // Clean up relative path (remove leading slash if present)
    final cleanPath = relativePath.startsWith('/') ? relativePath.substring(1) : relativePath;
    
    // Construct full public URL
    // Format: https://xxx.supabase.co/storage/v1/object/public/{relativePath}
    return '$supabaseUrl/storage/v1/object/public/$cleanPath';
  }
}
