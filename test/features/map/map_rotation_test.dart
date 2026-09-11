import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merkado_go/features/map/domain/navigation_models.dart';
import 'package:merkado_go/features/map/presentation/widgets/interactive_market_map.dart';
import 'package:merkado_go/models/stall_model.dart';

void main() {
  group('Map Rotation and Redirection Preservation Tests', () {
    const node1 = GraphNode(id: 'node_ex_n2', x: 200.0, y: 300.0, neighbors: ['node_ex_n3']);
    const node2 = GraphNode(id: 'node_ex_n3', x: 250.0, y: 300.0, neighbors: ['node_ex_n2']);
    const node3 = GraphNode(id: 'node_ex_n4', x: 300.0, y: 300.0, neighbors: ['node_ex_n3']);

    final sampleRouteA = NavigationRoute(
      nodeIds: const ['node_ex_n2', 'node_ex_n3'],
      nodes: const [node1, node2],
      points: const [Offset(200.0, 300.0), Offset(250.0, 300.0)],
      steps: const [
        NavigationStep(
          stepNumber: 1,
          instruction: 'Walk east',
          distance: 50.0,
          direction: TurnDirection.straight,
          nodeId: 'node_ex_n2',
        ),
      ],
      totalDistance: 50.0,
      entrance: null,
      originType: NavigationOriginType.stall,
      originStallId: 'id_202',
      originStallName: 'Stall 202',
      destinationStallId: 'id_126',
      destinationStallName: 'Stall 126',
    );

    final sampleRouteRedirected = NavigationRoute(
      nodeIds: const ['node_ex_n2', 'node_ex_n3', 'node_ex_n4'],
      nodes: const [node1, node2, node3],
      points: const [Offset(200.0, 300.0), Offset(250.0, 300.0), Offset(300.0, 300.0)],
      steps: const [
        NavigationStep(
          stepNumber: 1,
          instruction: 'Walk east towards redirected stall',
          distance: 100.0,
          direction: TurnDirection.straight,
          nodeId: 'node_ex_n2',
        ),
      ],
      totalDistance: 100.0,
      entrance: null,
      originType: NavigationOriginType.stall,
      originStallId: 'id_202',
      originStallName: 'Stall 202',
      destinationStallId: 'id_300',
      destinationStallName: 'Stall 300 (Redirected)',
    );

    final stalls = [
      StallModel(
        stallId: 'id_202',
        stallNumber: '202',
        name: 'Origin Vendor',
        category: 'Fish Section',
        products: const ['Bangus'],
        address: 'Fish Section',
        photoUrls: const [],
        openTime: '06:00',
        closeTime: '18:00',
        daysOpen: const ['Monday'],
        latitude: 13.0,
        longitude: 123.0,
        isActive: true,
        updatedAt: DateTime.now(),
      ),
      StallModel(
        stallId: 'id_126',
        stallNumber: '126',
        name: 'Destination Vendor',
        category: 'Dry Goods',
        products: const ['Clothes'],
        address: 'Dry Section',
        photoUrls: const [],
        openTime: '06:00',
        closeTime: '18:00',
        daysOpen: const ['Monday'],
        latitude: 13.0,
        longitude: 123.0,
        isActive: true,
        updatedAt: DateTime.now(),
      ),
    ];

    testWidgets('Map rotation controls rotate map and reset back to North', (tester) async {
      final mapKey = GlobalKey<InteractiveMarketMapState>();
      final transformController = TransformationController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 800,
              child: InteractiveMarketMap(
                key: mapKey,
                transformationController: transformController,
                stalls: stalls,
              ),
            ),
          ),
        ),
      );

      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // 1. Initial rotation should be 0 (North)
      final initialRot = math.atan2(transformController.value.storage[1], transformController.value.storage[0]);
      expect(initialRot.abs(), lessThan(0.01));

      // 2. Rotate by 90 degrees using rotateBy
      mapKey.currentState!.rotateBy(math.pi / 2, animate: false);
      for (int i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final rotatedRot = math.atan2(transformController.value.storage[1], transformController.value.storage[0]);
      expect((rotatedRot - (math.pi / 2)).abs(), lessThan(0.05));

      // 3. Reset rotation back to North
      mapKey.currentState!.resetRotation(animate: false);
      for (int i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final resetRot = math.atan2(transformController.value.storage[1], transformController.value.storage[0]);
      expect(resetRot.abs(), lessThan(0.05));
    });

    testWidgets('Route redirection preserves map rotation angle without resetting to 0', (tester) async {
      final mapKey = GlobalKey<InteractiveMarketMapState>();
      final transformController = TransformationController();
      NavigationRoute? activeRoute = sampleRouteA;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: SizedBox(
                  width: 400,
                  height: 800,
                  child: InteractiveMarketMap(
                    key: mapKey,
                    transformationController: transformController,
                    stalls: stalls,
                    activeRoute: activeRoute,
                  ),
                ),
                floatingActionButton: FloatingActionButton(
                  onPressed: () {
                    setState(() {
                      activeRoute = sampleRouteRedirected;
                    });
                  },
                  child: const Text('Redirect'),
                ),
              );
            },
          ),
        ),
      );

      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Rotate map by 45 degrees
      mapKey.currentState!.rotateBy(math.pi / 4, animate: false);
      for (int i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final rotBefore = math.atan2(transformController.value.storage[1], transformController.value.storage[0]);
      expect((rotBefore - math.pi / 4).abs(), lessThan(0.05));

      // Trigger Redirection
      await tester.tap(find.text('Redirect'));
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Rotation MUST still be preserved and NOT reset to 0
      final rotAfter = math.atan2(transformController.value.storage[1], transformController.value.storage[0]);
      expect((rotAfter - math.pi / 4).abs(), lessThan(0.05));
    });
  });
}
