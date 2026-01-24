import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'app_logger.dart';

/// Secure File Storage Utility
///
/// Ensures all files are stored in app-private directories
/// with proper permissions (no world-readable files)
class SecureFileStorage {
  /// Get app documents directory (private to app)
  static Future<Directory> getAppDocumentsDirectory() async {
    return await getApplicationDocumentsDirectory();
  }

  /// Get app cache directory (private, temporary)
  static Future<Directory> getAppCacheDirectory() async {
    return await getApplicationCacheDirectory();
  }

  /// Get app support directory (private, persistent)
  static Future<Directory> getAppSupportDirectory() async {
    return await getApplicationSupportDirectory();
  }

  /// Save file securely (app-private directory)
  static Future<File> saveFileSecurely({
    required List<int> bytes,
    required String filename,
    bool cache = false,
  }) async {
    try {
      final directory = cache 
          ? await getAppCacheDirectory()
          : await getAppDocumentsDirectory();
      
      final file = File('${directory.path}/$filename');
      await file.writeAsBytes(bytes);
      
      AppLogger.debug('File saved securely: $filename', 'SecureFileStorage');
      return file;
    } catch (e) {
      AppLogger.error('Failed to save file securely', e, null, 'SecureFileStorage');
      rethrow;
    }
  }

  /// Read file securely
  static Future<List<int>> readFileSecurely(String filename, {bool cache = false}) async {
    try {
      final directory = cache 
          ? await getAppCacheDirectory()
          : await getAppDocumentsDirectory();
      
      final file = File('${directory.path}/$filename');
      
      if (!await file.exists()) {
        throw FileSystemException('File not found', file.path);
      }
      
      return await file.readAsBytes();
    } catch (e) {
      AppLogger.error('Failed to read file securely', e, null, 'SecureFileStorage');
      rethrow;
    }
  }

  /// Delete file securely
  static Future<void> deleteFileSecurely(String filename, {bool cache = false}) async {
    try {
      final directory = cache 
          ? await getAppCacheDirectory()
          : await getAppDocumentsDirectory();
      
      final file = File('${directory.path}/$filename');
      
      if (await file.exists()) {
        await file.delete();
        AppLogger.debug('File deleted securely: $filename', 'SecureFileStorage');
      }
    } catch (e) {
      AppLogger.error('Failed to delete file securely', e, null, 'SecureFileStorage');
      rethrow;
    }
  }

  /// Clear cache directory
  static Future<void> clearCache() async {
    try {
      final directory = await getAppCacheDirectory();
      
      if (await directory.exists()) {
        await for (final entity in directory.list()) {
          if (entity is File) {
            await entity.delete();
          } else if (entity is Directory) {
            await entity.delete(recursive: true);
          }
        }
        AppLogger.info('Cache cleared', 'SecureFileStorage');
      }
    } catch (e) {
      AppLogger.error('Failed to clear cache', e, null, 'SecureFileStorage');
      rethrow;
    }
  }

  /// Get cache size
  static Future<int> getCacheSize() async {
    try {
      final directory = await getAppCacheDirectory();
      int totalSize = 0;
      
      if (await directory.exists()) {
        await for (final entity in directory.list(recursive: true)) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }
      
      return totalSize;
    } catch (e) {
      AppLogger.error('Failed to get cache size', e, null, 'SecureFileStorage');
      return 0;
    }
  }

  /// Format bytes to human-readable size
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Validate file path (ensure it's within app directory)
  static Future<bool> isPathSecure(String filePath) async {
    try {
      final appDir = await getAppDocumentsDirectory();
      final cacheDir = await getAppCacheDirectory();
      final supportDir = await getAppSupportDirectory();
      
      final file = File(filePath);
      final absolutePath = file.absolute.path;
      
      // Check if file is within any app directory
      return absolutePath.startsWith(appDir.path) ||
             absolutePath.startsWith(cacheDir.path) ||
             absolutePath.startsWith(supportDir.path);
    } catch (e) {
      AppLogger.error('Failed to validate file path', e, null, 'SecureFileStorage');
      return false;
    }
  }

  /// Get file info
  static Future<FileInfo?> getFileInfo(String filename, {bool cache = false}) async {
    try {
      final directory = cache 
          ? await getAppCacheDirectory()
          : await getAppDocumentsDirectory();
      
      final file = File('${directory.path}/$filename');
      
      if (!await file.exists()) {
        return null;
      }
      
      final stat = await file.stat();
      return FileInfo(
        path: file.path,
        size: stat.size,
        modified: stat.modified,
        accessed: stat.accessed,
      );
    } catch (e) {
      AppLogger.error('Failed to get file info', e, null, 'SecureFileStorage');
      return null;
    }
  }
}

/// File information
class FileInfo {
  final String path;
  final int size;
  final DateTime modified;
  final DateTime accessed;

  FileInfo({
    required this.path,
    required this.size,
    required this.modified,
    required this.accessed,
  });

  String get formattedSize => SecureFileStorage.formatBytes(size);
}
