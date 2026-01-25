import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import '../utils/app_logger.dart';

/// Secure token storage service
///
/// Uses Flutter Secure Storage to securely store JWT tokens
/// and user data. This ensures tokens are encrypted at rest.
///
/// Security features:
/// - AES encryption on Android
/// - Keychain on iOS
/// - No debug logging in release builds
class TokenStorageService {
  static final TokenStorageService _instance = TokenStorageService._internal();
  factory TokenStorageService() => _instance;
  TokenStorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_PKCS1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      accountName: 'com.histeeria.app',
    ),
  );

  /// Save access token
  Future<void> saveAccessToken(String token) async {
    try {
      await _storage.write(key: ApiConfig.accessTokenKey, value: token);
      AppLogger.auth('Access token saved');
    } catch (e) {
      AppLogger.error('Failed to save access token', e);
      throw Exception('Failed to save access token');
    }
  }

  /// Get access token
  Future<String?> getAccessToken() async {
    try {
      final token = await _storage.read(key: ApiConfig.accessTokenKey);
      if (token == null || token.isEmpty) {
        AppLogger.warning('No access token found', 'TokenStorage');
      }
      return token;
    } catch (e) {
      AppLogger.error('Failed to read access token', e, null, 'TokenStorage');
      return null;
    }
  }

  /// Save refresh token
  Future<void> saveRefreshToken(String token) async {
    try {
      await _storage.write(key: ApiConfig.refreshTokenKey, value: token);
    } catch (e) {
      throw Exception('Failed to save refresh token: $e');
    }
  }

  /// Get refresh token
  Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: ApiConfig.refreshTokenKey);
    } catch (e) {
      throw Exception('Failed to read refresh token: $e');
    }
  }

  /// Save user data
  Future<void> saveUserData(String userData) async {
    try {
      await _storage.write(key: ApiConfig.userDataKey, value: userData);
    } catch (e) {
      throw Exception('Failed to save user data: $e');
    }
  }

  /// Get user data
  Future<String?> getUserData() async {
    try {
      return await _storage.read(key: ApiConfig.userDataKey);
    } catch (e) {
      throw Exception('Failed to read user data: $e');
    }
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // ============================================================================
  // MULTI-ACCOUNT SUPPORT (Instagram-style)
  // ============================================================================

  /// Save access token for a specific user ID
  Future<void> saveAccessTokenForUser(String userId, String token) async {
    try {
      await _storage.write(key: '${ApiConfig.accessTokenKey}_$userId', value: token);
    } catch (e) {
      throw Exception('Failed to save access token for user: $e');
    }
  }

  /// Get access token for a specific user ID
  Future<String?> getAccessTokenForUser(String userId) async {
    try {
      return await _storage.read(key: '${ApiConfig.accessTokenKey}_$userId');
    } catch (e) {
      return null;
    }
  }

  /// Save user data for a specific user ID
  Future<void> saveUserDataForUser(String userId, String userData) async {
    try {
      await _storage.write(key: '${ApiConfig.userDataKey}_$userId', value: userData);
    } catch (e) {
      throw Exception('Failed to save user data for user: $e');
    }
  }

  /// Get user data for a specific user ID
  Future<String?> getUserDataForUser(String userId) async {
    try {
      return await _storage.read(key: '${ApiConfig.userDataKey}_$userId');
    } catch (e) {
      return null;
    }
  }

  // Multi-account storage keys
  static const String currentUserIdKey = 'histeeria_current_user_id';
  static const String linkedAccountsKey = 'histeeria_linked_accounts';

  /// Set current active user ID
  Future<void> setCurrentUserId(String userId) async {
    try {
      await _storage.write(key: currentUserIdKey, value: userId);
      
      // Sync the user-specific keys to the main keys for ApiClient
      final token = await getAccessTokenForUser(userId);
      final userData = await getUserDataForUser(userId);
      
      if (token != null) {
        await _storage.write(key: ApiConfig.accessTokenKey, value: token);
      } else {
        // Essential: clear main token if we don't have it for this user
        await _storage.delete(key: ApiConfig.accessTokenKey);
      }
      
      if (userData != null) {
        await _storage.write(key: ApiConfig.userDataKey, value: userData);
      } else {
        await _storage.delete(key: ApiConfig.userDataKey);
      }
    } catch (e) {
      throw Exception('Failed to set current user ID: $e');
    }
  }

  /// Get current active user ID
  Future<String?> getCurrentUserId() async {
    try {
      return await _storage.read(key: currentUserIdKey);
    } catch (e) {
      return null;
    }
  }

  /// Save linked accounts list
  Future<void> saveLinkedAccounts(List<Map<String, dynamic>> accounts) async {
    try {
      final json = jsonEncode(accounts);
      await _storage.write(key: linkedAccountsKey, value: json);
    } catch (e) {
      throw Exception('Failed to save linked accounts: $e');
    }
  }

  /// Get linked accounts list
  Future<List<Map<String, dynamic>>> getLinkedAccounts() async {
    try {
      final json = await _storage.read(key: linkedAccountsKey);
      if (json == null || json.isEmpty) {
        return [];
      }
      final List<dynamic> decoded = jsonDecode(json);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// Remove token and data for a specific user
  Future<void> removeUserData(String userId) async {
    try {
      await Future.wait([
        _storage.delete(key: '${ApiConfig.accessTokenKey}_$userId'),
        _storage.delete(key: '${ApiConfig.userDataKey}_$userId'),
      ]);
    } catch (e) {
      throw Exception('Failed to remove user data: $e');
    }
  }

  /// Clear all tokens and user data (including multi-account)
  Future<void> clearAll() async {
    try {
      // Get all linked accounts first
      final accounts = await getLinkedAccounts();
      
      // Remove tokens for all linked accounts
      for (final account in accounts) {
        final userId = account['user_id'] as String?;
        if (userId != null) {
          await removeUserData(userId);
        }
      }
      
      // Clear main keys
      await Future.wait([
        _storage.delete(key: ApiConfig.accessTokenKey),
        _storage.delete(key: ApiConfig.refreshTokenKey),
        _storage.delete(key: ApiConfig.userDataKey),
        _storage.delete(key: currentUserIdKey),
        _storage.delete(key: linkedAccountsKey),
      ]);
    } catch (e) {
      throw Exception('Failed to clear tokens: $e');
    }
  }

  /// Clear data for current user only (logout current account)
  Future<void> clearCurrentUser() async {
    try {
      final currentUserId = await getCurrentUserId();
      if (currentUserId != null) {
        await removeUserData(currentUserId);
      }
      
      // Clear main keys
      await Future.wait([
        _storage.delete(key: ApiConfig.accessTokenKey),
        _storage.delete(key: ApiConfig.refreshTokenKey),
        _storage.delete(key: ApiConfig.userDataKey),
        _storage.delete(key: currentUserIdKey),
      ]);
      
      // Remove from linked accounts
      final accounts = await getLinkedAccounts();
      final updatedAccounts = accounts.where((a) => a['user_id'] != currentUserId).toList();
      await saveLinkedAccounts(updatedAccounts);
    } catch (e) {
      throw Exception('Failed to clear current user: $e');
    }
  }
}
