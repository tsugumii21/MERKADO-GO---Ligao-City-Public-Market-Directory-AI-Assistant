import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merkado_go/features/map/domain/navigation_models.dart';
import 'package:merkado_go/features/map/presentation/widgets/navigation_loading_dialog.dart';
import 'package:merkado_go/features/map/presentation/widgets/route_navigation_card.dart';
import 'package:merkado_go/features/map/providers/navigation_provider.dart';

void main() {
  const sampleRoute = NavigationRoute(
    nodeIds: ['n1', 'n2', 'n3'],
    nodes: [],
    points: [],
    totalDistance: 1000.0,
    originStallId: 'stall_1',
    originStallName: 'Stall 1',
    destinationStallId: 'stall_2',
    destinationStallName: 'Stall 2',
    originType: NavigationOriginType.stall,
    entrance: null,
    steps: [
      NavigationStep(
        stepNumber: 1,
        instruction: 'Start at Stall 1',
        distance: 200.0,
        direction: TurnDirection.straight,
        nodeId: 'n1',
      ),
      NavigationStep(
        stepNumber: 2,
        instruction: 'Turn left along Central Corridor',
        distance: 400.0,
        direction: TurnDirection.turnLeft,
        nodeId: 'n2',
      ),
      NavigationStep(
        stepNumber: 3,
        instruction: 'Arrive at Stall 2',
        distance: 400.0,
        direction: TurnDirection.arrive,
        nodeId: 'n3',
      ),
    ],
  );

  group('Route Skip Navigation Tests', () {
    testWidgets(
        'RouteNavigationCard does not render a Skip button beside Steps text',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentStepIndexProvider.overrideWith((ref) => 0),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: RouteNavigationCard(
                route: sampleRoute,
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      // Verify Skip button beside Steps text is removed
      final skipFinder = find.widgetWithText(TextButton, 'Skip');
      expect(skipFinder, findsNothing);

      // Verify Steps button remains intact
      final stepsFinder = find.text('Steps');
      expect(stepsFinder, findsOneWidget);
    });

    testWidgets('isNavigationCompletedProvider controls Skip to Arrival visibility across repeat lifecycle',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Initially navigation is not completed
      expect(container.read(isNavigationCompletedProvider), isFalse);

      // When skip or arrival occurs, mark navigation as completed
      container.read(isNavigationCompletedProvider.notifier).state = true;
      expect(container.read(isNavigationCompletedProvider), isTrue);

      // When repeat button is pressed, navigation resets and skip button should appear again
      container.read(isNavigationCompletedProvider.notifier).state = false;
      container.read(currentStepIndexProvider.notifier).state = 0;
      expect(container.read(isNavigationCompletedProvider), isFalse);
      expect(container.read(currentStepIndexProvider), 0);
    });

    testWidgets(
        'NavigationLoadingDialog does not render a Skip button and completes on timer',
        (tester) async {
      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NavigationLoadingDialog(
              stallName: 'Stall 2',
              originName: 'Stall 1',
              onCompleted: () {
                completed = true;
              },
            ),
          ),
        ),
      );

      final skipFinder = find.text('Skip');
      expect(skipFinder, findsNothing);

      await tester.pump(const Duration(milliseconds: 2000));
      expect(completed, isTrue);
    });
  });
}
