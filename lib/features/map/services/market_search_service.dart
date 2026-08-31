import 'dart:convert';
import 'package:flutter/services.dart';
import '../../../../models/stall_model.dart';

enum StallMatchType {
  exactName,
  partialName,
  productMatch,
  trilingualKeyword,
  categoryMatch,
}

class SearchResultItem {
  final StallModel stall;
  final StallMatchType matchType;
  final String? matchedKeyword;
  final double score;

  const SearchResultItem({
    required this.stall,
    required this.matchType,
    this.matchedKeyword,
    required this.score,
  });
}

/// Category metadata definition from subcategory directory
class CategoryMetadata {
  final String key;
  final String displayName;
  final String shortName;
  final List<String> subcategories;
  final List<String> keywords;

  const CategoryMetadata({
    required this.key,
    required this.displayName,
    required this.shortName,
    required this.subcategories,
    required this.keywords,
  });

  factory CategoryMetadata.fromJson(String key, Map<String, dynamic> json) {
    return CategoryMetadata(
      key: key,
      displayName: json['display_name'] as String? ?? key,
      shortName: json['short_name'] as String? ?? key,
      subcategories: (json['subcategories'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      keywords: (json['keywords'] as List? ?? [])
          .map((e) => e.toString().toLowerCase().trim())
          .toList(),
    );
  }
}

/// Trilingual Smart Search Engine (English, Tagalog, Central Bicolano)
class MarketSearchService {
  final Map<String, CategoryMetadata> _categories = {};
  final Map<String, Set<String>> _keywordToCategoryKeys = {};
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  List<CategoryMetadata> get categories => _categories.values.toList();

  /// Load trilingual search directory from bundled assets
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final jsonStr = await rootBundle
          .loadString('assets/map/subcategory_search_directory.json');
      final jsonData = jsonDecode(jsonStr) as Map<String, dynamic>;
      initializeWithRawData(jsonData);
    } catch (e) {
      throw Exception('Failed to initialize MarketSearchService: $e');
    }
  }

  /// Initialize with raw in-memory JSON data
  void initializeWithRawData(Map<dynamic, dynamic> jsonData) {
    _categories.clear();
    _keywordToCategoryKeys.clear();

    final cats = (jsonData['categories'] as Map?) ?? {};

    for (final entry in cats.entries) {
      final key = entry.key.toString();
      final rawVal = entry.value;
      final valMap = rawVal is Map
          ? rawVal.map((k, v) => MapEntry(k.toString(), v))
          : <String, dynamic>{};

      final meta = CategoryMetadata.fromJson(key, valMap);
      _categories[key] = meta;

      // Index all trilingual keywords
      for (final kw in meta.keywords) {
        final normalized = _normalize(kw);
        if (normalized.isEmpty) continue;
        _keywordToCategoryKeys.putIfAbsent(normalized, () => {}).add(key);
      }

      // Also index subcategories as keywords
      for (final sub in meta.subcategories) {
        final normalized = _normalize(sub);
        if (normalized.isEmpty) continue;
        _keywordToCategoryKeys.putIfAbsent(normalized, () => {}).add(key);
      }

      // Index short name and display name
      _keywordToCategoryKeys
          .putIfAbsent(_normalize(meta.shortName), () => {})
          .add(key);
      _keywordToCategoryKeys
          .putIfAbsent(_normalize(meta.displayName), () => {})
          .add(key);
      _keywordToCategoryKeys
          .putIfAbsent(_normalize(key), () => {})
          .add(key);
    }

    _isInitialized = true;
  }

