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

  /// Tag display labels
  static const Map<String, String> tagLabels = {
    // Tags
    'halal': 'Halal',
    'organic': 'Organic',
    'local': 'Local',
    'wholesale': 'Wholesale',
    'budget_friendly': 'Budget-Friendly',
    'premium': 'Premium',
    'fresh_daily': 'Fresh Daily',
    'made_to_order': 'Made to Order',
    'delivery_available': 'Delivery Available',
    'open_early': 'Opens Early',
    'open_late': 'Closes Late',
    'takeout': 'Takeout',
    'dine_in': 'Dine-in',
    // Category tags
    'rice_dealer': 'Rice Dealer',
    'dried_fish': 'Dried Fish',
    'carinderia': 'Carinderia',
    'bakery': 'Bakery',
    'kakanin': 'Kakanin',
    'snack_stand': 'Snack Stand',
    'ukay_ukay': 'Ukay-Ukay',
    'tailor_shop': 'Tailor Shop',
    'hardware': 'Hardware & Tools',
    'school_supplies': 'School Supplies',
    'home_supplies': 'Home Supplies',
    'agrivet': 'Agrivet Supplies',
    'electronics_repair': 'Electronics & Repair',
    'barber_salon': 'Barber / Salon',
  };

  /// Category display labels
  static const Map<String, String> categoryLabels = {
    'fresh': 'Fresh Produce',
    'seafood': 'Seafood',
    'fish': 'Seafood',
    'meat': 'Pork',
    'beef': 'Beef',
    'pork': 'Pork',
    'karne': 'Pork',
    'poultry': 'Poultry',
    'chicken': 'Poultry',
    'manok': 'Poultry',
    'vegetables': 'Vegetables',
    'gulay': 'Vegetables',
    'fruits': 'Fruits',
    'prutas': 'Fruits',
    'frozen': 'Frozen Goods',
    'frozen_goods': 'Frozen Goods',
    'processed': 'Processed Foods',
    'processed_foods': 'Processed Foods',
    'spices': 'Spices',
    'pampalasa': 'Spices',
    'dry_goods': 'Dry Goods',
    'drygoods': 'Dry Goods',
    'rice': 'Rice',
    'rice_dealer': 'Rice Dealer',
    'bigas': 'Rice',
    'dried_fish': 'Dried Fish',
    'bulad': 'Dried Fish',
    'daing': 'Dried Fish',
    'eatery': 'Eatery',
    'carinderia': 'Carinderia',
    'cooked': 'Cooked Food',
    'cooked_food': 'Cooked Food',
    'lutong_ulam': 'Cooked Food',
    'bakery': 'Bakery',
    'kakanin': 'Kakanin',
    'snack_stand': 'Snack Stand',
    'sari_sari': 'Sari-Sari Store',
    'sarisari': 'Sari-Sari Store',
    'sari-sari': 'Sari-Sari Store',
    'sari_sari_store': 'Sari-Sari Store',
    'retail': 'Retail',
    'clothing': 'Clothing',
    'ukay_ukay': 'Ukay-Ukay',
    'ukay-ukay': 'Ukay-Ukay',
    'ukay': 'Ukay-Ukay',
    'tailor': 'Tailor Shop',
    'tailor_shop': 'Tailor Shop',
    'general': 'General Merchandise',
    'hardware': 'Hardware & Tools',
    'tools': 'Hardware & Tools',
    'hardware_tools': 'Hardware & Tools',
    'school_supplies': 'School Supplies',
    'school': 'School Supplies',
    'home_supplies': 'Home Supplies',
    'home': 'Home Supplies',
    'agrivet': 'Agrivet Supplies',
    'agrivet_supplies': 'Agrivet Supplies',
    'services': 'Services',
    'electronics': 'Electronics & Repair',
    'repair': 'Electronics & Repair',
    'electronics_repair': 'Electronics & Repair',
    'barber': 'Barber / Salon',
    'salon': 'Barber / Salon',
    'barber_salon': 'Barber / Salon',
  };

  /// Helper to get display label for tags
  static String getTagLabel(String tag) {
    return tagLabels[tag.toLowerCase()] ??
        tag
            .replaceAll('_', ' ')
            .split(' ')
            .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
            .join(' ');
  }

  /// Helper to get display label for categories
  static String getCategoryLabel(String category) {
    return categoryLabels[category.toLowerCase()] ??
        category
            .replaceAll('_', ' ')
            .split(' ')
            .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
            .join(' ');
  }

  /// Format operating days to short format (Mon-Fri, Sat-Sun, etc.)
  static String formatOperatingDays(String days) {
    // Already in short format
    if (days.contains('Mon-') || days.length <= 10) return days;

    // Convert long day names to short
    return days
        .replaceAll('Monday', 'Mon')
        .replaceAll('Tuesday', 'Tue')
        .replaceAll('Wednesday', 'Wed')
        .replaceAll('Thursday', 'Thu')
        .replaceAll('Friday', 'Fri')
        .replaceAll('Saturday', 'Sat')
        .replaceAll('Sunday', 'Sun');
  }
}
