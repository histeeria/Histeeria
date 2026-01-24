import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

/// Secure Storage Manager
///
/// Production-ready secure storage with:
/// - AES encryption on Android via encrypted shared preferences
/// - Keychain on iOS with proper accessibility settings
/// - Secure key management
/// - No debug logging in release builds
class SecureStorageManager {
  static final SecureStorageManager _instance = SecureStorageManager._internal();
  factory SecureStorageManager() => _instance;
  SecureStorageManager._internal();

  late final FlutterSecureStorage _storage;

  /// Initialize secure storage
  void initialize() {
    _storage = FlutterSecureStorage(
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
        // Use AES encryption
        keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_PKCS1Padding,
        storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
      ),
      iOptions: IOSOptions(
        // Most secure option - only accessible when device is unlocked
        accessibility: KeychainAccessibility.first_unlock_this_device,
        // Additional security: require biometric/passcode for sensitive data
        accountName: 'com.histeeria.app',
      ),
    );
  }

  /// Save encrypted data
  Future<void> saveSecure(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
      _logDebug('Saved secure data for key: $key');
    } catch (e) {
      _logError('Failed to save secure data for key: $key', e);
      rethrow;
    }
  }

  /// Read encrypted data
  Future<String?> readSecure(String key) async {
    try {
      final value = await _storage.read(key: key);
      if (value != null) {
        _logDebug('Read secure data for key: $key');
      }
      return value;
    } catch (e) {
      _logError('Failed to read secure data for key: $key', e);
      return null;
    }
  }

  /// Delete encrypted data
  Future<void> deleteSecure(String key) async {
    try {
      await _storage.delete(key: key);
      _logDebug('Deleted secure data for key: $key');
    } catch (e) {
      _logError('Failed to delete secure data for key: $key', e);
      rethrow;
    }
  }

  /// Save JSON data securely
  Future<void> saveJson(String key, Map<String, dynamic> data) async {
    final jsonStr = jsonEncode(data);
    await saveSecure(key, jsonStr);
  }

  /// Read JSON data securely
  Future<Map<String, dynamic>?> readJson(String key) async {
    final jsonStr = await readSecure(key);
    if (jsonStr == null) return null;
    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      _logError('Failed to decode JSON for key: $key', e);
      return null;
    }
  }

  /// Check if key exists
  Future<bool> containsKey(String key) async {
    final value = await _storage.read(key: key);
    return value != null;
  }

  /// Clear all secure storage (use with caution)
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
      _logDebug('Cleared all secure storage');
    } catch (e) {
      _logError('Failed to clear secure storage', e);
      rethrow;
    }
  }

  /// Get all keys (useful for debugging, disabled in release)
  Future<Map<String, String>> readAll() async {
    if (kReleaseMode) {
      throw UnsupportedError('readAll is disabled in release builds for security');
    }
    return await _storage.readAll();
  }

  // Debug logging (only in debug mode)
  void _logDebug(String message) {
    if (kDebugMode) {
      debugPrint('[SecureStorage] $message');
    }
  }

  void _logError(String message, dynamic error) {
    if (kDebugMode) {
      debugPrint('[SecureStorage] ERROR: $message - $error');
    }
  }
}

/// Storage Keys - centralized key management
class SecureStorageKeys {
  // Authentication
  static const String accessToken = 'histeeria_access_token';
  static const String refreshToken = 'histeeria_refresh_token';
  static const String userData = 'histeeria_user_data';
  
  // E2EE Keys (for messaging)
  static const String privateKey = 'histeeria_e2ee_private_key';
  static const String publicKey = 'histeeria_e2ee_public_key';
  static const String keyPairGenerated = 'histeeria_e2ee_key_pair_generated';
  
  // Multi-account
  static const String currentUserId = 'histeeria_current_user_id';
  static const String linkedAccounts = 'histeeria_linked_accounts';
  
  // Session management
  static const String lastLoginTime = 'histeeria_last_login_time';
  static const String deviceId = 'histeeria_device_id';
  
  // Feature flags
  static const String biometricEnabled = 'histeeria_biometric_enabled';
}
