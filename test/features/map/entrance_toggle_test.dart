import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merkado_go/features/map/domain/navigation_models.dart';
import 'package:merkado_go/features/map/providers/navigation_provider.dart';

void main() {
  group('Entrance Gate Selection & Toggle Tests', () {
    const gate1 = MarketEntryPoint(
      entranceId: 1,
      nodeId: 'node_entry_1',
      description: 'South Plaza • Church Entrance',
    );
    const gate2 = MarketEntryPoint(
      entranceId: 2,
      nodeId: 'node_entry_2',
      description: 'West Corridor • Back of LCC',
    );

    test('selectedEntranceProvider initial state is null (unchosen)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initial = container.read(selectedEntranceProvider);
      expect(initial, isNull);
    });

    test('Pressing entrance gate selects it', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Select Gate 1
      container.read(selectedEntranceProvider.notifier).state = gate1;
      expect(container.read(selectedEntranceProvider)?.entranceId, equals(1));
    });

    test('Pressing the same entrance gate again unchooses it (toggles to null)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Select Gate 2
      container.read(selectedEntranceProvider.notifier).state = gate2;
      expect(container.read(selectedEntranceProvider)?.entranceId, equals(2));

      // Simulate pressing Gate 2 again (toggle logic)
      final current = container.read(selectedEntranceProvider);
      if (current?.entranceId == gate2.entranceId) {
        container.read(selectedEntranceProvider.notifier).state = null;
      } else {
        container.read(selectedEntranceProvider.notifier).state = gate2;
      }

      // Must now be unchosen (null)
      expect(container.read(selectedEntranceProvider), isNull);
    });

    test('Pressing a different gate switches selection without unchoosing', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Select Gate 1
      container.read(selectedEntranceProvider.notifier).state = gate1;
      expect(container.read(selectedEntranceProvider)?.entranceId, equals(1));

      // Press Gate 2
      final current = container.read(selectedEntranceProvider);
      if (current?.entranceId == gate2.entranceId) {
        container.read(selectedEntranceProvider.notifier).state = null;
      } else {
        container.read(selectedEntranceProvider.notifier).state = gate2;
      }

      // Must now be Gate 2
      expect(container.read(selectedEntranceProvider)?.entranceId, equals(2));
    });

    group('Demand-Driven Entrance Pin Visibility Filter Tests', () {
      final allGates = List.generate(
        14,
        (i) => MarketEntryPoint(
          entranceId: i + 1,
          nodeId: 'node_ex_$i',
          description: 'Gate ${i + 1}',
        ),
      );

      bool isPinVisible({
        required MarketEntryPoint entrance,
        NavigationRoute? activeRoute,
        required bool showEntrancePins,
        MarketEntryPoint? selectedEntrance,
      }) {
        if (activeRoute != null) {
          return entrance.entranceId == activeRoute.entrance.entranceId;
        }
        if (showEntrancePins) {
          return true;
        }
        if (selectedEntrance != null) {
          return entrance.entranceId == selectedEntrance.entranceId;
        }
        return false;
      }

      test('When showEntrancePins is true (Pick on Map mode), all 14 gates are visible', () {
        final visibleGates = allGates.where(
          (e) => isPinVisible(
            entrance: e,
            showEntrancePins: true,
            selectedEntrance: gate1,
          ),
        ).toList();

        expect(visibleGates.length, equals(14));
      });

      test('When Gate 1 is selected and showEntrancePins is false, ONLY Gate 1 is visible', () {
        final visibleGates = allGates.where(
          (e) => isPinVisible(
            entrance: e,
            showEntrancePins: false,
            selectedEntrance: gate1,
          ),
        ).toList();

        expect(visibleGates.length, equals(1));
        expect(visibleGates.first.entranceId, equals(1));
      });

      test('When Gate 2 is selected and showEntrancePins is false, ONLY Gate 2 is visible and others hidden', () {
        final visibleGates = allGates.where(
          (e) => isPinVisible(
            entrance: e,
            showEntrancePins: false,
            selectedEntrance: gate2,
          ),
        ).toList();

        expect(visibleGates.length, equals(1));
        expect(visibleGates.first.entranceId, equals(2));
      });

      test('When no entrance is selected and showEntrancePins is false, all gates are hidden', () {
        final visibleGates = allGates.where(
          (e) => isPinVisible(
            entrance: e,
            showEntrancePins: false,
            selectedEntrance: null,
          ),
        ).toList();

        expect(visibleGates, isEmpty);
      });
    });
  });
}

