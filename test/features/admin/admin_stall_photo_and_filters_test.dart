import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merkado_go/models/stall_model.dart';
import 'package:merkado_go/features/admin/presentation/add_edit_stall_screen.dart';
import 'package:merkado_go/features/admin/presentation/manage_stalls_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AddEditStallScreen Photo and Dialog Tests', () {
    testWidgets('Step 4 shows Stall Photo placeholder when no photo exists', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AddEditStallScreen(stallId: null),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step 0 -> Fill required
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'Photo Test Stall');
      await tester.enterText(textFields.at(1), 'Building I, Stall 1');
      await tester.pump();

      // Next -> Step 1
      await tester.tap(find.text('Next: Category & Location'));
      await tester.pumpAndSettle();

      // Select Meat category and subcategory
      await tester.tap(find.text('Meat (Pork & Beef)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pork Cuts'));
      await tester.pumpAndSettle();

      // Next -> Step 2
      await tester.tap(find.text('Next: Schedule & Products'));
      await tester.pumpAndSettle();

      // Next -> Step 3 (Step 4 of 4)
      await tester.tap(find.text('Next: Photo & Status'));
      await tester.pumpAndSettle();

      expect(find.text('Stall Photo'), findsOneWidget);
      expect(find.text('Tap to upload stall photo'), findsOneWidget);
      // Remove button should NOT be visible when there is no photo
      expect(find.text('Remove Photo'), findsNothing);
    });

    testWidgets('Success dialog Done button is rendered with center alignment', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (dialogCtx) => Dialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1B5E20),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                'Done',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Done'), findsOneWidget);
      final buttonFinder = find.widgetWithText(ElevatedButton, 'Done');
      expect(buttonFinder, findsOneWidget);

      final elevatedBtn = tester.widget<ElevatedButton>(buttonFinder);
      expect(elevatedBtn.style?.padding?.resolve({}), EdgeInsets.zero);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Done'), findsNothing);
    });
  });

  group('ManageStallsScreen Admin Sort & Filter Tests', () {
    testWidgets('AdminSortFilterModal renders admin facets and updates active count', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      String? appliedSort;
      String appliedMap = 'all';
      String appliedStatus = 'all';
      String appliedPhoto = 'all';
      String? appliedDay;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminSortFilterModal(
              sortOption: null,
              mapFilter: 'all',
              statusFilter: 'all',
              photoFilter: 'all',
              selectedDay: null,
              onApply: (sort, map, status, photo, day) {
                appliedSort = sort;
                appliedMap = map;
                appliedStatus = status;
                appliedPhoto = photo;
                appliedDay = day;
              },
              onReset: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Admin filter facets are visible
      expect(find.text('Sort & Filter Stalls'), findsOneWidget);
      expect(find.text('SORT BY'), findsOneWidget);
      expect(find.text('MAP ASSIGNMENT'), findsOneWidget);
      expect(find.text('OPERATING STATUS'), findsOneWidget);
      expect(find.text('STALL PHOTO'), findsOneWidget);
      expect(find.text('OPERATING DAY'), findsOneWidget);

      // Verify options
      expect(find.text('Name (A to Z)'), findsOneWidget);
      expect(find.text('Section / Slot'), findsOneWidget);
      expect(find.text('Assigned on Map'), findsOneWidget);
      expect(find.text('Missing Map Pin'), findsOneWidget);
      expect(find.text('Open Now'), findsOneWidget);
      expect(find.text('Has Photo'), findsOneWidget);
      expect(find.text('Missing Photo'), findsOneWidget);

      // Verify Apply Filters button has zero padding to prevent text squashing
      expect(find.text('Apply Filters'), findsOneWidget);
      final applyButton = find.widgetWithText(ElevatedButton, 'Apply Filters');
      expect(applyButton, findsOneWidget);
      final btnWidget = tester.widget<ElevatedButton>(applyButton);
      expect(btnWidget.style?.padding?.resolve({}), EdgeInsets.zero);

      // Tap a filter (e.g. Missing Map Pin)
      await tester.tap(find.text('Missing Map Pin'));
      await tester.pumpAndSettle();

      // Counter should update on Apply button
      expect(find.text('Apply Filters (1)'), findsOneWidget);

      // Tap Name (A to Z)
      await tester.tap(find.text('Name (A to Z)'));
      await tester.pumpAndSettle();
      expect(find.text('Apply Filters (2)'), findsOneWidget);

      // Tap Apply
      await tester.tap(find.text('Apply Filters (2)'));
      await tester.pumpAndSettle();

      expect(appliedSort, 'az');
      expect(appliedMap, 'unassigned');
      expect(appliedStatus, 'all');
      expect(appliedPhoto, 'all');
      expect(appliedDay, isNull);
    });

    test('Stall filtering logic supports Map Location and Photo status', () {
      final sampleStalls = [
        StallModel(
          documentId: 's1',
          stallId: 's1',
          name: 'Alpha Meat',
          category: 'Meat (Pork & Beef)',
          subcategories: const ['Pork Cuts'],
          products: const ['Pork Belly'],
          address: 'Stall 1',
          section: 'Meat Section',
          physicalStallId: 'slot_m_1',
          photoUrls: const ['https://example.com/photo1.jpg'],
          openTime: '5:00 AM',
          closeTime: '6:00 PM',
          daysOpen: const ['Daily'],
          latitude: 13.24,
          longitude: 123.53,
          status: 'open',
          isActive: true,
          updatedAt: DateTime(2026, 1, 1),
        ),
        StallModel(
          documentId: 's2',
          stallId: 's2',
          name: 'Beta Veggies',
          category: 'Produce & Vegetables',
          subcategories: const ['Fresh Vegetables'],
          products: const ['Cabbage'],
          address: 'Stall 2',
          section: 'Vegetable Row',
          physicalStallId: null,
          explicitHasMapLocation: false,
          photoUrls: const [],
          openTime: '6:00 AM',
          closeTime: '5:00 PM',
          daysOpen: const ['Mon', 'Wed', 'Fri'],
          latitude: 13.24,
          longitude: 123.53,
          status: 'closed',
          isActive: false,
          updatedAt: DateTime(2026, 2, 1),
        ),
      ];

      // Test map assignment filtering
      final assignedStalls = sampleStalls.where((s) => s.hasMapLocation).toList();
      expect(assignedStalls.length, 1);
      expect(assignedStalls.first.name, 'Alpha Meat');

      final unassignedStalls = sampleStalls.where((s) => !s.hasMapLocation).toList();
      expect(unassignedStalls.length, 1);
      expect(unassignedStalls.first.name, 'Beta Veggies');

      // Test photo filtering
      final withPhoto = sampleStalls.where((s) => s.photoUrls.isNotEmpty).toList();
      expect(withPhoto.length, 1);
      expect(withPhoto.first.name, 'Alpha Meat');

      final withoutPhoto = sampleStalls.where((s) => s.photoUrls.isEmpty).toList();
      expect(withoutPhoto.length, 1);
      expect(withoutPhoto.first.name, 'Beta Veggies');

      // Test section sorting
      sampleStalls.sort((a, b) {
        final aSec = (a.section ?? a.address).toLowerCase();
        final bSec = (b.section ?? b.address).toLowerCase();
        return aSec.compareTo(bSec);
      });
      expect(sampleStalls.first.section, 'Meat Section');
    });
  });
}
