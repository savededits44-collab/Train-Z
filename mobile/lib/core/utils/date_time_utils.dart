import '../constants/app_constants.dart';

/// Date, time, and session policy helpers for TRAIN Z.
class DateTimeUtils {
  DateTimeUtils._();

  /// Checks if cancellation qualifies for a full credit refund (>= 12h before start).
  static bool canReturnCreditOnClientCancellation(DateTime sessionStartTime, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final difference = sessionStartTime.difference(current);
    return difference.inHours >= AppConstants.cancellationWindowHours;
  }

  /// Calculates remaining hours until session start.
  static double hoursUntilSession(DateTime sessionStartTime, {DateTime? now}) {
    final current = now ?? DateTime.now();
    return sessionStartTime.difference(current).inMinutes / 60.0;
  }

  /// Formats duration in friendly text
  static String formatDuration(int minutes) {
    if (minutes < 60) return '$minutes mins';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    return remaining == 0 ? '$hours hr' : '$hours hr $remaining min';
  }
}

