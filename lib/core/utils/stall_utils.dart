import '../../../models/stall_model.dart';

/// Utility class for stall-related calculations
/// Provides real-time open/closed status based on Philippine time (UTC+8)
class StallUtils {
  /// Check if a stall is currently open based on Philippine time
  static bool isStallOpenNow(StallModel stall) {
    try {
      // Get current Philippine time (UTC+8)
      final now = DateTime.now().toUtc().add(const Duration(hours: 8));
      
      // Check operating days first
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final currentDay = days[now.weekday - 1];
      
      // Convert daysOpen array to comma-separated string for checking
      final operatingDays = stall.daysOpen.join(',');
      
      if (!isDayIncluded(operatingDays, currentDay)) {
        return false;
      }
      
      // Parse opening and closing times
      final opening = parseTime(stall.openTime, now);
      final closing = parseTime(stall.closeTime, now);
      
      if (opening == null || closing == null) {
        return stall.isActive; // fallback to DB value
      }
      
      final currentMinutes = now.hour * 60 + now.minute;
      final openMinutes = opening.hour * 60 + opening.minute;
      final closeMinutes = closing.hour * 60 + closing.minute;
      
      return currentMinutes >= openMinutes && currentMinutes < closeMinutes;
    } catch (e) {
      return stall.isActive; // fallback on error
    }
  }

  /// Parse time string like "5:00 AM" or "12:00 PM"
  static DateTime? parseTime(String timeStr, DateTime ref) {
    try {
      timeStr = timeStr.trim().toUpperCase();
      final parts = timeStr.split(' ');
      final timeParts = parts[0].split(':');
      final amPm = parts.length > 1 ? parts[1] : 'AM';
      
      int hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      
      if (amPm == 'PM' && hour != 12) hour += 12;
      if (amPm == 'AM' && hour == 12) hour = 0;
      
      return DateTime(ref.year, ref.month, ref.day, hour, minute);
    } catch (e) {
      return null;
    }
  }

  /// Check if currentDay is included in the operatingDays range
  static bool isDayIncluded(String operatingDays, String currentDay) {
    try {
      // Check for "Mon-Sun" or similar all-week patterns
      if (operatingDays.toLowerCase().contains('sun') &&
          operatingDays.toLowerCase().contains('mon')) {
        return true;
      }
      
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      
      // Handle range like "Mon-Sat"
      if (operatingDays.contains('-')) {
        final parts = operatingDays.split('-');
        final startIdx = days.indexOf(parts[0].trim());
        final endIdx = days.indexOf(parts[1].trim());
        final currentIdx = days.indexOf(currentDay);
        
        if (startIdx == -1 || endIdx == -1) {
          return true; // fallback: assume open
        }
        
        // Handle normal range
        if (startIdx <= endIdx) {
          return currentIdx >= startIdx && currentIdx <= endIdx;
        } else {
          // Handle wraparound (e.g., Sat-Mon)
          return currentIdx >= startIdx || currentIdx <= endIdx;
        }
      }
      
      // Check if current day is in the comma-separated list
      return operatingDays.contains(currentDay);
    } catch (e) {
      return true; // fallback: assume open
    }
  }
}
