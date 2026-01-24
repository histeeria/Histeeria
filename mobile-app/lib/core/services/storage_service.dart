import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import '../api/api_client.dart';
import '../config/api_config.dart';

/// Storage service for file uploads
///
/// Handles uploading files to Supabase Storage via backend API
class StorageService {
  final ApiClient _apiClient = ApiClient();

  /// Upload profile picture
  ///
  /// Uploads a profile picture file and returns the public URL
  /// Note: This requires authentication, so for signup flow,
  /// we'll upload after registration completes
  Future<String> uploadProfilePicture(File imageFile) async {
    try {
      final response = await _apiClient.uploadFile<Map<String, dynamic>>(
        '${ApiConfig.account}/profile-picture',
        imageFile.path,
        fileKey: 'profile_picture',
        fromJson: (json) => json as Map<String, dynamic>,
      );

      final pictureUrl = response['profile_picture'] as String?;
      if (pictureUrl == null || pictureUrl.isEmpty) {
        throw Exception('Profile picture URL not returned from server');
      }

      return pictureUrl;
    } catch (e) {
      // Re-throw with more context
      if (e is Exception) {
        throw e;
      }
      throw Exception('Failed to upload profile picture: ${e.toString()}');
    }
  }

  /// Upload file directly to Supabase Storage (for signup flow)
  ///
  /// This is a temporary solution for signup - uploads directly to Supabase
  /// In production, you might want a public upload endpoint
  Future<String> uploadProfilePictureForSignup(File imageFile) async {
    // For signup, we'll upload after registration
    // This is a placeholder - you can implement direct Supabase upload here
    // or create a public upload endpoint in backend
    throw UnimplementedError(
      'Profile picture upload during signup requires authentication. '
      'Upload will happen after registration completes.',
    );
  }
}
