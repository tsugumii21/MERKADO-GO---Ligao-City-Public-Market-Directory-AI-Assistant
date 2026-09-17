import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merkado_go/features/admin/presentation/admin_manage_entrances_screen.dart';
import 'package:merkado_go/features/admin/presentation/widgets/admin_edit_entrance_sheet.dart';
import 'package:merkado_go/features/map/domain/navigation_models.dart';
import 'package:merkado_go/features/map/presentation/widgets/entrance_detail_sheet.dart';
import 'package:merkado_go/features/map/providers/entrance_provider.dart';
import 'package:merkado_go/features/map/providers/navigation_provider.dart';

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
}
