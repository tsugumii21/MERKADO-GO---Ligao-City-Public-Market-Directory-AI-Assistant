import 'package:flutter/material.dart';

/// Semantic colors for a market zone category
class ZoneColorSet {
  final Color fill;
  final Color accent;
  final Color outline;
  final String displayName;

  const ZoneColorSet({
    required this.fill,
    required this.accent,
    required this.outline,
    required this.displayName,
  });
}

/// Canonical 17-Category Market Zone Color Palette
/// Source of truth: MerkadoGo Master Context Â§5 and Core Market Zones spec.
class ZonePalette {
  ZonePalette._();

  static const double strokeWidth = 2.0;

  // 17 Vendor Categories
  static const produce = ZoneColorSet(
    fill: Color(0xFF4CAF50),
    accent: Color(0xFFA5D6A7),
    outline: Color(0xFF2E7D32),
    displayName: 'Produce',
  );

  static const meat = ZoneColorSet(
    fill: Color(0xFFE57373),
    accent: Color(0xFFFFCDD2),
    outline: Color(0xFFC62828),
    displayName: 'Meat',
  );

  static const mixedMeat = ZoneColorSet(
    fill: Color(0xFFC2185B),
    accent: Color(0xFFF8BBD0),
    outline: Color(0xFF880E4F),
    displayName: 'Mixed Meat',
  );

  static const fish = ZoneColorSet(
    fill: Color(0xFF64B5F6),
    accent: Color(0xFFBBDEFB),
    outline: Color(0xFF1565C0),
    displayName: 'Fish',
  );

  static const dryGoods = ZoneColorSet(
    fill: Color(0xFFFFD54F),
    accent: Color(0xFFFFE082),
    outline: Color(0xFFFF8F00),
    displayName: 'Dry Goods',
  );

  static const riceAndGrains = ZoneColorSet(
    fill: Color(0xFFE5A93C),
    accent: Color(0xFFFFF3D1),
    outline: Color(0xFFB27300),
    displayName: 'Rice & Grains',
  );

  static const thriftApparel = ZoneColorSet(
    fill: Color(0xFF3949AB),
    accent: Color(0xFFC5CAE9),
    outline: Color(0xFF1A237E),
    displayName: 'Thrift Apparel',
  );

  static const tailoring = ZoneColorSet(
    fill: Color(0xFF26C6DA),
    accent: Color(0xFFB2EBF2),
    outline: Color(0xFF00838F),
    displayName: 'Tailoring & Dress Shop',
  );

  static const eateries = ZoneColorSet(
    fill: Color(0xFFFF8A65),
    accent: Color(0xFFFFCCBC),
    outline: Color(0xFFD84315),
    displayName: 'Eateries',
  );

  static const sariSari = ZoneColorSet(
    fill: Color(0xFF8BC34A),
    accent: Color(0xFFDCEDC8),
    outline: Color(0xFF33691E),
    displayName: 'Sari Sari',
  );

  static const wholesaleSnacks = ZoneColorSet(
    fill: Color(0xFF8E24AA),
    accent: Color(0xFFE1BEE7),
    outline: Color(0xFF4A148C),
    displayName: 'Wholesale Snacks',
  );

  static const ingredients = ZoneColorSet(
    fill: Color(0xFF9575CD),
    accent: Color(0xFFD1C4E9),
    outline: Color(0xFF4527A0),
    displayName: 'Ingredients',
  );

  static const coconutAndGata = ZoneColorSet(
    fill: Color(0xFFA1887F),
    accent: Color(0xFFD7CCC8),
    outline: Color(0xFF4E342E),
    displayName: 'Coconut & Gata',
  );

  static const specialtyRepair = ZoneColorSet(
    fill: Color(0xFF5C6BC0),
    accent: Color(0xFF9FA8DA),
    outline: Color(0xFF283593),
    displayName: 'Specialty Repair',
  );

  static const wellnessAndSpa = ZoneColorSet(
    fill: Color(0xFFF06292),
    accent: Color(0xFFF48FB1),
    outline: Color(0xFFAD1457),
    displayName: 'Wellness & Spa',
  );

