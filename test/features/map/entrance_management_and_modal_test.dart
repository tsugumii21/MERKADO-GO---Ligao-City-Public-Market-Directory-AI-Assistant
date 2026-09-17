import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merkado_go/features/admin/presentation/admin_manage_entrances_screen.dart';
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
  });
}
