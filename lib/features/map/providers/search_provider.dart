import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/stall_model.dart';
import '../../../providers/stall_provider.dart';
import '../services/market_search_service.dart';

/// Singleton MarketSearchService provider
final marketSearchServiceProvider = Provider<MarketSearchService>((ref) {
  return MarketSearchService();
});

/// Future provider to initialize search directory assets
final marketSearchInitProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(marketSearchServiceProvider);
  if (!service.isInitialized) {
    await service.initialize();
  }
  return true;
});

/// Active search query string
final mapSearchQueryProvider = StateProvider<String>((ref) => '');

/// Active category filter
final selectedCategoryFilterProvider = StateProvider<String?>((ref) => null);

/// Computed search results combining query, category filter, and stalls
final searchResultsProvider = Provider<List<SearchResultItem>>((ref) {
  final service = ref.watch(marketSearchServiceProvider);
  final query = ref.watch(mapSearchQueryProvider);
  final categoryFilter = ref.watch(selectedCategoryFilterProvider);
  final allStallsAsync = ref.watch(allStallsProvider);

  final allStalls = allStallsAsync.value ?? <StallModel>[];

  if (!service.isInitialized) {
    // If not initialized, fallback to naive substring search
    if (query.trim().isEmpty) return const [];
    final clean = query.trim().toLowerCase();
    return allStalls
        .where((s) =>
            s.name.toLowerCase().contains(clean) ||
            s.category.toLowerCase().contains(clean) ||
            s.products.any((p) => p.toLowerCase().contains(clean)))
        .map((s) => SearchResultItem(
              stall: s,
              matchType: StallMatchType.partialName,
              score: 50.0,
            ))
        .toList();
  }

  return service.searchStalls(
    query: query,
    allStalls: allStalls,
    categoryFilter: categoryFilter,
  );
});
