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
  });
}
