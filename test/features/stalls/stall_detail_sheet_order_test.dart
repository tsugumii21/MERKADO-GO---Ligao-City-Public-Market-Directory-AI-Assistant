import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merkado_go/core/utils/stall_utils.dart';
import 'package:merkado_go/features/map/services/market_search_service.dart';
import 'package:merkado_go/features/stalls/presentation/stall_detail_sheet.dart';
import 'package:merkado_go/models/stall_model.dart';
import 'package:merkado_go/providers/favorite_provider.dart';

class FakeFavoriteNotifier extends FavoriteNotifier {
  FakeFavoriteNotifier([FavoriteState state = const FavoriteState()]) {
    this.state = state;
  }

  @override
  Future<void> loadFavorites() async {}

  @override
  Future<void> toggleFavorite(String stallId) async {}

  @override
  void clearFavorites() {
    state = const FavoriteState();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleStall = StallModel(
    stallId: 'stall_apparel_99',
    name: 'Ligao Fashion Hub',
    category: 'Thrift Apparel',
    subcategories: ['Kids Wear', 'Men Wear'],
    products: ['Graphic T-Shirt', 'Denim Jeans'],
    tags: ['Graphic T-Shirt', 'Kids Wear'],
    address: 'Dry Goods Building, Row 3',
    photoUrls: [],
    openTime: '8:00 AM',
    closeTime: '6:00 PM',
    daysOpen: ['Daily'],
    latitude: 13.24,
    longitude: 123.54,
    isActive: true,
    stallNumber: 'DG-33',
    section: 'Dry Goods',
    updatedAt: DateTime(2026, 1, 1),
  );

  group('StallDetailSheet Subcategories & Products Order Tests', () {
    testWidgets('Subcategories header is above Products Available and renamed from Subcategories & Tags',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            favoriteProvider.overrideWith((ref) => FakeFavoriteNotifier()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: StallDetailSheet(
                stall: sampleStall,
                isAdmin: false,
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final subcatHeaderFinder = find.text('Subcategories');
      expect(subcatHeaderFinder, findsOneWidget);

      expect(find.text('Subcategories & Tags'), findsNothing);

      final productsHeaderFinder = find.text('Products Available');
      expect(productsHeaderFinder, findsOneWidget);

      final subcatTop = tester.getTopLeft(subcatHeaderFinder).dy;
      final productsTop = tester.getTopLeft(productsHeaderFinder).dy;
      expect(subcatTop, lessThan(productsTop));

      expect(find.text('Graphic T-Shirt'), findsOneWidget);
      expect(find.text('Kids Wear'), findsOneWidget);
    });
  });

  group('Product Separation and Search Tests', () {
    test('StallUtils.matchesCategory subcategory matching does not treat products as subcategories', () {
      final matchesProductAsSubcat = StallUtils.matchesCategory(
        sampleStall,
        'Thrift Apparel',
        'Denim Jeans',
      );
      expect(matchesProductAsSubcat, isFalse);

      final matchesValidSubcat = StallUtils.matchesCategory(
        sampleStall,
        'Thrift Apparel',
        'Kids Wear',
      );
      expect(matchesValidSubcat, isTrue);
    });

    test('MarketSearchService finds stall by product keyword e.g. shirt', () {
      final searchService = MarketSearchService();
      final results = searchService.searchStalls(
        query: 'shirt',
        allStalls: [sampleStall],
      );

      expect(results.isNotEmpty, isTrue);
      expect(results.first.stall.stallId, equals('stall_apparel_99'));
      expect(results.first.matchType, equals(StallMatchType.productMatch));
    });
  });
}
