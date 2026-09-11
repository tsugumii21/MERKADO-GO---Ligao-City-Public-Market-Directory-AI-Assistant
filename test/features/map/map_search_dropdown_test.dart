import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merkado_go/features/map/presentation/widgets/map_search_dropdown.dart';
import 'package:merkado_go/models/stall_model.dart';
import 'package:merkado_go/providers/stall_provider.dart';

void main() {
  final sampleStalls = [
    StallModel(
      stallId: 'id_1',
      name: 'Caleb Gates',
      category: 'Meat',
      products: ['Pork', 'Beef'],
      address: 'Meat Section, Building 2',
      photoUrls: [],
      openTime: '6:00 AM',
      closeTime: '6:00 PM',
      daysOpen: ['Monday', 'Tuesday'],
      latitude: 13.24,
      longitude: 123.54,
      isActive: true,
      stallNumber: '12',
      section: 'Meat Section',
      updatedAt: DateTime(2026, 1, 1),
    ),
    StallModel(
      stallId: 'id_2',
      name: 'Penelope Cabrera',
      category: 'Fish',
      products: ['Tilapia', 'Bangus'],
      address: 'Fish Section, Building 1',
      photoUrls: [],
      openTime: '5:00 AM',
      closeTime: '5:00 PM',
      daysOpen: ['Daily'],
      latitude: 13.24,
      longitude: 123.54,
      isActive: true,
      stallNumber: '05',
      section: 'Fish Section',
      updatedAt: DateTime(2026, 1, 1),
    ),
  ];

  Widget buildTestWidget({
    required Function(StallModel) onStallSelected,
    VoidCallback? onEntranceTap,
    bool isOpen = false,
  }) {
    return ProviderScope(
      overrides: [
        allStallsProvider.overrideWith((ref) => Stream.value(sampleStalls)),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: MapSearchDropdown(
              onStallSelected: onStallSelected,
              onEntranceTap: onEntranceTap,
              isOpen: isOpen,
            ),
          ),
        ),
      ),
    );
  }

  group('MapSearchDropdown Widget Tests', () {
    testWidgets('Renders search input bar with search icon and hint text',
        (tester) async {
      await tester.pumpWidget(
        buildTestWidget(onStallSelected: (_) {}),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      expect(find.text('Search stalls, fish, meat...'), findsOneWidget);
      expect(find.text('Entrance'), findsOneWidget);
    });

    testWidgets('Tapping input bar opens dropdown and renders stall initials',
        (tester) async {
      StallModel? selectedStall;
      await tester.pumpWidget(
        buildTestWidget(
          onStallSelected: (stall) => selectedStall = stall,
        ),
      );
      await tester.pumpAndSettle();

      // Tap search text field to open dropdown
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // Verify dropdown appears with items
      expect(find.text('Caleb Gates'), findsOneWidget);
      expect(find.text('CG'), findsOneWidget);
      expect(find.text('Penelope Cabrera'), findsOneWidget);
      expect(find.text('PC'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsNWidgets(2));

      // Tap a stall item
      await tester.tap(find.text('Caleb Gates'));
      await tester.pumpAndSettle();

      expect(selectedStall?.name, equals('Caleb Gates'));
    });

    testWidgets('Shows "Oops.. No Results Found" for non-matching query',
        (tester) async {
      await tester.pumpWidget(
        buildTestWidget(onStallSelected: (_) {}),
      );
      await tester.pumpAndSettle();

      // Type non-existent query
      await tester.enterText(find.byType(TextField), 'Txa999');
      await tester.pumpAndSettle();

      // Verify empty state matching reference screenshot
      expect(find.text('Oops.. No Results Found'), findsOneWidget);
      expect(
        find.text(
          "Don't worry, it happens sometimes.\nPerhaps you could try entering a different search term",
        ),
        findsOneWidget,
      );
    });

    testWidgets('Clearing search input resets query', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(onStallSelected: (_) {}),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Caleb');
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Caleb'), findsNothing);
    });
  });
}
