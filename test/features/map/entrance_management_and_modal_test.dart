import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merkado_go/features/admin/presentation/admin_manage_entrances_screen.dart';
import 'package:merkado_go/features/admin/presentation/widgets/admin_edit_entrance_sheet.dart';
import 'package:merkado_go/features/map/domain/navigation_models.dart';
import 'package:merkado_go/features/map/presentation/widgets/entrance_detail_sheet.dart';
import 'package:merkado_go/features/map/presentation/widgets/entrance_selector_sheet.dart';
import 'package:merkado_go/features/map/presentation/widgets/route_navigation_card.dart';
import 'package:merkado_go/features/map/providers/entrance_provider.dart';
import 'package:merkado_go/features/map/providers/navigation_provider.dart';
import 'package:merkado_go/providers/stall_provider.dart';
import 'package:merkado_go/models/stall_model.dart';

void main() {
  group('MarketEntryPoint Model Tests', () {
    test('default displayName uses Gate X when title is null or empty', () {
      const entry = MarketEntryPoint(
        entranceId: 1,
        nodeId: 'node_ex_1',
        description: 'Straight From Church',
      );

      expect(entry.displayName, equals('Gate 1'));
      expect(entry.effectiveDescription, equals('Straight From Church'));
      expect(entry.effectiveLandmark, equals('Straight From Church'));
    });

    test('displayName returns custom title when configured', () {
      const entry = MarketEntryPoint(
        entranceId: 1,
        nodeId: 'node_ex_1',
        description: 'Straight From Church',
        title: 'Gate 1 - Church Entrance',
        landmark: 'Legazpi St. Church Front',
      );

      expect(entry.displayName, equals('Gate 1 - Church Entrance'));
      expect(entry.effectiveLandmark, equals('Legazpi St. Church Front'));
    });

    test('serialization roundtrip preserves all fields', () {
      final now = DateTime.now();
      final original = MarketEntryPoint(
        entranceId: 3,
        nodeId: 'node_ex_3',
        description: 'Side of LCC',
        title: 'Gate 3: LCC Side Gate',
        landmark: 'Beside Supermarket entrance',
        imageUrl: 'https://res.cloudinary.com/test/image/upload/gate3.jpg',
        updatedAt: now,
      );

      final map = original.toMap();
      final restored = MarketEntryPoint.fromJson(map);

      expect(restored.entranceId, equals(3));
      expect(restored.nodeId, equals('node_ex_3'));
      expect(restored.description, equals('Side of LCC'));
      expect(restored.title, equals('Gate 3: LCC Side Gate'));
      expect(restored.landmark, equals('Beside Supermarket entrance'));
      expect(restored.imageUrl, equals('https://res.cloudinary.com/test/image/upload/gate3.jpg'));
      expect(restored.displayName, equals('Gate 3: LCC Side Gate'));
    });

    test('copyWith updates fields while preserving existing values', () {
      const original = MarketEntryPoint(
        entranceId: 5,
        nodeId: 'node_ex_t4',
        description: 'Rice Section From Wet Market',
      );

      final updated = original.copyWith(
        imageUrl: 'https://res.cloudinary.com/test/image/upload/gate5.jpg',
        landmark: 'Wet Market corner',
      );

      expect(updated.entranceId, equals(5));
      expect(updated.nodeId, equals('node_ex_t4'));
      expect(updated.description, equals('Rice Section From Wet Market'));
      expect(updated.imageUrl, equals('https://res.cloudinary.com/test/image/upload/gate5.jpg'));
      expect(updated.landmark, equals('Wet Market corner'));
    });

    test('photo_removed and has_photo flags properly clear imageUrl in fromJson', () {
      final jsonWithDeletedPhoto = {
        'entrance_id': 1,
        'node_id': 'node_ex_1',
        'description': 'Straight From Church',
        'image_url': 'https://res.cloudinary.com/test/image/upload/gate1.jpg',
        'photo_removed': true,
        'has_photo': false,
      };

      final parsed = MarketEntryPoint.fromJson(jsonWithDeletedPhoto);
      expect(parsed.imageUrl, isNull);
    });

    test('toMap emits has_photo and photo_removed flags', () {
      const entryWithoutPhoto = MarketEntryPoint(
        entranceId: 1,
        nodeId: 'node_ex_1',
        description: 'Straight From Church',
      );

      final map = entryWithoutPhoto.toMap();
      expect(map['has_photo'], isFalse);
      expect(map['photo_removed'], isTrue);
      expect(map.containsKey('image_url'), isFalse);

      const entryWithPhoto = MarketEntryPoint(
        entranceId: 1,
        nodeId: 'node_ex_1',
        description: 'Straight From Church',
        imageUrl: 'https://test/gate1.jpg',
      );

      final mapWithPhoto = entryWithPhoto.toMap();
      expect(mapWithPhoto['has_photo'], isTrue);
      expect(mapWithPhoto['photo_removed'], isFalse);
      expect(mapWithPhoto['image_url'], equals('https://test/gate1.jpg'));
    });
  });

  group('marketEntrancesProvider Merge & Fallback Tests', () {
    test('merges baseline 14 gates with custom Firestore data', () async {
      final baseline = [
        const MarketEntryPoint(
          entranceId: 1,
          nodeId: 'node_ex_1',
          description: 'Straight From Church',
        ),
        const MarketEntryPoint(
          entranceId: 2,
          nodeId: 'node_ex_2',
          description: 'The Back of LCC',
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          entryPointsProvider.overrideWithValue(baseline),
          firestoreEntrancesStreamProvider.overrideWith((ref) {
            return Stream.value({
              1: const MarketEntryPoint(
                entranceId: 1,
                nodeId: 'node_ex_1',
                description: 'Straight From Church',
                title: 'Gate 1 - Church Grand Entrance',
                imageUrl: 'https://custom.image/gate1.jpg',
              ),
            });
          }),
        ],
      );
      addTearDown(container.dispose);

      await container.read(firestoreEntrancesStreamProvider.future);
      final merged = container.read(marketEntrancesProvider);
      expect(merged.length, equals(2));

      // Gate 1 should have custom title and image
      final gate1 = merged.firstWhere((e) => e.entranceId == 1);
      expect(gate1.title, equals('Gate 1 - Church Grand Entrance'));
      expect(gate1.imageUrl, equals('https://custom.image/gate1.jpg'));

      // Gate 2 should have deterministic Cloudinary fallback URL
      final gate2 = merged.firstWhere((e) => e.entranceId == 2);
      expect(gate2.imageUrl, contains('entry_2.jpg'));
      expect(gate2.displayName, equals('Gate 2'));
    });
  });

  group('EntranceDetailSheet Widget Tests', () {
    testWidgets('renders gate badge, title, landmark, and route action button',
        (tester) async {
      const testGate = MarketEntryPoint(
        entranceId: 1,
        nodeId: 'node_ex_1',
        description: 'Straight From Church',
        title: 'Gate 1 - Church Entrance',
        landmark: 'Legazpi St. Entrance',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            marketEntrancesProvider.overrideWithValue([testGate]),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: EntranceDetailSheet(
                entrance: testGate,
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Gate 1'), findsWidgets);
      expect(find.text('Gate 1 - Church Entrance'), findsOneWidget);
      expect(find.text('Straight From Church'), findsOneWidget);
      expect(find.text('Legazpi St. Entrance'), findsOneWidget);
      expect(find.text('Snap: node_ex_1'), findsNothing);
      expect(find.text('Start Route From Here'), findsOneWidget);
    });

    testWidgets(
        'default gate renders Gate X title and landmark without duplicate text',
        (tester) async {
      const defaultGate = MarketEntryPoint(
        entranceId: 1,
        nodeId: 'node_ex_1',
        description: 'Straight From Church',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            marketEntrancesProvider.overrideWithValue([defaultGate]),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: EntranceDetailSheet(
                entrance: defaultGate,
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Gate 1 appears exactly ONCE as the prominent title
      expect(find.text('Gate 1'), findsOneWidget);
      // 'Straight From Church' appears exactly ONCE in the landmark chip
      expect(find.text('Straight From Church'), findsOneWidget);
      // Sheet header
      expect(find.text('Entrance Details'), findsOneWidget);
      expect(find.text('Start Route From Here'), findsOneWidget);
    });

    testWidgets('tapping Start Route From Here updates selectedEntranceProvider',
        (tester) async {
      const testGate = MarketEntryPoint(
        entranceId: 4,
        nodeId: 'node_ex_t3',
        description: 'Wet Market Left Side',
      );

      final container = ProviderContainer(
        overrides: [
          marketEntrancesProvider.overrideWithValue([testGate]),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: EntranceDetailSheet(
                entrance: testGate,
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap 'Start Route From Here'
      await tester.tap(find.text('Start Route From Here'));
      await tester.pumpAndSettle();

      // Selected entrance should now be testGate
      final selected = container.read(selectedEntranceProvider);
      expect(selected?.entranceId, equals(4));
    });

    testWidgets('tapping Start Route From Here triggers onStartRoute callback',
        (tester) async {
      const testGate = MarketEntryPoint(
        entranceId: 5,
        nodeId: 'node_ex_t4',
        description: 'Rice Section From Wet Market',
      );

      bool startRouteCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            marketEntrancesProvider.overrideWithValue([testGate]),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: EntranceDetailSheet(
                entrance: testGate,
                onClose: () {},
                onStartRoute: () {
                  startRouteCalled = true;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Start Route From Here'));
      await tester.pumpAndSettle();

      expect(startRouteCalled, isTrue);
    });

    testWidgets('closing sheet via close button does not trigger onStartRoute',
        (tester) async {
      const testGate = MarketEntryPoint(
        entranceId: 2,
        nodeId: 'node_ex_2',
        description: 'The Back of LCC',
      );

      bool startRouteCalled = false;
      bool closeCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            marketEntrancesProvider.overrideWithValue([testGate]),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: EntranceDetailSheet(
                entrance: testGate,
                onClose: () {
                  closeCalled = true;
                },
                onStartRoute: () {
                  startRouteCalled = true;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap close icon button
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(closeCalled, isTrue);
      expect(startRouteCalled, isFalse);
    });

    testWidgets(
        'when entrance is currently selected, button displays Clear Selection instead of Start Route From Here',
        (tester) async {
      const testGate = MarketEntryPoint(
        entranceId: 1,
        nodeId: 'node_ex_1',
        description: 'Straight From Church',
      );

      final container = ProviderContainer(
        overrides: [
          marketEntrancesProvider.overrideWithValue([testGate]),
          selectedEntranceProvider.overrideWith((ref) => testGate),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: EntranceDetailSheet(
                entrance: testGate,
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should display Clear Selection button
      expect(find.text('Clear Selection'), findsOneWidget);
      expect(find.text('Start Route From Here'), findsNothing);
      expect(find.byIcon(Icons.clear_rounded), findsOneWidget);
    });

    testWidgets(
        'tapping Clear Selection resets selectedEntranceProvider and triggers onClearSelection',
        (tester) async {
      const testGate = MarketEntryPoint(
        entranceId: 1,
        nodeId: 'node_ex_1',
        description: 'Straight From Church',
      );

      final container = ProviderContainer(
        overrides: [
          marketEntrancesProvider.overrideWithValue([testGate]),
          selectedEntranceProvider.overrideWith((ref) => testGate),
        ],
      );
      addTearDown(container.dispose);

      bool clearCalled = false;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: EntranceDetailSheet(
                entrance: testGate,
                onClose: () {},
                onClearSelection: () {
                  clearCalled = true;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap 'Clear Selection'
      await tester.tap(find.text('Clear Selection'));
      await tester.pumpAndSettle();

      expect(clearCalled, isTrue);
      // selectedEntranceProvider should now be null
      expect(container.read(selectedEntranceProvider), isNull);
    });

    testWidgets(
        'when pickingOriginTargetStall is set, button displays Start Route to StallName and tapping resets target and picking state',
        (tester) async {
      const testGate = MarketEntryPoint(
        entranceId: 1,
        nodeId: 'node_ex_1',
        description: 'Straight From Church',
      );
      final testStall = StallModel(
        stallId: 'stall_101',
        name: 'Aling Nena Fruit Stand',
        category: 'Fruits',
        products: ['Mango', 'Banana'],
        address: 'Fruit Section',
        photoUrls: [],
        openTime: '6:00 AM',
        closeTime: '6:00 PM',
        daysOpen: ['Daily'],
        latitude: 13.24,
        longitude: 123.54,
        isActive: true,
        updatedAt: DateTime.now(),
      );

      final container = ProviderContainer(
        overrides: [
          marketEntrancesProvider.overrideWithValue([testGate]),
          pickingOriginTargetStallProvider.overrideWith((ref) => testStall),
          isPickingEntranceOnMapProvider.overrideWith((ref) => true),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: EntranceDetailSheet(
                entrance: testGate,
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Start Route to Aling Nena Fruit Stand'), findsOneWidget);

      await tester.tap(find.text('Start Route to Aling Nena Fruit Stand'));
      await tester.pump();

      expect(container.read(pickingOriginTargetStallProvider), isNull);
      expect(container.read(isPickingEntranceOnMapProvider), isFalse);
    });
  });

  group('AdminManageEntrancesScreen Widget Tests', () {
    testWidgets('renders entrance list and search filter filters properly',
        (tester) async {
      final sampleGates = [
        const MarketEntryPoint(
          entranceId: 1,
          nodeId: 'node_ex_1',
          description: 'Straight From Church',
          title: 'Gate 1 - Church Entrance',
        ),
        const MarketEntryPoint(
          entranceId: 2,
          nodeId: 'node_ex_2',
          description: 'The Back of LCC',
          title: 'Gate 2 - LCC Rear',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            marketEntrancesProvider.overrideWithValue(sampleGates),
          ],
          child: const MaterialApp(
            home: AdminManageEntrancesScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Manage Entrances'), findsOneWidget);
      expect(find.text('2 ENTRANCES'), findsOneWidget);
      expect(find.text('Gate 1 - Church Entrance'), findsOneWidget);
      expect(find.text('Gate 2 - LCC Rear'), findsOneWidget);

      // Filter by "Church"
      await tester.enterText(find.byType(TextField), 'Church');
      await tester.pumpAndSettle();

      expect(find.text('1 ENTRANCES'), findsOneWidget);
      expect(find.text('Gate 1 - Church Entrance'), findsOneWidget);
      expect(find.text('Gate 2 - LCC Rear'), findsNothing);
    });

    testWidgets(
        'does not render preview eye button or pathway snap node IDs in entrance cards',
        (tester) async {
      final sampleGates = [
        const MarketEntryPoint(
          entranceId: 1,
          nodeId: 'node_ex_1',
          description: 'Straight From Church',
          title: 'Gate 1 - Church Entrance',
          landmark: 'Legazpi St. Entrance',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            marketEntrancesProvider.overrideWithValue(sampleGates),
          ],
          child: const MaterialApp(
            home: AdminManageEntrancesScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Eye button must NOT exist
      expect(find.byIcon(Icons.visibility_outlined), findsNothing);
      // Snap node ID must NOT exist in the card
      expect(find.text('node_ex_1'), findsNothing);
      // Edit button must exist
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    });

    testWidgets('renders RefreshIndicator with clamping scroll physics',
        (tester) async {
      final sampleGates = [
        const MarketEntryPoint(
          entranceId: 1,
          nodeId: 'node_ex_1',
          description: 'Straight From Church',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            marketEntrancesProvider.overrideWithValue(sampleGates),
          ],
          child: const MaterialApp(
            home: AdminManageEntrancesScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(RefreshIndicator), findsOneWidget);

      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.physics, isA<AlwaysScrollableScrollPhysics>());
      final physics = listView.physics as AlwaysScrollableScrollPhysics;
      expect(physics.parent, isA<ClampingScrollPhysics>());
    });
  });

  group('AdminEditEntranceSheet Widget Tests', () {
    testWidgets(
        'does not render Vector Pathway Snap Node and provides Remove Photo button when photo exists',
        (tester) async {
      const gateWithPhoto = MarketEntryPoint(
        entranceId: 1,
        nodeId: 'node_ex_1',
        description: 'Straight From Church',
        title: 'Gate 1',
        landmark: 'Legazpi St. Entrance',
        imageUrl: 'https://res.cloudinary.com/test/image/upload/gate1.jpg',
      );

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AdminEditEntranceSheet(
                entrance: gateWithPhoto,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Vector pathway snap node must NOT exist
      expect(find.textContaining('Vector Pathway Snap Node'), findsNothing);
      expect(find.text('node_ex_1'), findsNothing);

      // Remove Photo button must exist because photo is present
      expect(find.text('Remove Photo'), findsOneWidget);

      // Tap Remove Photo
      await tester.tap(find.text('Remove Photo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Remove Photo button disappears
      expect(find.text('Remove Photo'), findsNothing);
      // Placeholder graphic is now shown
      expect(find.text('No Photo Configured'), findsOneWidget);
    });
  });

  group('EntranceSelectorSheet Widget Tests', () {
    const gate1 = MarketEntryPoint(
      entranceId: 1,
      nodeId: 'node_ex_1',
      description: 'Straight From Church',
      title: 'Gate 1 - Church Entrance',
      landmark: 'Legazpi St. Entrance',
    );
    const gate2 = MarketEntryPoint(
      entranceId: 2,
      nodeId: 'node_ex_2',
      description: 'West Corridor • Back of LCC',
      title: 'Gate 2',
      landmark: 'Behind LCC',
    );

    testWidgets(
        'renders Clear Selected Entrance button when an entrance is already active',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          marketEntrancesProvider.overrideWithValue([gate1, gate2]),
          selectedEntranceProvider.overrideWith((ref) => gate1),
          allStallsProvider.overrideWith((ref) => Stream.value([])),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: EntranceSelectorSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Clear Selected Entrance button must be present
      expect(find.text('Clear Selected Entrance'), findsOneWidget);
      expect(find.byIcon(Icons.clear_rounded), findsOneWidget);
      expect(
          find.textContaining('Select Starting Entrance • Gate 1'), findsNothing);
    });

    testWidgets(
        'tapping Clear Selected Entrance resets selectedEntranceProvider to null',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          marketEntrancesProvider.overrideWithValue([gate1, gate2]),
          selectedEntranceProvider.overrideWith((ref) => gate1),
          allStallsProvider.overrideWith((ref) => Stream.value([])),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: EntranceSelectorSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Clear Selected Entrance'));
      await tester.pumpAndSettle();

      expect(container.read(selectedEntranceProvider), isNull);
    });

    testWidgets(
        'tapping a different gate changes button to Select Starting Entrance • Gate 2',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          marketEntrancesProvider.overrideWithValue([gate1, gate2]),
          selectedEntranceProvider.overrideWith((ref) => gate1),
          allStallsProvider.overrideWith((ref) => Stream.value([])),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: EntranceSelectorSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially Clear Selected Entrance
      expect(find.text('Clear Selected Entrance'), findsOneWidget);

      // Tap Gate 2 in the list
      await tester.tap(find.text('Entrance Gate 2'));
      await tester.pumpAndSettle();

      // Button must now say Select Starting Entrance • Gate 2
      expect(find.text('Select Starting Entrance • Gate 2'), findsOneWidget);
      expect(find.text('Clear Selected Entrance'), findsNothing);

      // Confirming Gate 2 updates selectedEntranceProvider
      await tester.tap(find.text('Select Starting Entrance • Gate 2'));
      await tester.pumpAndSettle();

      expect(container.read(selectedEntranceProvider)?.entranceId, equals(2));
    });

    testWidgets('tapping Pick on Map closes sheet with pick_on_map result',
        (tester) async {
      const gate1 = MarketEntryPoint(
        entranceId: 1,
        nodeId: 'node_ex_1',
        description: 'Straight From Church',
      );

      final container = ProviderContainer(
        overrides: [
          marketEntrancesProvider.overrideWithValue([gate1]),
          allStallsProvider.overrideWith((ref) => Stream.value([])),
        ],
      );
      addTearDown(container.dispose);

      dynamic returnedResult;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    returnedResult = await EntranceSelectorSheet.show(
                      context,
                      targetStallId: 'stall_1',
                      targetStallName: 'Target Stall',
                    );
                  },
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Pick on the Map'), findsOneWidget);

      await tester.tap(find.text('Pick on the Map'));
      await tester.pumpAndSettle();

      expect(returnedResult, equals('pick_on_map'));
    });
  });

  _registerRouteNavigationChangeTests();
}

class _TestActiveRouteNotifier extends ActiveRouteNotifier {
  _TestActiveRouteNotifier(super.ref, NavigationRoute? initial) {
    state = initial;
  }
}

void _registerRouteNavigationChangeTests() {
  group('Route Navigation Entrance Change Tests', () {
    testWidgets(
        'RouteNavigationCard calls onChangeEntrance when tapping origin in minimized bar',
        (tester) async {
      bool changed = false;
      const route = NavigationRoute(
        nodeIds: ['node_ex_1', 'node_ex_t1'],
        nodes: [],
        points: [],
        steps: [
          NavigationStep(
            stepNumber: 1,
            instruction: 'Head straight',
            distance: 10,
            direction: TurnDirection.straight,
            nodeId: 'node_ex_1',
          ),
        ],
        totalDistance: 10,
        destinationStallId: 'stall_1',
        destinationStallName: 'Target Stall',
        entrance: MarketEntryPoint(
          entranceId: 1,
          nodeId: 'node_ex_1',
          description: 'Gate 1 Description',
        ),
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: RouteNavigationCard(
                route: route,
                onChangeEntrance: () {
                  changed = true;
                },
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('1 Steps • Gate 1'), findsOneWidget);

      await tester.tap(find.text('1 Steps • Gate 1'));
      await tester.pumpAndSettle();

      expect(changed, isTrue);
    });

    testWidgets(
        'RouteNavigationCard calls onChangeEntrance when tapping origin in expanded content',
        (tester) async {
      bool changed = false;
      const route = NavigationRoute(
        nodeIds: ['node_ex_1', 'node_ex_t1'],
        nodes: [],
        points: [],
        steps: [
          NavigationStep(
            stepNumber: 1,
            instruction: 'Head straight',
            distance: 10,
            direction: TurnDirection.straight,
            nodeId: 'node_ex_1',
          ),
        ],
        totalDistance: 10,
        destinationStallId: 'stall_1',
        destinationStallName: 'Target Stall',
        entrance: MarketEntryPoint(
          entranceId: 1,
          nodeId: 'node_ex_1',
          description: 'Gate 1 Description',
        ),
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: RouteNavigationCard(
                route: route,
                onChangeEntrance: () {
                  changed = true;
                },
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      // Expand card
      await tester.tap(find.text('Steps'));
      await tester.pumpAndSettle();

      expect(find.text('From Gate 1: Gate 1 Description'), findsOneWidget);

      await tester.tap(find.text('From Gate 1: Gate 1 Description'));
      await tester.pumpAndSettle();

      expect(changed, isTrue);
    });

    testWidgets(
        'EntranceDetailSheet displays Start Route to destination stall when activeRoute is set',
        (tester) async {
      const gate2 = MarketEntryPoint(
        entranceId: 2,
        nodeId: 'node_ex_2',
        description: 'Gate 2 Entrance',
      );
      const activeRoute = NavigationRoute(
        nodeIds: ['node_ex_1'],
        nodes: [],
        points: [],
        steps: [],
        totalDistance: 10,
        destinationStallId: 'stall_88',
        destinationStallName: 'Wet Market Stall 88',
        entrance: MarketEntryPoint(
          entranceId: 1,
          nodeId: 'node_ex_1',
          description: 'Gate 1 Entrance',
        ),
      );

      final container = ProviderContainer(
        overrides: [
          marketEntrancesProvider.overrideWithValue([gate2]),
          activeRouteProvider.overrideWith(
            (ref) => _TestActiveRouteNotifier(ref, activeRoute),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => EntranceDetailSheet.show(context, gate2),
                  child: const Text('Open Detail'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Detail'));
      await tester.pumpAndSettle();

      expect(find.text('Start Route to Wet Market Stall 88'), findsOneWidget);
    });

    testWidgets(
        'EntranceDetailSheet in picking mode shows Start Route to destination even if gate matches selectedEntrance',
        (tester) async {
      const gate1 = MarketEntryPoint(
        entranceId: 1,
        nodeId: 'node_ex_1',
        description: 'Gate 1 Entrance',
      );
      final targetStall = StallModel(
        stallId: 'stall_88',
        name: 'Wet Market Stall 88',
        category: 'Fish',
        products: const [],
        address: '',
        photoUrls: const [],
        openTime: '',
        closeTime: '',
        daysOpen: const [],
        latitude: 0,
        longitude: 0,
        isActive: true,
        updatedAt: DateTime.now(),
      );

      final container = ProviderContainer(
        overrides: [
          marketEntrancesProvider.overrideWithValue([gate1]),
          selectedEntranceProvider.overrideWith((ref) => gate1),
          pickingOriginTargetStallProvider.overrideWith((ref) => targetStall),
          isPickingEntranceOnMapProvider.overrideWith((ref) => true),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => EntranceDetailSheet.show(context, gate1),
                  child: const Text('Open Detail'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Detail'));
      await tester.pumpAndSettle();

      expect(find.text('Start Route to Wet Market Stall 88'), findsOneWidget);
      expect(find.text('Clear Selection'), findsNothing);
    });

    testWidgets(
        'EntranceDetailSheet reroutes to target stall when tapping Start Route in picking mode',
        (tester) async {
      const gate2 = MarketEntryPoint(
        entranceId: 2,
        nodeId: 'node_ex_2',
        description: 'Gate 2 Entrance',
      );
      final targetStall = StallModel(
        stallId: 'stall_88',
        name: 'Wet Market Stall 88',
        category: 'Fish',
        products: const [],
        address: '',
        photoUrls: const [],
        openTime: '',
        closeTime: '',
        daysOpen: const [],
        latitude: 0,
        longitude: 0,
        isActive: true,
        updatedAt: DateTime.now(),
      );

      late _SpyActiveRouteNotifier spyNotifier;

      final container = ProviderContainer(
        overrides: [
          marketEntrancesProvider.overrideWithValue([gate2]),
          pickingOriginTargetStallProvider.overrideWith((ref) => targetStall),
          isPickingEntranceOnMapProvider.overrideWith((ref) => true),
          activeRouteProvider.overrideWith((ref) {
            spyNotifier = _SpyActiveRouteNotifier(ref);
            return spyNotifier;
          }),
        ],
      );
      addTearDown(container.dispose);

      bool startRouteCallbackCalled = false;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => EntranceDetailSheet.show(
                    context,
                    gate2,
                    onStartRoute: () {
                      startRouteCallbackCalled = true;
                    },
                  ),
                  child: const Text('Open Detail'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Detail'));
      await tester.pumpAndSettle();

      expect(find.text('Start Route to Wet Market Stall 88'), findsOneWidget);

      await tester.tap(find.text('Start Route to Wet Market Stall 88'));
      await tester.pumpAndSettle();

      expect(startRouteCallbackCalled, isTrue);
      expect(spyNotifier.lastNavigatedStallId, equals('stall_88'));
      expect(spyNotifier.lastNavigatedStallName, equals('Wet Market Stall 88'));
      expect(spyNotifier.lastNavigatedEntrance?.entranceId, equals(2));
    });
  });
}

class _SpyActiveRouteNotifier extends ActiveRouteNotifier {
  String? lastNavigatedStallId;
  String? lastNavigatedStallName;
  MarketEntryPoint? lastNavigatedEntrance;

  _SpyActiveRouteNotifier(super.ref, [NavigationRoute? initial]) {
    state = initial;
  }

  @override
  Future<void> navigateToStall({
    required String stallId,
    String? stallName,
    MarketEntryPoint? entranceOverride,
  }) async {
    lastNavigatedStallId = stallId;
    lastNavigatedStallName = stallName;
    lastNavigatedEntrance = entranceOverride;
  }
}
