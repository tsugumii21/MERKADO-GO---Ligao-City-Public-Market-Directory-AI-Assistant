import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merkado_go/features/admin/presentation/widgets/admin_stall_location_picker.dart';
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

  group('AdminStallLocationPicker Widget Tests', () {
    test('AdminStallLocationResult creates properly with all required fields', () {
      const result = AdminStallLocationResult(
        stallId: 'slot_wm_29',
        zoneCode: 'wm',
        sectionName: 'MEAT SECTION',
        suggestedStallNumber: 'STALL #29 WET MARKET',
        bounds: Rect.fromLTWH(4335.47, 3898, 73, 28),
        center: Offset(4371.97, 3912),
      );

      expect(result.stallId, equals('slot_wm_29'));
      expect(result.zoneCode, equals('wm'));
      expect(result.sectionName, equals('MEAT SECTION'));
      expect(result.suggestedStallNumber, equals('STALL #29 WET MARKET'));
      expect(result.bounds.width, equals(73));
      expect(result.bounds.height, equals(28));
      expect(result.center.dx, closeTo(4371.97, 0.01));
      expect(result.isCleared, isFalse);
    });

    test('AdminStallLocationResult.cleared creates an empty cleared result', () {
      const result = AdminStallLocationResult.cleared();

      expect(result.stallId, isEmpty);
      expect(result.zoneCode, isEmpty);
      expect(result.sectionName, isEmpty);
      expect(result.suggestedStallNumber, isEmpty);
      expect(result.bounds, equals(Rect.zero));
      expect(result.center, equals(Offset.zero));
      expect(result.isCleared, isTrue);
    });

    testWidgets('Renders picker header and legend', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allStallsProvider.overrideWith((ref) => Stream.value(testStalls)),
          ],
          child: const MaterialApp(
            home: AdminStallLocationPicker(
              stallCategory: 'Meat',
              stallName: 'Test Stall',
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify app bar title and instructions
      expect(find.text('Select Stall Location'), findsOneWidget);
      expect(
        find.text('Tap an empty light gray stall to assign location'),
        findsOneWidget,
      );

      // Verify legend
      expect(find.text('Empty Stall (Available)'), findsOneWidget);
      expect(find.text('Meat'), findsOneWidget);
    });

    testWidgets('Shows confirmation card when initialStallId is provided',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allStallsProvider.overrideWith((ref) => Stream.value(testStalls)),
          ],
          child: const MaterialApp(
            home: AdminStallLocationPicker(
              initialStallId: 'slot_wm_29',
              stallCategory: 'Meat',
              stallName: 'Test Stall',
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify confirmed slot card is displayed
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Vacant Slot'), findsOneWidget);
      expect(find.text('Wet Market (Slot WM-29)'), findsOneWidget);
      expect(find.text('Will display in Meat color'), findsOneWidget);
    });

    testWidgets('Calls onLocationSelected when Confirm is tapped',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      AdminStallLocationResult? selectedResult;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allStallsProvider.overrideWith((ref) => Stream.value(testStalls)),
          ],
          child: MaterialApp(
            home: AdminStallLocationPicker(
              initialStallId: 'slot_wm_29',
              stallCategory: 'Meat',
              stallName: 'Test Meatshop',
              onLocationSelected: (res) {
                selectedResult = res;
              },
            ),
          ),
        ),
      );

      await tester.pump();

      final confirmBtn = find.text('Confirm');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(selectedResult, isNotNull);
      expect(selectedResult!.stallId, equals('slot_wm_29'));
      expect(selectedResult!.zoneCode, equals('wm'));
      expect(selectedResult!.sectionName, equals('MEAT SECTION'));
      expect(selectedResult!.suggestedStallNumber, equals('STALL #29 WET MARKET'));
    });
  });
}
