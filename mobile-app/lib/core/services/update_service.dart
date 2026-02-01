import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateInfo {
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;
  final bool hasUpdate;

  UpdateInfo({
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.hasUpdate,
  });
}

class UpdateService {
  static const String _githubRepo = 'histeeria/Histeeria';
  
  /// Check if a newer version is available on GitHub
  Future<UpdateInfo?> checkForUpdates() async {
    try {
      // 1. Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // e.g., "1.0.0"

      // 2. Fetch latest release from GitHub
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$_githubRepo/releases/latest'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tagName = data['tag_name'] as String; // e.g., "v1.0.1"
        final latestVersion = tagName.replaceAll('v', ''); // "1.0.1"
        final body = data['body'] as String? ?? 'New version available!';
        
        // Find APK asset
        String downloadUrl = data['html_url']; // Fallback to release page
        final assets = data['assets'] as List?;
        if (assets != null) {
          for (var asset in assets) {
            if (asset['name'].toString().endsWith('.apk')) {
              downloadUrl = asset['browser_download_url'];
              break;
            }
          }
        }

        // 3. Compare versions
        final hasUpdate = _defaultVersionCompare(currentVersion, latestVersion);

        return UpdateInfo(
          latestVersion: latestVersion,
          downloadUrl: downloadUrl,
          releaseNotes: body,
          hasUpdate: hasUpdate,
        );
      }
    } catch (e) {
      print('[UpdateService] Failed to check for updates: $e');
    }
    return null;
  }

  /// Launch the download URL
  Future<void> downloadUpdate(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Compare standard version strings (e.g. "1.0.0" vs "1.0.1")
  /// Returns true if version2 > version1
  bool _defaultVersionCompare(String v1, String v2) {
    try {
      final parts1 = v1.split('.').map((e) => int.parse(e)).toList();
      final parts2 = v2.split('.').map((e) => int.parse(e)).toList();

      for (int i = 0; i < 3; i++) {
        final p1 = i < parts1.length ? parts1[i] : 0;
        final p2 = i < parts2.length ? parts2[i] : 0;
        
        if (p2 > p1) return true;
        if (p1 > p2) return false;
      }
    } catch (e) {
      // Fallback simple string comparison
      return v2.compareTo(v1) > 0;
    }
    return false;
  }
}
