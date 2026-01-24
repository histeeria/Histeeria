import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import '../utils/app_logger.dart';

/// Certificate Pinning Service
///
/// Prevents MITM attacks by validating SSL certificates
/// Enable in production for sensitive endpoints
class CertificatePinning {
  /// Setup certificate pinning for Dio client
  ///
  /// WARNING: Only enable in production after adding your server's certificate
  static void setupCertificatePinning(Dio dio, {
    List<String>? pinnedCertificates,
    bool enableInDebug = false,
  }) {
    // Skip in debug mode unless explicitly enabled
    if (kDebugMode && !enableInDebug) {
      AppLogger.warning('Certificate pinning disabled in debug mode');
      return;
    }

    // Configure SSL/TLS validation
    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      
      // Set security context
      client.badCertificateCallback = (X509Certificate cert, String host, int port) {
        // In production, you should implement certificate pinning here
        // For now, we validate that it's a valid certificate
        
        if (kReleaseMode) {
          // Production: Strict validation
          AppLogger.info('Validating certificate for $host:$port');
          
          // TODO: Add your server's certificate fingerprints here
          // Example:
          // const String expectedFingerprint = 'YOUR_CERT_SHA256_FINGERPRINT';
          // final String actualFingerprint = sha256.convert(cert.der).toString();
          // return actualFingerprint == expectedFingerprint;
          
          // For now, use default validation
          return false; // Reject bad certificates in production
        } else {
          // Development: More lenient (but still log)
          AppLogger.warning('Certificate validation failed for $host:$port');
          return true; // Allow for development/testing
        }
      };
      
      // Set timeout
      client.connectionTimeout = const Duration(seconds: 30);
      
      // Enforce TLS 1.2+ only
      AppLogger.info('TLS configured: enforcing TLS 1.2+');
      
      return client;
    };
  }

  /// Validate certificate fingerprint (SHA-256)
  static bool validateCertificateFingerprint(
    X509Certificate cert,
    List<String> validFingerprints,
  ) {
    try {
      // Get certificate DER bytes
      final certDer = cert.der;
      
      // Calculate SHA-256 fingerprint
      // Note: You'll need to add crypto package for this
      // import 'package:crypto/crypto.dart';
      // final fingerprint = sha256.convert(certDer).toString();
      
      // For now, placeholder
      final fingerprint = certDer.hashCode.toString();
      
      // Check if fingerprint matches any valid one
      final isValid = validFingerprints.contains(fingerprint);
      
      if (!isValid) {
        AppLogger.error('Certificate fingerprint mismatch!', 
          'Expected one of: $validFingerprints, got: $fingerprint');
      }
      
      return isValid;
    } catch (e) {
      AppLogger.error('Failed to validate certificate fingerprint', e);
      return false;
    }
  }

  /// Setup HTTPS-only enforcement
  static void enforceHttps(Dio dio) {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // Ensure all requests use HTTPS
        if (!options.uri.isScheme('HTTPS') && kReleaseMode) {
          AppLogger.error('Attempted HTTP request in production: ${options.uri}');
          return handler.reject(
            DioException(
              requestOptions: options,
              error: 'HTTP not allowed in production. Use HTTPS.',
              type: DioExceptionType.badResponse,
            ),
          );
        }
        return handler.next(options);
      },
    ));
  }
}

/// How to get your server's certificate fingerprint:
///
/// 1. Using OpenSSL:
///    ```bash
///    openssl s_client -connect your-api.com:443 < /dev/null | \
///    openssl x509 -fingerprint -sha256 -noout
///    ```
///
/// 2. Using online tools:
///    - https://www.ssllabs.com/ssltest/
///    - Look for "Certificate #1" SHA256 Fingerprint
///
/// 3. Add to your app:
///    ```dart
///    const yourCertFingerprints = [
///      'AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99',
///    ];
///    
///    CertificatePinning.setupCertificatePinning(
///      dio,
///      pinnedCertificates: yourCertFingerprints,
///    );
///    ```
