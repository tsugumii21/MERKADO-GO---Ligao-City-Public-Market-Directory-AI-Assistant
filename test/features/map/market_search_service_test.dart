import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:merkado_go/features/map/services/market_search_service.dart';
import 'package:merkado_go/models/stall_model.dart';

StallModel createTestStall({
  required String stallId,
  required String name,
  required String category,
  String? stallNumber,
  String? section,
  List<String> products = const [],
}) {
  return StallModel(
    stallId: stallId,
    name: name,
    category: category,
    stallNumber: stallNumber,
    section: section,
    products: products,
    address: 'Ligao Public Market',
    photoUrls: const [],
    openTime: '06:00 AM',
    closeTime: '06:00 PM',
    daysOpen: const ['Monday', 'Tuesday', 'Wednesday'],
    latitude: 13.24,
    longitude: 123.54,
    isActive: true,
    updatedAt: DateTime.now(),
  );
}

void main() {
  group('MarketSearchService Unit Tests', () {
    late MarketSearchService service;
    late List<StallModel> sampleStalls;

    setUp(() {
      service = MarketSearchService();

      sampleStalls = [
        createTestStall(
          stallId: 'id_1',
          name: "2 CEE'S STORE",
          category: 'Dry Goods',
          stallNumber: 'DG-01',
          section: 'Dry Market',
          products: ['Biscuits', 'Canned Goods', 'Soap'],
        ),
        createTestStall(
          stallId: 'id_10',
          name: 'ALPARO FISH SECTION',
          category: 'Fish',
          stallNumber: 'F-10',
          section: 'Wet Market',
          products: ['Bangus', 'Tilapia', 'Galunggong'],
        ),
        createTestStall(
          stallId: 'id_20',
          name: 'LIGAO MEAT MASTER',
          category: 'Meat',
          stallNumber: 'M-20',
          section: 'Wet Market',
          products: ['Pork Chop', 'Liempo', 'Beef Shank'],
        ),
        createTestStall(
          stallId: 'id_30',
          name: 'NANAY ROSA PRODUCE',
          category: 'Produce',
          stallNumber: 'P-30',
          section: 'Fruits Section',
          products: ['Kamatis', 'Talong', 'Pechay', 'Siling Labuyo'],
        ),
        createTestStall(
          stallId: 'id_40',
          name: 'BICOL RICE & GRAINS',
          category: 'Rice & Grains',
          stallNumber: 'R-40',
          section: 'Rice Section',
          products: ['Sinandomeng', 'Dinorado', 'Jasponica'],
        ),
      ];
    });

    test('Indexes trilingual keywords from raw JSON data', () {
      final sampleJson = {
        'categories': {
          'fish': {
            'display_name': 'Fish & Seafood',
            'short_name': 'Fish',
            'subcategories': ['Freshwater Fish', 'Seafood'],
            'keywords': ['sira', 'bangus', 'tilapia', 'isda', 'salmon'],
          },
          'meat': {
            'display_name': 'Meat & Poultry',
            'short_name': 'Meat',
            'subcategories': ['Pork', 'Beef'],
            'keywords': ['orig', 'baboy', 'karneng urig', 'pork', 'baka'],
          },
        }
      };

      service.initializeWithRawData(sampleJson);
      expect(service.isInitialized, true);
      expect(service.categories.length, 2);

      // Central Bicolano match: "sira" -> Fish
      final fishResults = service.searchStalls(
        query: 'sira',
        allStalls: sampleStalls,
      );
      expect(fishResults.isNotEmpty, true);
      expect(fishResults.first.stall.stallId, 'id_10');
      expect(fishResults.first.matchType, StallMatchType.trilingualKeyword);

      // Central Bicolano match: "orig" -> Meat
      final meatResults = service.searchStalls(
        query: 'orig',
        allStalls: sampleStalls,
      );
      expect(meatResults.isNotEmpty, true);
      expect(meatResults.first.stall.stallId, 'id_20');
    });

    test('Matches exact and partial stall names', () {
      final sampleJson = {'categories': {}};
      service.initializeWithRawData(sampleJson);

      final exact = service.searchStalls(
        query: "2 CEE'S STORE",
        allStalls: sampleStalls,
      );
      expect(exact.first.matchType, StallMatchType.exactName);
      expect(exact.first.score, 100.0);

      final partial = service.searchStalls(
        query: 'Alparo',
        allStalls: sampleStalls,
      );
      expect(partial.first.stall.stallId, 'id_10');
      expect(partial.first.matchType, StallMatchType.partialName);
    });

    test('Matches direct products in stall inventory', () {
      final sampleJson = {'categories': {}};
      service.initializeWithRawData(sampleJson);

      final results = service.searchStalls(
        query: 'Liempo',
        allStalls: sampleStalls,
      );
      expect(results.isNotEmpty, true);
      expect(results.first.stall.stallId, 'id_20');
      expect(results.first.matchType, StallMatchType.productMatch);
      expect(results.first.matchedKeyword, 'Liempo');
    });

    test('Respects category filter parameter', () {
      final sampleJson = {'categories': {}};
      service.initializeWithRawData(sampleJson);

      final filtered = service.searchStalls(
        query: '',
        allStalls: sampleStalls,
        categoryFilter: 'Produce',
      );
      expect(filtered.length, 1);
      expect(filtered.first.stall.stallId, 'id_30');
    });
  });

  group('Real Subcategory Search Directory Asset Tests', () {
    late MarketSearchService service;

    setUp(() {
      service = MarketSearchService();
      final file = File('assets/map/subcategory_search_directory.json');
      final jsonData = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      service.initializeWithRawData(jsonData);
    });

    test('Loads 17 categories from real bundled asset', () {
      expect(service.categories.length, 17);
    });

    test('Resolves Central Bicolano, Tagalog, and English terms against real directory', () {
      final stalls = [
        createTestStall(
          stallId: 'id_101',
          name: 'Fresh Fish Center',
          category: 'Fish',
        ),
        createTestStall(
          stallId: 'id_102',
          name: 'Ligao Pork & Beef',
          category: 'Meat',
        ),
        createTestStall(
          stallId: 'id_103',
          name: 'Bicol Grains Supply',
          category: 'Rice & Grains',
        ),
      ];

      // Central Bicolano "sira" -> matches Fish
      final bicolFish = service.searchStalls(query: 'sira', allStalls: stalls);
      expect(bicolFish.any((r) => r.stall.category == 'Fish'), true);

      // Central Bicolano "orig" -> matches Meat
      final bicolMeat = service.searchStalls(query: 'orig', allStalls: stalls);
      expect(bicolMeat.any((r) => r.stall.category == 'Meat'), true);

      // Central Bicolano "bagas" -> matches Rice & Grains
      final bicolRice = service.searchStalls(query: 'bagas', allStalls: stalls);
      expect(bicolRice.any((r) => r.stall.category == 'Rice & Grains'), true);
    });
  });
}
