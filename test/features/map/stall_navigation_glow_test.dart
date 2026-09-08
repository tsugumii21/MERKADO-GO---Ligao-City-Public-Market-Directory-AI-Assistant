import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merkado_go/features/map/domain/navigation_models.dart';
import 'package:merkado_go/features/map/presentation/widgets/interactive_market_map.dart';
import 'package:merkado_go/models/stall_model.dart';

void main() {
  group('Navigation Stall Glow and Line Anchoring Tests', () {
    const node1 = GraphNode(id: 'node_ex_n2', x: 200.0, y: 300.0, neighbors: ['node_ex_n3']);
    const node2 = GraphNode(id: 'node_ex_n3', x: 250.0, y: 300.0, neighbors: ['node_ex_n2']);

    final sampleRoute = NavigationRoute(
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

    test('RouteOverlayPainter accepts originStallCenter and destinationStallCenter', () {
      const originCenter = Offset(190.0, 310.0);
      const destCenter = Offset(260.0, 310.0);

      final painter = RouteOverlayPainter(
        route: sampleRoute,
        nodeOffsetX: 0.0,
        nodeOffsetY: 0.0,
        pulseScale: 1.0,
        originStallCenter: originCenter,
        destinationStallCenter: destCenter,
        walkProgress: 0.0,
        isWalking: true,
      );

      expect(painter.originStallCenter, equals(originCenter));
      expect(painter.destinationStallCenter, equals(destCenter));

      // Test repaint detection on originStallCenter change
      final differentPainter = RouteOverlayPainter(
        route: sampleRoute,
        nodeOffsetX: 0.0,
        nodeOffsetY: 0.0,
        pulseScale: 1.0,
        originStallCenter: const Offset(100.0, 100.0),
        destinationStallCenter: destCenter,
      );
      expect(painter.shouldRepaint(differentPainter), isTrue);
    });

    testWidgets('InteractiveMarketMap renders without errors with active stall route', (tester) async {
      final now = DateTime.now();
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
          updatedAt: now,
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
          updatedAt: now,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 800,
              child: InteractiveMarketMap(
                stalls: stalls,
                activeRoute: sampleRoute,
              ),
            ),
          ),
        ),
      );

      // Pump several frames for SVG load and layout
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(InteractiveMarketMap), findsOneWidget);
    });
  });
}
