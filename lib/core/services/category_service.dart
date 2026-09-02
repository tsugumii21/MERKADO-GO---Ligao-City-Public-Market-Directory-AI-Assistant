import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/market_categories.dart';

/// Central Service for managing dynamic category and subcategory customization in Firestore
class CategoryService {
  CategoryService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'category_metadata';

  // In-memory cache for fast UI lookups and responsive offline-first experience
  static final Map<String, List<String>> _cachedSubcategories = {};

  /// Clear the local subcategories cache
  static void clearCache([String? categoryKey]) {
    if (categoryKey != null) {
      _cachedSubcategories.remove(categoryKey);
    } else {
      _cachedSubcategories.clear();
    }
  }

  /// Retrieve subcategories for a category key, checking Firestore first and falling back to default MarketCategories
  static Future<List<String>> getSubcategories(
    String categoryKey, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedSubcategories.containsKey(categoryKey)) {
      return List<String>.from(_cachedSubcategories[categoryKey]!);
    }

    try {
      final doc = await _firestore.collection(_collectionName).doc(categoryKey).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['customSubcategories'] is List) {
          final list = (data['customSubcategories'] as List)
              .map((e) => (e ?? '').toString().trim())
              .where((e) => e.isNotEmpty)
              .toList();
          _cachedSubcategories[categoryKey] = list;
          return List<String>.from(list);
        }
      }
    } catch (_) {
      // Fallback on network or initial empty state
    }

    // Default from static definition
    final defaultCat = MarketCategories.findCategory(categoryKey);
    final defaults = defaultCat != null ? List<String>.from(defaultCat.subcategories) : <String>[];
    _cachedSubcategories[categoryKey] = defaults;
    return List<String>.from(defaults);
  }

  /// Add a new subcategory to a category and persist to Firestore
  static Future<List<String>> addSubcategory(String categoryKey, String newSubcategory) async {
    final trimmed = newSubcategory.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Subcategory name cannot be empty');
    }

    final currentList = await getSubcategories(categoryKey);
    if (currentList.any((s) => s.toLowerCase() == trimmed.toLowerCase())) {
      throw Exception('Subcategory "$trimmed" already exists in this category');
    }

    currentList.add(trimmed);
    _cachedSubcategories[categoryKey] = currentList;

    final catItem = MarketCategories.findCategory(categoryKey);

    await _firestore.collection(_collectionName).doc(categoryKey).set({
      'categoryId': categoryKey,
      'primaryCategoryName': catItem?.primaryCategoryName ?? categoryKey,
      'customSubcategories': currentList,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return List<String>.from(currentList);
  }

  /// Rename/edit an existing subcategory and persist changes in Firestore
  static Future<List<String>> editSubcategory({
    required String categoryKey,
    required String oldName,
    required String newName,
  }) async {
    final trimmedNew = newName.trim();
    if (trimmedNew.isEmpty) {
      throw ArgumentError('Subcategory name cannot be empty');
    }

    final currentList = await getSubcategories(categoryKey);
    final index = currentList.indexWhere((s) => s.toLowerCase() == oldName.trim().toLowerCase());
    if (index == -1) {
      throw Exception('Subcategory "$oldName" not found');
    }

    if (oldName.trim().toLowerCase() != trimmedNew.toLowerCase() &&
        currentList.any((s) => s.toLowerCase() == trimmedNew.toLowerCase())) {
      throw Exception('A subcategory named "$trimmedNew" already exists');
    }

    currentList[index] = trimmedNew;
    _cachedSubcategories[categoryKey] = currentList;

    final catItem = MarketCategories.findCategory(categoryKey);

    await _firestore.collection(_collectionName).doc(categoryKey).set({
      'categoryId': categoryKey,
      'primaryCategoryName': catItem?.primaryCategoryName ?? categoryKey,
      'customSubcategories': currentList,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return List<String>.from(currentList);
  }

  /// Delete a subcategory from a category and persist in Firestore
  static Future<List<String>> deleteSubcategory(String categoryKey, String subcategoryToDelete) async {
    final trimmed = subcategoryToDelete.trim();
    final currentList = await getSubcategories(categoryKey);
    currentList.removeWhere((s) => s.toLowerCase() == trimmed.toLowerCase());
    _cachedSubcategories[categoryKey] = currentList;

    final catItem = MarketCategories.findCategory(categoryKey);

    await _firestore.collection(_collectionName).doc(categoryKey).set({
      'categoryId': categoryKey,
      'primaryCategoryName': catItem?.primaryCategoryName ?? categoryKey,
      'customSubcategories': currentList,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return List<String>.from(currentList);
  }
}
