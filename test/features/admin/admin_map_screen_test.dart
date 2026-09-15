import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merkado_go/features/admin/presentation/admin_map_screen.dart';
import 'package:merkado_go/features/map/presentation/widgets/interactive_market_map.dart';
import 'package:merkado_go/models/stall_model.dart';
import 'package:merkado_go/providers/stall_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testStalls = [
    StallModel(
      stallId: 'id_3',
      name: "4E'S LLOBET MEATSHOP",
      category: 'Meat',
      products: ['Pork'],
      address: 'STALL #1 MEAT SECTION',
      photoUrls: [],
      openTime: '5:00 AM',
      closeTime: '6:00 PM',
      daysOpen: ['Mon-Sun'],
      latitude: 13.24,
      longitude: 123.54,
      isActive: true,
      stallNumber: '1',
      section: 'MEAT SECTION',
      updatedAt: DateTime(2026, 1, 1),
    ),
  ];

  testWidgets('AdminMapScreen renders InteractiveMarketMap and search bar', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allStallsProvider.overrideWith((ref) => Stream.value(testStalls)),
        ],
        child: const MaterialApp(
          home: AdminMapScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(InteractiveMarketMap), findsOneWidget);
    expect(find.text('Search stalls, fish, meat...'), findsOneWidget);
  });

  testWidgets('AdminMapScreen dynamically updates InteractiveMarketMap when stall is deleted or removed', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final streamController = StreamController<List<StallModel>>();
    addTearDown(() => streamController.close());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allStallsProvider.overrideWith((ref) => streamController.stream),
        ],
        child: const MaterialApp(
          home: AdminMapScreen(),
        ),
      ),
    );

    // Initial emission with stall
    streamController.add(testStalls);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(InteractiveMarketMap), findsOneWidget);

    // Stall deleted -> stream emits empty list
    streamController.add([]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final mapWidget = tester.widget<InteractiveMarketMap>(find.byType(InteractiveMarketMap));
    expect(mapWidget.stalls.isEmpty, isTrue);
  });
}
