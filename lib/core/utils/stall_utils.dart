import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/stall_model.dart';

/// Utility class for stall-related calculations
/// Provides real-time open/closed status based on Philippine time (UTC+8)
class StallUtils {
  /// Check if a stall is currently open based on real operating days + hours.
  /// Explicit non-open statuses always override to closed.
  static bool isStallOpenNow(StallModel stall) {
    final status = stall.status.trim().toLowerCase();

    // If status is explicitly set and not 'open', always show as closed
    if (status.isNotEmpty && status != 'open') {
      return false;
    }

    final now = DateTime.now();

    // Check if today is an operating day
    final operatingDays = stall.daysOpen.join(', ');
    if (!_isTodayOperatingDay(operatingDays)) {
      return false;
    }

    // Check if current time is within operating hours
    final operatingHours = '${stall.openTime} - ${stall.closeTime}';
    return _isWithinOperatingHours(operatingHours, now);
  }

  static bool _isTodayOperatingDay(String operatingDays) {
    if (operatingDays.isEmpty) return true;

    final now = DateTime.now();
    final todayIndex = now.weekday;
    final days = operatingDays.trim();
    final normalized = days.toLowerCase();

    if (normalized == 'daily' ||
        normalized == 'everyday' ||
        normalized == 'every day') {
      return true;
    }

    final tokens = days
        .replaceAll('|', ',')
        .split(',')
        .map((d) => d.trim())
        .where((d) => d.isNotEmpty)
        .toList();

    final candidates = tokens.isEmpty ? <String>[days] : tokens;

    for (final token in candidates) {
      final clean = token.replaceAll('.', '').trim();

      if (clean.contains('-') || clean.toLowerCase().contains(' to ')) {
        final parts = clean.split(RegExp(r'\s*-\s*|\s+to\s+', caseSensitive: false));
        if (parts.length == 2) {
          final startDay = _toWeekday(parts[0]);
          final endDay = _toWeekday(parts[1]);
          if (startDay != null && endDay != null) {
            if (startDay <= endDay) {
              if (todayIndex >= startDay && todayIndex <= endDay) {
                return true;
              }
            } else {
              if (todayIndex >= startDay || todayIndex <= endDay) {
                return true;
              }
            }
          }
        }
        continue;
      }

      final singleDay = _toWeekday(clean);
      if (singleDay != null && singleDay == todayIndex) {
        return true;
      }
    }

    // Conservative default to avoid false "open" labels
    return false;
  }

  static bool _isWithinOperatingHours(String operatingHours, DateTime now) {
    if (operatingHours.isEmpty) return false;

    final normalized = operatingHours
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .trim();
    final parts = normalized
        .split(RegExp(r'\s*-\s*|\s+TO\s+', caseSensitive: false))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.length != 2) return false;

    final openTime = _parseTime(parts[0].trim(), now);
    final closeTime = _parseTime(parts[1].trim(), now);
    if (openTime == null || closeTime == null) return false;

    final nowMinutes = now.hour * 60 + now.minute;
    final openMinutes = openTime.hour * 60 + openTime.minute;
    final closeMinutes = closeTime.hour * 60 + closeTime.minute;

    // Overnight schedule e.g. 10:00 PM - 6:00 AM
    if (openMinutes > closeMinutes) {
      return nowMinutes >= openMinutes || nowMinutes <= closeMinutes;
    }

