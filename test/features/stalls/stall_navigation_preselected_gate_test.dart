import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merkado_go/features/map/domain/navigation_models.dart';
import 'package:merkado_go/features/map/providers/navigation_provider.dart';
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

  final testStall = StallModel(
    stallId: 'stall_101',
    name: 'Aling Maria Fish Stall',
    category: 'Fish',
    subcategories: ['Fresh Fish'],
    products: ['Tilapia', 'Bangus'],
    tags: ['Fresh Fish'],
    address: 'Wet Market, Row 1',
    photoUrls: [],
    openTime: '6:00 AM',
    closeTime: '2:00 PM',
    daysOpen: ['Daily'],
    latitude: 13.24,
    longitude: 123.54,
    isActive: true,
    stallNumber: 'WM-01',
    section: 'Wet Market',
    updatedAt: DateTime(2026, 1, 1),
  );

  const testGate1 = MarketEntryPoint(
    entranceId: 1,
    nodeId: 'node_entry_1',
    description: 'South Plaza Entrance',
    title: 'Gate 1',
  );

  const testGateChurch = MarketEntryPoint(
    entranceId: 4,
    nodeId: 'node_entry_4',
    description: 'Direct From Church',
    title: 'Church Entrance',
  );

  group('StallDetailSheet Pre-selected Entrance Routing Tests', () {
    testWidgets('Displays Navigate to Stall without subtitle when no gate is pre-selected', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            favoriteProvider.overrideWith((ref) => FakeFavoriteNotifier()),
            selectedEntranceProvider.overrideWith((ref) => null),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: StallDetailSheet(
                stall: testStall,
                isAdmin: false,
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Navigate to Stall'), findsOneWidget);
      expect(find.textContaining('From Gate'), findsNothing);
    });

    testWidgets('Displays primaryActionSubtitle From Gate 1 when Gate 1 is pre-selected', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            favoriteProvider.overrideWith((ref) => FakeFavoriteNotifier()),
            selectedEntranceProvider.overrideWith((ref) => testGate1),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: StallDetailSheet(
                stall: testStall,
                isAdmin: false,
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Navigate to Stall'), findsOneWidget);
      expect(find.text('From Gate 1'), findsOneWidget);
    });

    testWidgets('Displays custom entrance title in subtitle when pre-selected', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            favoriteProvider.overrideWith((ref) => FakeFavoriteNotifier()),
            selectedEntranceProvider.overrideWith((ref) => testGateChurch),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: StallDetailSheet(
                stall: testStall,
                isAdmin: false,
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Navigate to Stall'), findsOneWidget);
      expect(find.text('From Church Entrance'), findsOneWidget);
    });
  });
}
