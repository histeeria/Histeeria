import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Network configuration service
///
/// Manages dynamic IP address configuration for development
/// Stores IP address in SharedPreferences so it persists across app restarts
/// Provides smart defaults based on platform
class NetworkConfigService {
  static const String _keyStoredIpAddress = 'dev_api_base_url';
  static const String _keyLastKnownIp = 'last_known_ip_address';

  // Default ports
  static const int defaultPort = 8081;
  static const String defaultPath = '/api/v1';

  /// Get stored base URL from preferences, or null if not set
  static Future<String?> getStoredBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyStoredIpAddress);
    } catch (e) {
      debugPrint('Error getting stored base URL: $e');
      return null;
    }
  }

  /// Store base URL in preferences
  static Future<bool> setStoredBaseUrl(String baseUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_keyStoredIpAddress, baseUrl);
    } catch (e) {
      debugPrint('Error storing base URL: $e');
      return false;
    }
  }

  /// Get last known IP address (without port/path)
  static Future<String?> getLastKnownIp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyLastKnownIp);
    } catch (e) {
      return null;
    }
  }

  /// Store last known IP address
  static Future<bool> setLastKnownIp(String ip) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_keyLastKnownIp, ip);
    } catch (e) {
      return false;
    }
  }

  /// Clear stored base URL (reset to defaults)
  static Future<bool> clearStoredBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_keyStoredIpAddress);
    } catch (e) {
      return false;
    }
  }

  /// Get platform-specific default base URL
  /// 
  /// Returns:
  /// - Android Emulator: http://10.0.2.2:8081/api/v1
  /// - iOS Simulator: http://localhost:8081/api/v1
  /// - Physical Device: null (needs to be configured)
  static String? getPlatformDefaultBaseUrl() {
    // Check if running on Android emulator
    if (Platform.isAndroid && !kIsWeb) {
      // Android emulator uses special IP to reach host
      return 'http://10.0.2.2:$defaultPort$defaultPath';
    }

    // iOS simulator can use localhost
    if (Platform.isIOS && !kIsWeb) {
      return 'http://localhost:$defaultPort$defaultPath';
    }

    // Physical devices or web - no default
    return null;
  }

  /// Build base URL from IP address
  /// 
  /// Accepts IP address with or without protocol/port/path
  /// Examples:
  /// - "192.168.1.100" -> "http://192.168.1.100:8081/api/v1"
  /// - "192.168.1.100:8081" -> "http://192.168.1.100:8081/api/v1"
  /// - "http://192.168.1.100:8081/api/v1" -> "http://192.168.1.100:8081/api/v1"
  static String buildBaseUrl(String input) {
    // Remove whitespace
    input = input.trim();

    // If already a full URL, return as-is
    if (input.startsWith('http://') || input.startsWith('https://')) {
      // Ensure it ends with /api/v1 if not already present
      if (!input.endsWith('/api/v1')) {
        // Remove trailing slash if present
        input = input.replaceAll(RegExp(r'/+$'), '');
        // Add /api/v1 if path doesn't already exist
        if (!input.contains('/api/')) {
          input = '$input$defaultPath';
        }
      }
      return input;
    }

    // Extract IP address (handle cases with port)
    String ip;
    int? port;
    
    if (input.contains(':')) {
      final parts = input.split(':');
      ip = parts[0];
      if (parts.length > 1) {
        final portStr = parts[1].split('/')[0];
        port = int.tryParse(portStr) ?? defaultPort;
      } else {
        port = defaultPort;
      }
    } else {
      ip = input;
      port = defaultPort;
    }

    // Build full URL
    return 'http://$ip:$port$defaultPath';
  }

  /// Validate IP address format
  /// 
  /// Returns true if IP address is valid (IPv4)
  static bool isValidIpAddress(String ip) {
    // Simple IPv4 validation
    final ipRegex = RegExp(
      r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$',
    );
    
    // Extract IP from input (remove port if present)
    final cleanIp = ip.split(':').first.split('/').first.trim();
    return ipRegex.hasMatch(cleanIp);
  }

  /// Get development base URL with smart fallback
  /// 
  /// Priority:
  /// 1. Stored base URL (from SharedPreferences)
  /// 2. Environment variable (API_BASE_URL)
  /// 3. Platform default (10.0.2.2 for Android emulator, localhost for iOS simulator)
  /// 4. Last known IP (if stored)
  /// 5. null (needs manual configuration)
  static Future<String> getDevelopmentBaseUrl() async {
    // Current Laptop WiFi IP - Most likely correct for physical device testing
    const laptopWiFiIp = '192.168.100.187';
    final laptopWiFiUrl = 'http://$laptopWiFiIp:$defaultPort$defaultPath';

    // 1. Check environment variable
    const envBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (envBaseUrl.isNotEmpty) {
      return envBaseUrl;
    }

    // 2. Check stored preference
    final stored = await getStoredBaseUrl();
    if (stored != null && stored.isNotEmpty) {
      // If we are on a physical device, ignore the emulator IP
      if (Platform.isAndroid && !kIsWeb && stored.contains('10.0.2.2')) {
         debugPrint('[NetworkConfigService] Ignoring stored emulator IP on physical device');
      } else {
        return stored;
      }
    }

    // 3. Try last known IP (Highest priority for physical devices)
    final lastKnownIp = await getLastKnownIp();
    if (lastKnownIp != null && lastKnownIp.isNotEmpty) {
      // Validate IP (prevent using local loopback on physical devices)
      if (Platform.isAndroid && !kIsWeb && (lastKnownIp.contains('127.0.0.1') || lastKnownIp.contains('localhost'))) {
         debugPrint('[NetworkConfigService] Ignoring loopback IP on physical device');
      } else {
        final builtUrl = buildBaseUrl(lastKnownIp);
        return builtUrl;
      }
    }

    // 4. Platform-specific defaults (Emulator/Simulator fallback)
    final platformDefault = getPlatformDefaultBaseUrl();
    if (platformDefault != null) {
      // On physical Android device, prefer the laptop WiFi IP over the emulator default
      if (Platform.isAndroid && !kIsWeb) {
        return laptopWiFiUrl;
      }
      return platformDefault;
    }

    // 5. Hardcoded WiFi IP fallback (For the current user's environment)
    return laptopWiFiUrl;
  }

  /// Get WebSocket URL from base URL
  static String getWsUrl(String baseUrl) {
    return baseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://')
        .replaceFirst('/api/v1', '/api/v1/ws');
  }
}
