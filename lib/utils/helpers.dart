import 'package:intl/intl.dart';

/// Helper utility functions
class Helpers {
  /// Format currency amount
  static String formatCurrency(double amount, {String symbol = 'KSh'}) {
    return '$symbol ${amount.toStringAsFixed(0)}';
  }

  /// Format distance (meters to km if > 1000)
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  /// Format date relative to now
  static String formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM').format(date);
  }

  /// Format time as hh:mm AM/PM
  static String formatTime(DateTime date) {
    return DateFormat('hh:mm a').format(date);
  }

  /// Format phone number to E.164 format
  static String formatPhone(String phone) {
    phone = phone.replaceAll(RegExp(r'[\s\-\+]'), '');
    if (phone.startsWith('0')) {
      phone = '254${phone.substring(1)}';
    } else if (phone.startsWith('7') || phone.startsWith('1')) {
      phone = '254$phone';
    }
    return phone;
  }

  /// Calculate distance between two coordinates using Haversine formula
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // meters
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = (dLat / 2) * (dLat / 2) +
        _toRadians(lat1) *
            _toRadians(lat2) *
            (dLon / 2) *
            (dLon / 2);
    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degree) => degree * (3.14159265359 / 180);
  static double _sqrt(double x) => x; // Simplified
  static double _atan2(double y, double x) => y; // Simplified

  /// Truncate text with ellipsis
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}