  /// Search stalls across name, products, and trilingual keyword directory
  List<SearchResultItem> searchStalls({
    required String query,
    required List<StallModel> allStalls,
    String? categoryFilter,
  }) {
    final cleanQuery = _normalize(query);
    final results = <SearchResultItem>[];

    // Filter stalls by category first if specified
    final candidateStalls = categoryFilter != null && categoryFilter.isNotEmpty
        ? allStalls
            .where((s) =>
                s.category.toLowerCase() == categoryFilter.toLowerCase())
            .toList()
        : allStalls;

    if (cleanQuery.isEmpty) {
      // If query is empty but filter is present, return all in category
      return candidateStalls.map((s) {
        return SearchResultItem(
          stall: s,
          matchType: StallMatchType.categoryMatch,
          score: 10.0,
        );
      }).toList();
    }

    // Identify matching category keys from trilingual index
    final matchingCategoryKeys = _findMatchingCategories(cleanQuery);

    for (final stall in candidateStalls) {
      final nameNorm = _normalize(stall.name);
      final stallNumNorm = _normalize(stall.stallNumber);
      final stallIdNorm = _normalize(stall.stallId);
      final catNorm = _normalize(stall.category);

      // 1. Check exact / prefix stall name match
      if (nameNorm == cleanQuery ||
          stallNumNorm == cleanQuery ||
          stallIdNorm == cleanQuery) {
        results.add(SearchResultItem(
          stall: stall,
          matchType: StallMatchType.exactName,
          score: 100.0,
        ));
        continue;
      }

      if (nameNorm.contains(cleanQuery) || stallNumNorm.contains(cleanQuery)) {
        results.add(SearchResultItem(
          stall: stall,
          matchType: StallMatchType.partialName,
          score: 85.0,
        ));
        continue;
      }

      // 2. Check product list matches
      String? matchedProduct;
      for (final prod in stall.products) {
        final prodNorm = _normalize(prod);
        if (prodNorm.contains(cleanQuery) || cleanQuery.contains(prodNorm)) {
          matchedProduct = prod;
          break;
        }
      }

      if (matchedProduct != null) {
        results.add(SearchResultItem(
          stall: stall,
          matchType: StallMatchType.productMatch,
          matchedKeyword: matchedProduct,
          score: 75.0,
        ));
        continue;
      }

      // 3. Check trilingual keyword match
      if (_matchesCategory(stall.category, matchingCategoryKeys)) {
        results.add(SearchResultItem(
          stall: stall,
          matchType: StallMatchType.trilingualKeyword,
          matchedKeyword: query,
          score: 60.0,
        ));
        continue;
      }

      // 4. Check category direct match
      if (catNorm.contains(cleanQuery)) {
        results.add(SearchResultItem(
          stall: stall,
          matchType: StallMatchType.categoryMatch,
          score: 45.0,
        ));
      }
    }

    // Sort by descending relevance score
    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  bool _matchesCategory(String stallCategory, Set<String> matchedCategoryKeys) {
    if (matchedCategoryKeys.isEmpty) return false;
    final catNorm = _normalize(stallCategory);

    for (final key in matchedCategoryKeys) {
      final normKey = _normalize(key);
      if (catNorm.contains(normKey) || normKey.contains(catNorm)) return true;

      final meta = _categories[key];
      if (meta != null) {
        final shortNorm = _normalize(meta.shortName);
        final dispNorm = _normalize(meta.displayName);

        if (catNorm.contains(shortNorm) ||
            shortNorm.contains(catNorm) ||
            catNorm.contains(dispNorm) ||
            dispNorm.contains(catNorm)) {
          return true;
        }

        // Subcategory check
        for (final sub in meta.subcategories) {
          final subNorm = _normalize(sub);
          if (catNorm.contains(subNorm) || subNorm.contains(catNorm)) {
            return true;
          }
        }
      }
    }

    return false;
  }

  /// Resolve query words against the trilingual keyword index
  Set<String> _findMatchingCategories(String query) {
    final matched = <String>{};

    // Direct lookup
    if (_keywordToCategoryKeys.containsKey(query)) {
      matched.addAll(_keywordToCategoryKeys[query]!);
    }

    // Substring / tokenized lookup for multi-word queries
    final words = query.split(RegExp(r'\s+'));
    for (final word in words) {
      if (word.length < 2) continue;
      for (final entry in _keywordToCategoryKeys.entries) {
        if (entry.key == word || entry.key.contains(word) || word.contains(entry.key)) {
          matched.addAll(entry.value);
        }
      }
    }

    return matched;
  }

  String _normalize(String? input) {
    if (input == null) return '';
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .trim();
  }
}
