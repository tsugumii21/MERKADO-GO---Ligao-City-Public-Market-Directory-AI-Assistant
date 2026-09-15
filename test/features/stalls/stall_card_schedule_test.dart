import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merkado_go/features/stalls/presentation/stall_list_screen.dart';
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

  final sampleStalls = [
    StallModel(
      stallId: 'id_cee_store',
      name: "2 CEE'S STORE",
      category: 'Rice & Grains',
      products: ['White Rice'],
      address: 'STALL #15 BUILDING II MARKET SITE, BAGUMBAYAN, LIGAO CITY',
      photoUrls: [],
      openTime: '3:46 AM',
      closeTime: '5:46 PM',
      daysOpen: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
      latitude: 13.24,
      longitude: 123.54,
      isActive: true,
      stallNumber: '15',
      section: 'Building II',
      updatedAt: DateTime(2026, 1, 1),
    ),
  ];

  testWidgets('Stall card operating schedule renders both hours and full days cleanly',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allStallsProvider.overrideWith((ref) => Stream.value(sampleStalls)),
          favoriteProvider.overrideWith((ref) => FakeFavoriteNotifier()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: StallListScreen(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify stall title is present
    expect(find.text("2 CEE'S STORE"), findsOneWidget);

    // Verify hours are rendered with schedule icon
    expect(find.text('3:46 AM – 5:46 PM'), findsOneWidget);
    expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);

    // Verify full days schedule is rendered with calendar event icon
    expect(find.text('Daily (Mon – Sun)'), findsOneWidget);
    expect(find.byIcon(Icons.event_available_rounded), findsOneWidget);
  });
}
