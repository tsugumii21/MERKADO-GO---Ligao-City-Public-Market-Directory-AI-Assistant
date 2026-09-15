import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merkado_go/features/map/presentation/widgets/map_search_dropdown.dart';
import 'package:merkado_go/features/stalls/presentation/stall_detail_sheet.dart';
import 'package:merkado_go/models/stall_model.dart';
import 'package:merkado_go/providers/favorite_provider.dart';
import 'package:merkado_go/providers/stall_provider.dart';

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
    stallId: 'id_101',
    name: 'Aling Maria Veggies',
    category: 'Produce',
    products: ['Kangkong', 'Talong'],
    address: 'Wet Market Site',
    photoUrls: [],
    openTime: '5:00 AM',
    closeTime: '6:00 PM',
    daysOpen: ['Daily'],
    latitude: 13.24,
    longitude: 123.54,
    isActive: true,
    stallNumber: '18',
    section: 'Wet Market',
    updatedAt: DateTime(2026, 1, 1),
  );

  group('StallDetailSheet Admin vs User Mode Tests', () {
    testWidgets('Renders "Edit Stall" button and hides report button when isAdmin is true',
        (tester) async {
      bool editTapped = false;
      tester.view.physicalSize = const Size(800, 1200);
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
                stall: testStall,
                isAdmin: true,
                onClose: () {},
                onEdit: () {
                  editTapped = true;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify "Edit Stall" button is rendered
      expect(find.text('Edit Stall'), findsOneWidget);
      expect(find.byIcon(Icons.edit_rounded), findsOneWidget);

      // Verify "Navigate to Stall" button is NOT rendered
      expect(find.text('Navigate to Stall'), findsNothing);

      // Verify customer report link is NOT rendered
      expect(find.text('Report an issue with this stall'), findsNothing);

      // Tap "Edit Stall" and verify callback fires
      await tester.ensureVisible(find.text('Edit Stall'));
      await tester.tap(find.text('Edit Stall'));
      await tester.pumpAndSettle();
      expect(editTapped, isTrue);
    });

    testWidgets('Renders "Navigate to Stall" button and report button when isAdmin is false',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
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
                stall: testStall,
                isAdmin: false,
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify "Navigate to Stall" button is rendered
      expect(find.text('Navigate to Stall'), findsOneWidget);

      // Verify "Edit Stall" button is NOT rendered
      expect(find.text('Edit Stall'), findsNothing);

      // Verify customer report link IS rendered
      expect(find.text('Report an issue with this stall'), findsOneWidget);
    });
  });

  group('MapSearchDropdown showEntrance Toggle Tests', () {
    testWidgets('Hides entrance button when showEntrance is false', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allStallsProvider.overrideWith((ref) => Stream.value([testStall])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: MapSearchDropdown(
                showEntrance: false,
                onStallSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Entrance text or Gate indicator should not be visible
      expect(find.text('Entrance'), findsNothing);
      expect(find.byIcon(Icons.location_on_rounded), findsNothing);
    });

    testWidgets('Shows entrance button when showEntrance is true', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allStallsProvider.overrideWith((ref) => Stream.value([testStall])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: MapSearchDropdown(
                showEntrance: true,
                onStallSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Entrance button should be visible
      expect(find.text('Entrance'), findsOneWidget);
      expect(find.byIcon(Icons.location_on_rounded), findsOneWidget);
    });
  });
}
