import 'package:intl/intl.dart';

/// Date utility functions
class DateUtils {
  /// Format time ago (e.g., "2h", "3d", "1w")
  static String timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '${years}y';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo';
    } else if (difference.inDays > 7) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  /// Format date for display
  static String formatDate(DateTime dateTime) {
    return DateFormat('MMM d, y').format(dateTime);
  }

  /// Format date and time
  static String formatDateTime(DateTime dateTime) {
    return DateFormat('MMM d, y • h:mm a').format(dateTime);
  }
}

/// App-specific date utilities (alias)
class AppDateUtils {
  static String timeAgo(DateTime dateTime) => DateUtils.timeAgo(dateTime);
  static String formatDate(DateTime dateTime) => DateUtils.formatDate(dateTime);
  static String formatDateTime(DateTime dateTime) => DateUtils.formatDateTime(dateTime);
}
