import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merkado_go/features/chat/domain/chat_directory_action.dart';
import 'package:merkado_go/features/chat/presentation/widgets/chat_directory_card.dart';
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

  final List<StallModel> sampleStalls = [
    StallModel(
      stallId: 'stall_fish_1',
      name: 'Marilyn Mecayer Martin Fish Vendor',
      category: 'Fish',
      stallNumber: '44',
      section: 'Fish Section',
      products: ['Bangus', 'Tilapia'],
      address: 'Wet Market',
      photoUrls: [],
      daysOpen: ['Daily'],
      openTime: '5:00 AM',
      closeTime: '6:00 PM',
      latitude: 13.24,
      longitude: 123.54,
      isActive: true,
      status: 'open',
      updatedAt: DateTime.now(),
    ),
    StallModel(
      stallId: 'stall_meat_1',
      name: 'Bong Meat Stand',
      category: 'Meat',
      stallNumber: '12',
      section: 'Meat Section',
      products: ['Pork', 'Beef'],
      address: 'Meat Section',
      photoUrls: [],
      daysOpen: ['Daily'],
      openTime: '5:00 AM',
      closeTime: '6:00 PM',
      latitude: 13.24,
      longitude: 123.54,
      isActive: true,
      status: 'open',
      updatedAt: DateTime.now(),
    ),
  ];

  group('Chat Directory Redirection Integration Tests', () {
    testWidgets(
        'Tapping View in Stall Directory sets selectedDirectoryCategoryProvider to Fish on 1st tap',
        (tester) async {
      const action = ChatDirectoryAction(
        category: 'Fish',
        totalCount: 8,
      );

      final container = ProviderContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: ChatDirectoryCard(
                action: action,
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      expect(container.read(selectedDirectoryCategoryProvider), equals('All'));

      await tester.tap(find.text('View in Stall Directory'));
      await tester.pump();

      expect(container.read(selectedDirectoryCategoryProvider), equals('Fish'));
    });

    testWidgets(
        'StallListScreen initializes directly with Fish category and filters stalls',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          allStallsProvider.overrideWith((ref) => Stream.value(sampleStalls)),
          selectedDirectoryCategoryProvider.overrideWith((ref) => 'Fish'),
          favoriteProvider.overrideWith((ref) => FakeFavoriteNotifier()),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: StallListScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Marilyn Mecayer Martin Fish Vendor'), findsOneWidget);
      expect(find.text('Bong Meat Stand'), findsNothing);
    });
  });
}
