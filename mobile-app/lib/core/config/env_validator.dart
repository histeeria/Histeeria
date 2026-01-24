import 'package:flutter/foundation.dart';
import 'api_config.dart';
import '../utils/app_logger.dart';

/// Environment Validator
///
/// Validates configuration at app startup to prevent runtime failures
class EnvValidator {
  /// Validate all required configuration
  static Future<ValidationResult> validate() async {
    final errors = <String>[];
    final warnings = <String>[];

    // Validate API Base URL
    if (ApiConfig.baseUrl.isEmpty) {
      errors.add('API Base URL is not configured');
    } else {
      try {
        final uri = Uri.parse(ApiConfig.baseUrl);
        
        // Check if HTTPS in production
        if (kReleaseMode && uri.scheme != 'https') {
          errors.add('Production build must use HTTPS. Current: ${uri.scheme}://');
        }
        
        // Check if localhost in production
        if (kReleaseMode && (uri.host == 'localhost' || uri.host == '127.0.0.1')) {
          errors.add('Production build cannot use localhost');
        }
        
        // Validate URL format
        if (!uri.hasScheme || !uri.hasAuthority) {
          errors.add('Invalid API URL format: ${ApiConfig.baseUrl}');
        }
      } catch (e) {
        errors.add('Invalid API URL: ${ApiConfig.baseUrl}');
      }
    }

    // Check Supabase storage configuration
    try {
      await ApiConfig.fetchStorageUrl();
      final storageUrl = ApiConfig.supabaseStorageUrl;
      
      if (storageUrl == null || storageUrl.isEmpty) {
        warnings.add('Supabase storage URL not configured - media may not display');
      } else {
        AppLogger.success('Supabase storage URL configured: $storageUrl');
      }
    } catch (e) {
      warnings.add('Failed to fetch Supabase storage URL: $e');
    }

    // Validate environment consistency
    if (kReleaseMode) {
      // Production checks
      if (ApiConfig.baseUrl.contains('localhost')) {
        errors.add('Localhost URL detected in production build');
      }
      if (ApiConfig.baseUrl.contains('http://')) {
        errors.add('HTTP protocol detected in production build');
      }
    }

    // Log results
    if (errors.isNotEmpty) {
      AppLogger.error('Environment validation failed!');
      for (final error in errors) {
        AppLogger.error('  - $error');
      }
    }

    if (warnings.isNotEmpty) {
      AppLogger.warning('Environment validation warnings:');
      for (final warning in warnings) {
        AppLogger.warning('  - $warning');
      }
    }

    if (errors.isEmpty && warnings.isEmpty) {
      AppLogger.success('Environment validation passed!');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Test API connectivity
  static Future<ConnectivityResult> testApiConnectivity() async {
    try {
      AppLogger.info('Testing API connectivity...');
      
      // Try to fetch storage URL as a connectivity test
      await ApiConfig.fetchStorageUrl();
      
      AppLogger.success('API connectivity test passed');
      return ConnectivityResult(
        isConnected: true,
        message: 'Connected to API successfully',
      );
    } catch (e) {
      AppLogger.error('API connectivity test failed', e);
      return ConnectivityResult(
        isConnected: false,
        message: 'Failed to connect to API: $e',
      );
    }
  }

  /// Get user-friendly error message
  static String getErrorMessage(ValidationResult result) {
    if (result.isValid) return '';
    
    final buffer = StringBuffer();
    buffer.writeln('App configuration error:');
    buffer.writeln();
    
    for (final error in result.errors) {
      buffer.writeln('• $error');
    }
    
    buffer.writeln();
    buffer.writeln('Please contact support or reinstall the app.');
    
    return buffer.toString();
  }
}

/// Validation Result
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  ValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
  });

  bool get hasWarnings => warnings.isNotEmpty;
  bool get hasErrors => errors.isNotEmpty;
}

/// Connectivity Result
class ConnectivityResult {
  final bool isConnected;
  final String message;

  ConnectivityResult({
    required this.isConnected,
    required this.message,
  });
}
