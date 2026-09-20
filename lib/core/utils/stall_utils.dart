import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/market_categories.dart';
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
              'icon': '',
            };
          }
          return {
            'label': 'Closed',
            'color': const Color(0xFFC62828),
            'bgColor': const Color(0xFFFFEBEE),
            'borderColor': const Color(0xFFE53935),
            'icon': '',
          };
        case 'closed':
          return {
            'label': 'Closed',
            'color': const Color(0xFFC62828),
            'bgColor': const Color(0xFFFFEBEE),
            'borderColor': const Color(0xFFE53935),
            'icon': '',
          };
        case 'temporarily_closed':
          return {
            'label': 'Temp. Closed',
            'color': const Color(0xFFE65100),
            'bgColor': const Color(0xFFFFF3E0),
            'borderColor': const Color(0xFFFF9800),
            'icon': '',
          };
        case 'renovation':
        case 'under_renovation':
          return {
            'label': 'Renovation',
            'color': const Color(0xFF6A1B9A),
            'bgColor': const Color(0xFFF3E5F5),
            'borderColor': const Color(0xFFCE93D8),
            'icon': '',
          };
        case 'coming_soon':
          return {
            'label': 'Coming Soon',
            'color': const Color(0xFF1565C0),
            'bgColor': const Color(0xFFE3F2FD),
            'borderColor': const Color(0xFF90CAF9),
            'icon': '',
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
            'icon': '',
          }
        : {
            'label': 'Closed',
            'color': const Color(0xFFC62828),
            'bgColor': const Color(0xFFFFEBEE),
            'borderColor': const Color(0xFFE53935),
            'icon': '',
          };
  }

  static Widget buildStatusBadge(StallModel stall) {
    final info = getStallStatusInfo(stall);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: info['bgColor'] as Color,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: info['borderColor'] as Color, width: 0.8),
      ),
      child: Text(
        info['label'] as String,
        style: GoogleFonts.poppins(
          fontSize: 11,
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
        return 'Open';
      case 'closed':
        return 'Closed';
      case 'temporarily_closed':
        return 'Temp. Closed';
      case 'renovation':
      case 'under_renovation':
        return 'Renovation';
      case 'coming_soon':
        return 'Coming Soon';
      default:
        return 'Closed';
    }
  }

  static int getStatusColorHex(String status) {
    switch (status) {
      case 'open':
        return 0xFF2E7D32;
      case 'temporarily_closed':
        return 0xFFE65100;
      case 'renovation':
      case 'under_renovation':
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

  /// Format operating days to clean short format (Daily, Mon–Fri, Mon–Sat, etc.)
  static String formatOperatingDays(String rawDays) {
    final trimmed = rawDays.trim();
    if (trimmed.isEmpty) return 'Days not set';

    final normalized = trimmed
        .replaceAll('Monday', 'Mon')
        .replaceAll('Tuesday', 'Tue')
        .replaceAll('Wednesday', 'Wed')
        .replaceAll('Thursday', 'Thu')
        .replaceAll('Friday', 'Fri')
        .replaceAll('Saturday', 'Sat')
        .replaceAll('Sunday', 'Sun');

    final parts = normalized
        .split(RegExp(r'[,|/]|\s+and\s+|\s+to\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (parts.isEmpty) return trimmed;

    final lowerParts = parts.map((p) => p.toLowerCase()).toSet();

    // Check if all 7 days (Daily)
    final allWeekdays = {'mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'};
    if (allWeekdays.every(lowerParts.contains)) {
      return 'Daily (Mon – Sun)';
    }

    // Check if 6 days (Mon–Sat)
    final monToSat = {'mon', 'tue', 'wed', 'thu', 'fri', 'sat'};
    if (monToSat.length == lowerParts.length &&
        monToSat.every(lowerParts.contains)) {
      return 'Mon – Sat';
    }

    // Check if Mon–Fri (Weekdays)
    final monToFri = {'mon', 'tue', 'wed', 'thu', 'fri'};
    if (monToFri.length == lowerParts.length &&
        monToFri.every(lowerParts.contains)) {
      return 'Mon – Fri (Weekdays)';
    }

    // Check if Sat–Sun (Weekends)
    final weekends = {'sat', 'sun'};
    if (weekends.length == lowerParts.length &&
        weekends.every(lowerParts.contains)) {
      return 'Sat – Sun (Weekends)';
    }

    // Sort days chronologically (Mon -> Sun) for consistent display
    const Map<String, int> weekdayOrder = {
      'mon': 1,
      'tue': 2,
      'wed': 3,
      'thu': 4,
      'fri': 5,
      'sat': 6,
      'sun': 7,
    };

    final uniqueDays = <String, String>{};
    for (final p in parts) {
      final key = p.toLowerCase();
      if (weekdayOrder.containsKey(key) && !uniqueDays.containsKey(key)) {
        final formatted = p.length >= 3
            ? p[0].toUpperCase() + p.substring(1, 3).toLowerCase()
            : p;
        uniqueDays[key] = formatted;
      } else if (!uniqueDays.containsKey(key)) {
        uniqueDays[key] = p;
      }
    }

    if (uniqueDays.isNotEmpty) {
      final sortedEntries = uniqueDays.entries.toList()
        ..sort((a, b) {
          final orderA = weekdayOrder[a.key] ?? 99;
          final orderB = weekdayOrder[b.key] ?? 99;
          return orderA.compareTo(orderB);
        });
      return sortedEntries.map((e) => e.value).join(', ');
    }

    return parts.join(', ');
  }

  /// Converts text to clean Title Case, preserving Roman numerals (e.g. II, IV) and acronyms.
  static String toTitleCase(String text) {
    if (text.trim().isEmpty) return '';
    final words = text.trim().split(RegExp(r'\s+'));
    final buffer = <String>[];

    final romanNumerals = {'i', 'ii', 'iii', 'iv', 'v', 'vi', 'vii', 'viii', 'ix', 'x'};

    for (final rawWord in words) {
      final clean = rawWord.replaceAll(RegExp(r'[^\w#]'), '');
      final lower = clean.toLowerCase();

      // Check if word has trailing punctuation like comma or period
      String suffix = '';
      if (rawWord.endsWith(',')) suffix = ',';
      if (rawWord.endsWith('.')) suffix = '.';

      if (romanNumerals.contains(lower)) {
        buffer.add('${lower.toUpperCase()}$suffix');
      } else if (lower.startsWith('stall#')) {
        final numPart = lower.replaceAll('stall#', '');
        buffer.add('Stall #$numPart$suffix');
      } else if (lower.startsWith('#')) {
        final numPart = lower.replaceAll('#', '');
        if (buffer.isNotEmpty && buffer.last.toLowerCase().contains('stall')) {
          buffer.add('#$numPart$suffix');
        } else {
          buffer.add('Stall #$numPart$suffix');
        }
      } else if (lower.length <= 2 && !{'at', 'in', 'on', 'to', 'of'}.contains(lower)) {
        buffer.add('${lower.toUpperCase()}$suffix');
      } else if (lower.isNotEmpty) {
        final title = lower[0].toUpperCase() + lower.substring(1);
        buffer.add('$title$suffix');
      }
    }
    return buffer.join(' ');
  }

  /// Formats stall location cleanly with hierarchy: Building - Stall Number - Address
  /// Ensures Title Case formatting without screaming ALL-CAPS.
  static String formatStallLocation({
    String? building,
    String? stallNumber,
    String? address,
    String fallback = 'Ligao City Public Market',
  }) {
    final parts = parseStallLocationParts(
      building: building,
      stallNumber: stallNumber,
      address: address,
      fallbackMarket: fallback,
      fallbackStreet: '',
    );
    if (parts.marketLocation == fallback && parts.streetAddress.isEmpty) {
      return fallback;
    }
    if (parts.streetAddress.isEmpty) {
      return parts.marketLocation;
    }
    if (parts.marketLocation == fallback) {
      return parts.streetAddress;
    }
    return '${parts.marketLocation} • ${parts.streetAddress}';
  }

  /// Parses raw stall location fields into two structured, non-redundant rows:
  /// - Row 1 (marketLocation): Building/Section name + Stall number (e.g. "Building I, Stall #15")
  /// - Row 2 (streetAddress): Barangay + City only, no repeated building or market-site name (e.g. "Bagumbayan, Ligao City")
  static StallLocationParts parseStallLocationParts({
    String? building,
    String? stallNumber,
    String? address,
    String fallbackMarket = 'Ligao Public Market',
    String fallbackStreet = 'Bagumbayan, Ligao City',
  }) {
    String bld = (building ?? '').trim();
    String stNum = (stallNumber ?? '').trim();
    String addr = (address ?? '').trim();

    // 1. Isolate clean stall number token
    // Extract only the code directly following 'stall' / '#' (e.g. '15', '5', '19A', 'K-02')
    // Discards dirty trailing text like '5 EXTENSION V MARKET SITE BAGUMBAYAN'
    String cleanStallNum = '';
    if (stNum.isNotEmpty) {
      final match = RegExp(
        r'(?:stall\s*(?:#|no\.?|number)?\s*|^#\s*)([0-9a-zA-Z_-]+)',
        caseSensitive: false,
      ).firstMatch(stNum);
      if (match != null) {
        cleanStallNum = 'Stall #${match.group(1)}';
      } else {
        final cleanRaw = stNum.replaceFirst(
          RegExp(r'^(stall\s*(#|no\.?|number)?\s*)+', caseSensitive: false),
          '',
        ).trim();
        if (cleanRaw.isNotEmpty) {
          cleanStallNum = 'Stall #$cleanRaw';
        }
      }
    }

    // If stall number is not yet found, attempt extraction from address
    if (cleanStallNum.isEmpty && addr.isNotEmpty) {
      final match = RegExp(
        r'stall\s*(?:#|no\.?|number)?\s*([0-9a-zA-Z_-]+)',
        caseSensitive: false,
      ).firstMatch(addr);
      if (match != null) {
        cleanStallNum = 'Stall #${match.group(1)}';
      }
    }

    // 2. Extract or clean building / section
    if (bld.isEmpty && addr.isNotEmpty) {
      final bldMatch = RegExp(
        r'(building\s+[ivx0-9]+|extension\s+[ivx0-9]+|new\s+camarin|wet\s+market|meat\s+section|fish\s+section|fruits?\s+section|vegetables?\s+section)',
        caseSensitive: false,
      ).firstMatch(addr);
      if (bldMatch != null) {
        bld = bldMatch.group(0)!;
      }
    }

    if (bld.isNotEmpty) {
      bld = toTitleCase(bld);
    }

    // 3. Compose Row 1: Market Location
    final row1Parts = <String>[];
    if (bld.isNotEmpty) {
      row1Parts.add(bld);
    }
    if (cleanStallNum.isNotEmpty) {
      row1Parts.add(cleanStallNum);
    }
    final marketLocation =
        row1Parts.isNotEmpty ? row1Parts.join(', ') : fallbackMarket;

    // 4. Compose Row 2: Clean Street / Barangay / City Address
    String cleanAddr = addr;

    // Strip stall number pattern from address
    cleanAddr = cleanAddr.replaceAll(
      RegExp(r'stall\s*(?:#|no\.?|number)?\s*[0-9a-zA-Z_-]+', caseSensitive: false),
      '',
    );
    cleanAddr = cleanAddr.replaceAll(
      RegExp(r'^#\s*[0-9a-zA-Z_-]+', caseSensitive: false),
      '',
    );

    // Strip building / section pattern from address
    if (bld.isNotEmpty) {
      cleanAddr = cleanAddr.replaceAll(
        RegExp(RegExp.escape(bld), caseSensitive: false),
        '',
      );
    }
    cleanAddr = cleanAddr.replaceAll(
      RegExp(
        r'(building\s+[ivx0-9]+|extension\s+[ivx0-9]+|new\s+camarin|wet\s+market|meat\s+section|fish\s+section|fruits?\s+section|vegetables?\s+section)',
        caseSensitive: false,
      ),
      '',
    );

    // Strip redundant "Market Site"
    cleanAddr = cleanAddr.replaceAll(
      RegExp(r'market\s+site', caseSensitive: false),
      '',
    );

    // Clean up residual punctuation and separators
    cleanAddr = cleanAddr
        .replaceAll(RegExp(r'^[,\s•-]+|[,\s•-]+$'), '')
        .replaceAll(RegExp(r',\s*,'), ',')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleanAddr.isNotEmpty) {
      cleanAddr = toTitleCase(cleanAddr);
    }

    // Normalize City: ensure "Ligao City" presence without duplication
    if (cleanAddr.isEmpty) {
      cleanAddr = fallbackStreet;
    } else {
      final lower = cleanAddr.toLowerCase();
      if (!lower.contains('ligao')) {
        cleanAddr = '$cleanAddr, Ligao City';
      } else if (!lower.contains('ligao city')) {
        cleanAddr = cleanAddr.replaceAll(
          RegExp(r'ligao', caseSensitive: false),
          'Ligao City',
        );
      }
      // Deduplicate consecutive "Ligao City, Ligao City"
      cleanAddr = cleanAddr.replaceAll(
        RegExp(r'Ligao City,\s*Ligao City', caseSensitive: false),
        'Ligao City',
      );
      cleanAddr = cleanAddr
          .replaceAll(RegExp(r'^[,\s•-]+|[,\s•-]+$'), '')
          .replaceAll(RegExp(r',\s*,'), ', ')
          .trim();
    }

    return StallLocationParts(
      marketLocation: marketLocation,
      streetAddress: cleanAddr,
    );
  }

  /// Formats physical location cleanly by de-duplicating section if already contained in address.
  static String formatLocation(
    String? section,
    String address, {
    String fallback = 'Ligao City Public Market',
  }) {
    final sec = section?.trim() ?? '';
    final addr = address.trim();
    if (sec.isEmpty && addr.isEmpty) return fallback;
    if (sec.isEmpty) {
      return toTitleCase(addr);
    }
    if (addr.isEmpty) {
      return 'Section $sec, Ligao Public Market';
    }
    return formatStallLocation(
      building: sec,
      address: addr,
      fallback: fallback,
    );
  }

  /// Formats stall number cleanly, eliminating duplicated prefixes like "STALL #STALL #1".
  static String formatStallNumber(String? rawStallNumber) {
    if (rawStallNumber == null) return '';
    final trimmed = rawStallNumber.trim();
    if (trimmed.isEmpty) return '';

    // Strip duplicated or redundant leading prefixes
    final clean = trimmed
        .replaceFirst(
          RegExp(r'^(stall\s*(#|no\.?|number)?\s*)+', caseSensitive: false),
          '',
        )
        .trim();

    if (clean.isEmpty) return 'Stall';
    return 'Stall #$clean';
  }

  /// Formats products into a clean 1-line summary (e.g. "Item 1, Item 2 • +3 more").
  static String formatProductsSummary(List<String> products, {int maxPreview = 2}) {
    if (products.isEmpty) return '';
    if (products.length <= maxPreview) {
      return products.join(', ');
    }
    final preview = products.take(maxPreview).join(', ');
    final remaining = products.length - maxPreview;
    return '$preview • +$remaining more';
  }

  /// Formats tags into a clean 1-line summary (e.g. "Tag 1, Tag 2 • +2 more").
  static String formatTagsSummary(List<String> tags, {int maxPreview = 2}) {
    if (tags.isEmpty) return '';
    final formatted = tags.map(getTagLabel).toList();
    if (formatted.length <= maxPreview) {
      return formatted.join(', ');
    }
    final preview = formatted.take(maxPreview).join(', ');
    final remaining = formatted.length - maxPreview;
    return '$preview • +$remaining more';
  }

  /// Determines if a [stall] matches a given [category] and optional [subcategory].
  /// Matches against primary category, id, aliases, keywords, and subcategories.
  static bool matchesCategory(
    StallModel stall,
    String category, [
    String? subcategory,
  ]) {
    if (category == 'All') return true;

    final targetItem = MarketCategories.findCategory(category);
    final stallItem = MarketCategories.findCategory(stall.category);

    bool categoryMatched = false;
    if (targetItem != null && stallItem != null) {
      if (targetItem.id == stallItem.id) {
        categoryMatched = true;
      }
    }

    if (!categoryMatched) {
      final stallCat = stall.category.toLowerCase();
      final targetCat = category.toLowerCase();
      if (stallCat.contains(targetCat) || targetCat.contains(stallCat)) {
        categoryMatched = true;
      }
    }

    if (!categoryMatched && targetItem != null) {
      final stallCat = stall.category.toLowerCase();
      final allWords = [
        ...targetItem.keywords,
        ...targetItem.subcategories,
        targetItem.shortName.toLowerCase(),
        targetItem.displayName.toLowerCase(),
      ];
      categoryMatched = allWords.any((w) =>
          stallCat.contains(w.toLowerCase()) ||
          stall.products.any((p) => p.toLowerCase().contains(w.toLowerCase())));
    }

    if (!categoryMatched) return false;

    // If subcategory is selected, filter strictly by subcategory (products are not subcategories)
    if (subcategory != null && subcategory.isNotEmpty) {
      final subNorm = subcategory.toLowerCase();
      final inSubcategories = stall.subcategories.any((s) =>
          s.toLowerCase().contains(subNorm) || subNorm.contains(s.toLowerCase()));
      final inTags = stall.tags.any((t) =>
          t.toLowerCase().contains(subNorm) || subNorm.contains(t.toLowerCase()));
      final inCategories = stall.categories.any((c) =>
          c.toLowerCase().contains(subNorm) || subNorm.contains(c.toLowerCase()));
      final inName = stall.name.toLowerCase().contains(subNorm);
      return inSubcategories || inTags || inCategories || inName;
    }

    return true;
  }
}

/// Structured stall location parts separated into market location and street address.
class StallLocationParts {
  final String marketLocation;
  final String streetAddress;

  const StallLocationParts({
    required this.marketLocation,
    required this.streetAddress,
  });

  @override
  String toString() => '$marketLocation • $streetAddress';
}