  static const salonAndBeauty = ZoneColorSet(
    fill: Color(0xFFBA68C8),
    accent: Color(0xFFF3E5F5),
    outline: Color(0xFF7B1FA2),
    displayName: 'Salon & Beauty',
  );

  static const miscellaneous = ZoneColorSet(
    fill: Color(0xFF4DB6AC),
    accent: Color(0xFFB2DFDB),
    outline: Color(0xFF00695C),
    displayName: 'Miscellaneous',
  );

  // Unassigned / Empty Stalls
  static const unassigned = ZoneColorSet(
    fill: Color(0xFFE2E8F0),
    accent: Color(0xFFE2E8F0),
    outline: Color(0xFF94A3B8),
    displayName: 'Unassigned',
  );

  // Infrastructure Elements
  static const pathways = ZoneColorSet(
    fill: Color(0xFFE0E0E0),
    accent: Color(0xFFF5F5F5),
    outline: Color(0xFF9E9E9E),
    displayName: 'Pathways',
  );

  static const buildings = ZoneColorSet(
    fill: Color(0xFFB0BEC5),
    accent: Color(0xFFECEFF1),
    outline: Color(0xFF546E7A),
    displayName: 'Buildings',
  );

  static const footbridge = ZoneColorSet(
    fill: Color(0xFF78909C),
    accent: Color(0xFFB0BEC5),
    outline: Color(0xFF455A64),
    displayName: 'Footbridge / Ramp',
  );

  static const river = ZoneColorSet(
    fill: Color(0xFF4DD0E1),
    accent: Color(0xFFE0F7FA),
    outline: Color(0xFF00838F),
    displayName: 'Natural River',
  );

  /// Map of canonical category names to ZoneColorSet
  static const Map<String, ZoneColorSet> _categoryMap = {
    'produce': produce,
    'fruits & vegetables': produce,
    'fruits': produce,
    'vegetables': produce,
    'meat': meat,
    'pork & beef': meat,
    'pork': meat,
    'beef': meat,
    'poultry': meat,
    'mixed meat': mixedMeat,
    'dressed chicken': mixedMeat,
    'fish': fish,
    'seafood': fish,
    'dry goods': dryGoods,
    'rice & grains': riceAndGrains,
    'rice': riceAndGrains,
    'thrift apparel': thriftApparel,
    'ukay ukay': thriftApparel,
    'ukay-ukay': thriftApparel,
    'tailoring & dress shop': tailoring,
    'tailoring': tailoring,
    'dressmaking': tailoring,
    'eateries': eateries,
    'eatery': eateries,
    'carinderia': eateries,
    'carenderia': eateries,
    'bakery': eateries,
    'sari sari': sariSari,
    'sari-sari': sariSari,
    'wholesale snacks & repacked supplies': wholesaleSnacks,
    'wholesale snacks': wholesaleSnacks,
    'snacks': wholesaleSnacks,
    'ingredients': ingredients,
    'spices & oils': ingredients,
    'coconut & gata': coconutAndGata,
    'coconut': coconutAndGata,
    'specialty repair': specialtyRepair,
    'watch & jewelry repair': specialtyRepair,
    'wellness & spa': wellnessAndSpa,
    'spa': wellnessAndSpa,
    'salon & beauty': salonAndBeauty,
    'salon': salonAndBeauty,
    'miscellaneous': miscellaneous,
    'unassigned': unassigned,
  };

  /// Resolve color set for a given category name (case-insensitive)
  static ZoneColorSet getColorSet(String? categoryName) {
    if (categoryName == null || categoryName.trim().isEmpty) {
      return unassigned;
    }
    final normalized = categoryName.trim().toLowerCase();
    return _categoryMap[normalized] ?? miscellaneous;
  }

  /// Resolve primary base fill hex for SVG rendering
  static Color getFillColor(String? categoryName) {
    return getColorSet(categoryName).fill;
  }

  /// Resolve lighter accent color for highlights and selection
  static Color getAccentColor(String? categoryName) {
    return getColorSet(categoryName).accent;
  }

  /// Resolve darker outline stroke color
  static Color getOutlineColor(String? categoryName) {
    return getColorSet(categoryName).outline;
  }
}
