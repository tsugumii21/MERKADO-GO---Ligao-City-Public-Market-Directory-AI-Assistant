import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merkado_go/core/utils/stall_utils.dart';
import 'package:merkado_go/features/stalls/presentation/widgets/category_filter_chips_bar.dart';
import 'package:merkado_go/features/stalls/presentation/widgets/inline_filter_drawer.dart';
import 'package:merkado_go/features/stalls/presentation/widgets/stall_filter_sort_bar.dart';
import 'package:merkado_go/models/stall_model.dart';

void main() {
  group('StallUtils.matchesCategory Tests', () {
    final meatStall = StallModel(
      stallId: 'stall_1',
      stallNumber: 'M-01',
      name: 'Ligao Fresh Pork & Beef',
      category: 'Meat Section',
      products: ['Pork', 'Beef', 'Orig'],
      section: 'Meat Section',
      address: 'Meat Section, Ligao Public Market',
      photoUrls: const [],
      openTime: '06:00 AM',
      closeTime: '05:00 PM',
      daysOpen: ['Daily'],
      latitude: 13.24,
      longitude: 123.54,
      isActive: true,
      status: 'open',
      tags: ['meat', 'pork', 'beef'],
      updatedAt: DateTime.now(),
    );

    final ukayStall = StallModel(
      stallId: 'stall_2',
      stallNumber: 'U-05',
      name: 'Boutique Thrift Clothes',
      category: 'Dry Goods',
      products: ['T-shirts', 'Jeans', 'Ukay'],
      section: 'Dry Goods Section',
      address: 'Dry Goods Section, Ligao Public Market',
      photoUrls: const [],
      openTime: '08:00 AM',
      closeTime: '06:00 PM',
      daysOpen: ['Monday - Saturday'],
      latitude: 13.24,
      longitude: 123.54,
      isActive: true,
      status: 'open',
      tags: ['ukay', 'clothes'],
      updatedAt: DateTime.now(),
    );

    test('Returns true for category All', () {
      expect(StallUtils.matchesCategory(meatStall, 'All'), isTrue);
      expect(StallUtils.matchesCategory(ukayStall, 'All'), isTrue);
    });

    test('Matches category by primary name, display name, and shortName', () {
      expect(StallUtils.matchesCategory(meatStall, 'Meat'), isTrue);
      expect(StallUtils.matchesCategory(meatStall, 'Fresh Meat'), isTrue);
      expect(StallUtils.matchesCategory(meatStall, 'Vegetables'), isFalse);

      expect(StallUtils.matchesCategory(ukayStall, 'Dry Goods'), isTrue);
      expect(StallUtils.matchesCategory(ukayStall, 'Thrift / Dry Goods'), isTrue);
      expect(StallUtils.matchesCategory(ukayStall, 'Thrift'), isTrue);
    });

    test('Matches subcategory strictly when provided', () {
      expect(StallUtils.matchesCategory(meatStall, 'Meat', 'Pork'), isTrue);
      expect(StallUtils.matchesCategory(meatStall, 'Meat', 'Chicken'), isFalse);
    });
  });

  group('StallFilterSortBar Widget Tests', () {
    testWidgets('Renders count, title, and handles 1-tap toggles', (tester) async {
      String? currentSort;
      bool currentOpenOnly = false;
      bool isDrawerOpen = false;
      bool resetCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return StallFilterSortBar(
                  title: 'All Stalls',
                  count: 42,
                  sortAlpha: currentSort,
                  filterOpenOnly: currentOpenOnly,
                  isDrawerOpen: isDrawerOpen,
                  hasAdvancedFilters: false,
                  hasAnyActiveFilter: currentSort != null || currentOpenOnly,
                  onSortAlphaChanged: (val) => setState(() => currentSort = val),
                  onFilterOpenOnlyChanged: (val) =>
                      setState(() => currentOpenOnly = val),
                  onToggleDrawer: () =>
                      setState(() => isDrawerOpen = !isDrawerOpen),
                  onResetAll: () => resetCalled = true,
                );
              },
            ),
          ),
        ),
      );

      // Verify title and count
      expect(find.text('All Stalls (42)'), findsOneWidget);

      // 1-tap on Open pill
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(currentOpenOnly, isTrue);

      // 1-tap on Sort pill (Default -> A-Z)
      await tester.tap(find.text('Sort'));
      await tester.pumpAndSettle();
      expect(currentSort, equals('az'));
      expect(find.text('A–Z'), findsOneWidget);

      // 2nd tap on Sort pill (A-Z -> Z-A)
      await tester.tap(find.text('A–Z'));
      await tester.pumpAndSettle();
      expect(currentSort, equals('za'));
      expect(find.text('Z–A'), findsOneWidget);

      // 3rd tap on Sort pill (Z-A -> Default)
      await tester.tap(find.text('Z–A'));
      await tester.pumpAndSettle();
      expect(currentSort, isNull);

      // Tap on Filter drawer toggle icon
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();
      expect(isDrawerOpen, isTrue);

      // Reset button should now be visible since active filter is true (currentOpenOnly is true)
      expect(find.text('• Reset'), findsOneWidget);
      await tester.tap(find.text('• Reset'));
      await tester.pump();
      expect(resetCalled, isTrue);
    });
  });

  group('CategoryFilterChipsBar Widget Tests', () {
    testWidgets('Renders categories and fires onCategorySelected', (tester) async {
      String selectedCat = 'All';
      String? selectedSub;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return CategoryFilterChipsBar(
                  selectedCategory: selectedCat,
                  selectedSubcategory: selectedSub,
                  onCategorySelected: (cat) => setState(() {
                    selectedCat = cat;
                    selectedSub = null;
                  }),
                  onSubcategorySelected: (sub) =>
                      setState(() => selectedSub = sub),
                );
              },
            ),
          ),
        ),
      );

      // Find 'All' chip
      expect(find.text('All'), findsOneWidget);

      // Find 'Meat' chip and tap
      await tester.tap(find.text('Meat'));
      await tester.pumpAndSettle();
      expect(selectedCat, equals('Meat'));

      // Subcategory strip should now be visible for Meat
      expect(find.text('All Meat'), findsOneWidget);
    });
  });

  group('InlineFilterDrawer Widget Tests', () {
    testWidgets('Selects day and toggles open/closed day filter', (tester) async {
      String? day;
      bool showOpen = true;
      bool cleared = false;
      bool closed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return InlineFilterDrawer(
                  selectedDay: day,
                  showOpenOnDay: showOpen,
                  openTime: null,
                  closeTime: null,
                  onDaySelected: (d) => setState(() => day = d),
                  onShowOpenChanged: (val) => setState(() => showOpen = val),
                  onTimeRangeChanged: (_, __) {},
                  onClear: () => cleared = true,
                  onClose: () => closed = true,
                );
              },
            ),
          ),
        ),
      );

      // Tap on Monday short day pill
      await tester.tap(find.text('Mon'));
      await tester.pumpAndSettle();
      expect(day, equals('Monday'));

      // Tap on Closed Only toggle
      await tester.tap(find.text('Closed Only'));
      await tester.pumpAndSettle();
      expect(showOpen, isFalse);

      // Tap Clear
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(cleared, isTrue);

      // Tap Close button
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
    });
  });
}