    return nowMinutes >= openMinutes && nowMinutes <= closeMinutes;
  }

  static DateTime? _parseTime(String timeStr, DateTime date) {
    try {
      final t = timeStr
          .trim()
          .toUpperCase()
          .replaceAll('.', '')
          .replaceAll(RegExp(r'\s+'), ' ');
      final isPM = t.contains('PM');
      final isAM = t.contains('AM');

      final timePart = t.replaceAll('AM', '').replaceAll('PM', '').trim();
      final colonParts = timePart.split(':');

      int hour = int.parse(colonParts[0].trim());
      final int minute =
          colonParts.length > 1 ? int.parse(colonParts[1].trim()) : 0;

      if (minute < 0 || minute > 59) return null;

      if (isPM && hour != 12) {
        hour += 12;
      } else if (isAM && hour == 12) {
        hour = 0;
      }

      // If AM/PM is missing, treat as 24-hour time.
      if (!isAM && !isPM && (hour < 0 || hour > 23)) return null;
      if ((isAM || isPM) && (hour < 0 || hour > 23)) return null;

      return DateTime(date.year, date.month, date.day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  static int? _toWeekday(String rawDay) {
    final key = rawDay.trim().toLowerCase();
    switch (key) {
      case 'mon':
      case 'monday':
        return 1;
      case 'tue':
      case 'tues':
      case 'tuesday':
        return 2;
      case 'wed':
      case 'wednesday':
        return 3;
      case 'thu':
      case 'thur':
      case 'thurs':
      case 'thursday':
        return 4;
      case 'fri':
      case 'friday':
        return 5;
      case 'sat':
      case 'saturday':
        return 6;
      case 'sun':
      case 'sunday':
        return 7;
      default:
        return null;
    }
  }

  static Map<String, dynamic> getStallStatusInfo(StallModel stall) {
    final status = stall.status.trim().toLowerCase();

    if (status.isNotEmpty) {
      switch (status) {
        case 'open':
          if (isStallOpenNow(stall)) {
            return {
              'label': 'Open',
              'color': const Color(0xFF2E7D32),
              'bgColor': const Color(0xFFE8F5E9),
              'borderColor': const Color(0xFF4CAF50),
              'icon': '●',
            };
          }
          return {
            'label': 'Closed',
            'color': const Color(0xFFC62828),
            'bgColor': const Color(0xFFFFEBEE),
            'borderColor': const Color(0xFFE53935),
            'icon': '●',
          };
        case 'closed':
          return {
            'label': 'Closed',
            'color': const Color(0xFFC62828),
            'bgColor': const Color(0xFFFFEBEE),
            'borderColor': const Color(0xFFE53935),
            'icon': '●',
          };
        case 'temporarily_closed':
          return {
            'label': 'Temp. Closed',
            'color': const Color(0xFFE65100),
            'bgColor': const Color(0xFFFFF3E0),
            'borderColor': const Color(0xFFFF9800),
            'icon': '⏸',
          };
        case 'renovation':
          return {
            'label': 'Renovation',
            'color': const Color(0xFF6A1B9A),
            'bgColor': const Color(0xFFF3E5F5),
            'borderColor': const Color(0xFFCE93D8),
            'icon': '🔧',
          };
        case 'coming_soon':
          return {
            'label': 'Coming Soon',
            'color': const Color(0xFF1565C0),
            'bgColor': const Color(0xFFE3F2FD),
            'borderColor': const Color(0xFF90CAF9),
            'icon': '🆕',
          };
      }
    }

    final isOpen = isStallOpenNow(stall);
    return isOpen
        ? {
            'label': 'Open',
            'color': const Color(0xFF2E7D32),
            'bgColor': const Color(0xFFE8F5E9),
            'borderColor': const Color(0xFF4CAF50),
            'icon': '●',
          }
        : {
            'label': 'Closed',
            'color': const Color(0xFFC62828),
            'bgColor': const Color(0xFFFFEBEE),
            'borderColor': const Color(0xFFE53935),
            'icon': '●',
          };
  }

  static Widget buildStatusBadge(StallModel stall) {
    final info = getStallStatusInfo(stall);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: info['bgColor'] as Color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: info['borderColor'] as Color),
      ),
      child: Text(
        '${info['icon']} ${info['label']}',
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: info['color'] as Color,
        ),
      ),
    );
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
    'seafood': 'Seafood & Fish',
    'fish': 'Seafood & Fish',
    'meat': 'Meat',
    'beef': 'Meat',
    'pork': 'Meat',
    'karne': 'Meat',
    'poultry': 'Poultry & Chicken',
    'chicken': 'Poultry & Chicken',
    'manok': 'Poultry & Chicken',
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

  static String getStatusLabel(String status) {
    switch (status) {
      case 'open':
        return '● Open';
      case 'closed':
        return '● Closed';
      case 'temporarily_closed':
        return '⏸ Temp. Closed';
      case 'renovation':
        return '🔧 Renovation';
      case 'coming_soon':
        return '🆕 Coming Soon';
      default:
        return '● Closed';
    }
  }

  static int getStatusColorHex(String status) {
    switch (status) {
      case 'open':
        return 0xFF2E7D32;
      case 'temporarily_closed':
        return 0xFFE65100;
      case 'renovation':
        return 0xFF6A1B9A;
      case 'coming_soon':
        return 0xFF1565C0;
      default:
        return 0xFFC62828;
    }
  }

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
