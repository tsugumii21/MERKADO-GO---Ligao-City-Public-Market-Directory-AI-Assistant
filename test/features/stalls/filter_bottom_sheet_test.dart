import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merkado_go/features/stalls/presentation/stall_list_screen.dart';

void main() {
  group('FilterBottomSheet Widget & Sizing Tests', () {
    testWidgets('renders within 60% screen height constraint on standard device', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.7;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterBottomSheet(
              currentSortAlpha: null,
              currentFilterOpenTime: null,
              currentFilterCloseTime: null,
              currentSelectedDay: null,
              currentShowOpenOnDay: true,
              currentFilterOpenOnly: false,
              onApply: (_, __, ___, ____, _____, ______) {},
              onReset: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rootContainerFinder = find.descendant(
        of: find.byType(FilterBottomSheet),
        matching: find.byType(Container),
      ).first;

      final Container rootContainer = tester.widget(rootContainerFinder);
      final maxHeight = rootContainer.constraints!.maxHeight;

      final expectedMax = (2400 / 2.7) * 0.60;
      expect(maxHeight, lessThanOrEqualTo(expectedMax + 0.1));
      expect(maxHeight, lessThanOrEqualTo(560.0));

      expect(find.text('Sort & Filter'), findsOneWidget);
      expect(find.text('Reset All'), findsOneWidget);
      expect(find.text('01  Alphabetical'), findsOneWidget);
      expect(find.text('02  Time Range'), findsOneWidget);
      expect(find.text('03  Quick Filter'), findsOneWidget);
      expect(find.text('04  Day & Status'), findsOneWidget);
      expect(find.text('Apply Filters'), findsOneWidget);
    });

    testWidgets('caps at 560px on large/tablet displays', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterBottomSheet(
              currentSortAlpha: null,
              currentFilterOpenTime: null,
              currentFilterCloseTime: null,
              currentSelectedDay: null,
              currentShowOpenOnDay: true,
              currentFilterOpenOnly: false,
              onApply: (_, __, ___, ____, _____, ______) {},
              onReset: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rootContainerFinder = find.descendant(
        of: find.byType(FilterBottomSheet),
        matching: find.byType(Container),
      ).first;

      final Container rootContainer = tester.widget(rootContainerFinder);
      expect(rootContainer.constraints!.maxHeight, equals(560.0));
    });

    testWidgets('calls onApply with correct values when Apply Filters is tapped', (tester) async {
      bool applied = false;
      String? appliedSort;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterBottomSheet(
              currentSortAlpha: null,
              currentFilterOpenTime: null,
              currentFilterCloseTime: null,
              currentSelectedDay: null,
              currentShowOpenOnDay: true,
              currentFilterOpenOnly: false,
              onApply: (sort, open, close, day, showOpen, openOnly) {
                applied = true;
                appliedSort = sort;
              },
              onReset: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('A to Z'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Apply Filters (1)'));
      await tester.pumpAndSettle();

      expect(applied, isTrue);
      expect(appliedSort, equals('az'));
    });
  });
}
