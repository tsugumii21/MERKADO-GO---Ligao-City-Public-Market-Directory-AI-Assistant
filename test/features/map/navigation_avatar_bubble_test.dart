import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merkado_go/features/map/domain/navigation_models.dart';
import 'package:merkado_go/features/map/presentation/widgets/interactive_market_map.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const node1 = GraphNode(id: 'node_1', x: 100.0, y: 100.0, neighbors: ['node_2']);
  const node2 = GraphNode(id: 'node_2', x: 200.0, y: 100.0, neighbors: ['node_1', 'node_3']);
  const node3 = GraphNode(id: 'node_3', x: 200.0, y: 250.0, neighbors: ['node_2', 'node_4']);
  const node4 = GraphNode(id: 'node_4', x: 350.0, y: 250.0, neighbors: ['node_3']);

  final sampleRoute = NavigationRoute(
    nodeIds: const ['node_1', 'node_2', 'node_3', 'node_4'],
    nodes: const [node1, node2, node3, node4],
    points: const [
      Offset(100.0, 100.0),
      Offset(200.0, 100.0),
      Offset(200.0, 250.0),
      Offset(350.0, 250.0),
    ],
    steps: const [
      NavigationStep(
        stepNumber: 1,
        instruction: 'Start from Gate 11',
        distance: 100.0,
        direction: TurnDirection.start,
        nodeId: 'node_1',
      ),
      NavigationStep(
        stepNumber: 2,
        instruction: 'Turn right towards Corridor A',
        distance: 150.0,
        direction: TurnDirection.turnRight,
        nodeId: 'node_2',
      ),
      NavigationStep(
        stepNumber: 3,
        instruction: 'Turn left into Fish Alley',
        distance: 200.0,
        direction: TurnDirection.turnLeft,
        nodeId: 'node_3',
      ),
      NavigationStep(
        stepNumber: 4,
        instruction: 'Arrive at L. Pimentel Fish Stall',
        distance: 0.0,
        direction: TurnDirection.arrive,
        nodeId: 'node_4',
      ),
    ],
    totalDistance: 450.0,
    destinationStallId: 'id_202',
    destinationStallName: 'L. Pimentel Fish Stall',
  );

  group('Navigation Avatar and Enlarged Speech Bubble Tests', () {
    testWidgets('RouteOverlayPainter paints walking avatar and enlarged HUD without errors',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              size: const Size(8004.0, 8000.0),
              painter: RouteOverlayPainter(
                route: sampleRoute,
                nodeOffsetX: 0.0,
                nodeOffsetY: 0.0,
                pulseScale: 1.0,
                walkProgress: 0.45,
                isWalking: true,
                mapRotationRadians: 0.0,
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('RouteOverlayPainter paints arrival state without errors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              size: const Size(8004.0, 8000.0),
              painter: RouteOverlayPainter(
                route: sampleRoute,
                nodeOffsetX: 0.0,
                nodeOffsetY: 0.0,
                pulseScale: 1.2,
                walkProgress: 1.0,
                isWalking: false,
                mapRotationRadians: 0.5,
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
