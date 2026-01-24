import '../services/network_config_service.dart';

/// Environment configuration for Histeeria Mobile App
///
/// Supports dev, staging, and production environments
/// Can be overridden via environment variables or build configuration
enum Environment {
  development,
  staging,
  production,
}

/// Environment configuration service
///
/// Provides environment-specific configuration values
class EnvironmentConfig {
  static Environment _currentEnvironment = _detectEnvironment();

  /// Get current environment
  static Environment get current => _currentEnvironment;

  /// Set environment (useful for testing or manual override)
  static void setEnvironment(Environment env) {
    _currentEnvironment = env;
  }

  /// Detect environment from environment variables or build configuration
  static Environment _detectEnvironment() {
    // Check for environment variable (can be set via --dart-define)
    const envString = String.fromEnvironment('ENV', defaultValue: '');
    
    switch (envString.toLowerCase()) {
      case 'production':
      case 'prod':
        return Environment.production;
      case 'staging':
        return Environment.staging;
      case 'development':
      case 'dev':
      default:
        return Environment.development;
    }
  }

  /// Get base URL for current environment
  /// 
  /// For development: Uses NetworkConfigService to get stored IP or smart defaults
  /// This allows runtime configuration without hardcoding IP addresses
  static Future<String> get baseUrl async {
    switch (_currentEnvironment) {
      case Environment.production:
        return 'https://api.histeeria.app/api/v1';
      case Environment.staging:
        return 'https://staging-api.histeeria.app/api/v1';
      case Environment.development:
        return await _getDevelopmentBaseUrl();
    }
  }

  /// Get WebSocket URL for current environment
  /// 
  /// For development: Uses NetworkConfigService to get stored IP or smart defaults
  static Future<String> get wsUrl async {
    switch (_currentEnvironment) {
      case Environment.production:
        return 'wss://api.histeeria.app/ws';
      case Environment.staging:
        return 'wss://staging-api.histeeria.app/ws';
      case Environment.development:
        return await _getDevelopmentWsUrl();
    }
  }

  /// Get development base URL
  /// 
  /// Uses NetworkConfigService to get IP from preferences or smart defaults
  /// No more hardcoded IP addresses - configured at runtime!
  static Future<String> _getDevelopmentBaseUrl() async {
    return await NetworkConfigService.getDevelopmentBaseUrl();
  }

  /// Get development WebSocket URL
  /// 
  /// Converts base URL to WebSocket URL
  static Future<String> _getDevelopmentWsUrl() async {
    final baseUrl = await _getDevelopmentBaseUrl();
    return NetworkConfigService.getWsUrl(baseUrl);
  }

  /// Check if current environment is production
  static bool get isProduction => _currentEnvironment == Environment.production;

  /// Check if current environment is staging
  static bool get isStaging => _currentEnvironment == Environment.staging;

  /// Check if current environment is development
  static bool get isDevelopment => _currentEnvironment == Environment.development;

  /// Get environment name as string
  static String get name {
    switch (_currentEnvironment) {
      case Environment.production:
        return 'production';
      case Environment.staging:
        return 'staging';
      case Environment.development:
        return 'development';
    }
  }
}
