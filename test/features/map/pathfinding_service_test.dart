import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:merkado_go/features/map/domain/navigation_models.dart';
import 'package:merkado_go/features/map/services/pathfinding_service.dart';

void main() {
  group('PathfindingService Unit Tests', () {
    late PathfindingService service;

    setUp(() {
      service = PathfindingService();
    });

    test('GraphNode correctly parses and calculates Euclidean distance', () {
      final nodeA = GraphNode.fromJson('node_a', {
        'x': 0.0,
        'y': 0.0,
        'neighbors': ['node_b'],
      });

      final nodeB = GraphNode.fromJson('node_b', {
        'x': 30.0,
        'y': 40.0,
        'neighbors': ['node_a'],
      });

      expect(nodeA.id, 'node_a');
      expect(nodeA.x, 0.0);
      expect(nodeA.y, 0.0);
      expect(nodeA.neighbors, ['node_b']);
      expect(nodeA.distanceTo(nodeB), 50.0); // 3-4-5 triangle: sqrt(900 + 1600) = 50
    });

    test('Initializes with raw in-memory JSON data correctly', () {
      final sampleNodes = {
        'node_1': {
          'x': 0.0,
          'y': 0.0,
          'neighbors': ['node_2'],
        },
        'node_2': {
          'x': 100.0,
          'y': 0.0,
          'neighbors': ['node_1', 'node_3'],
        },
        'node_3': {
          'x': 100.0,
          'y': 100.0,
          'neighbors': ['node_2'],
        },
      };

      final sampleEntrances = [
        {
          'entrance_id': 1,
          'node_id': 'node_1',
          'description': 'Main Gate',
        },
      ];

      final sampleStallNodes = {
        'id_single': 'node_3',
        'id_multi': ['node_2', 'node_3', 'node_2'], // Multi with duplicate
      };

      service.initializeWithRawData(
        mapNodesJson: sampleNodes,
        entryPointsJson: sampleEntrances,
        stallNodesJson: sampleStallNodes,
      );

      expect(service.isInitialized, true);
      expect(service.nodes.length, 3);
      expect(service.entryPoints.length, 1);
      expect(service.entryPoints.first.description, 'Main Gate');

      // Test Index-0 snapping rule
      expect(service.getPrimaryNodeForStall('id_single'), 'node_3');
      expect(service.getPrimaryNodeForStall('id_multi'), 'node_2');
      // Test deduplication
      expect(service.getCandidateNodesForStall('id_multi'), ['node_2', 'node_3']);
    });

    test('A* pathfinding computes the optimal route correctly', () {
      // Create a grid graph:
      // node_start (0,0) ---- node_mid (100,0) ---- node_goal (200,0) [Shortest direct line: 200]
      //      |                                            |
      // node_detour (0,150) --------------------- node_detour2 (200,150) [Longer path: 0->150->350->200 = 500]
      final nodes = {
        'start': {
          'x': 0.0,
          'y': 0.0,
          'neighbors': ['mid', 'detour'],
        },
        'mid': {
          'x': 100.0,
          'y': 0.0,
          'neighbors': ['start', 'goal'],
        },
        'goal': {
          'x': 200.0,
          'y': 0.0,
          'neighbors': ['mid', 'detour2'],
        },
        'detour': {
          'x': 0.0,
          'y': 150.0,
          'neighbors': ['start', 'detour2'],
        },
        'detour2': {
          'x': 200.0,
          'y': 150.0,
          'neighbors': ['detour', 'goal'],
        },
      };

      service.initializeWithRawData(
        mapNodesJson: nodes,
        entryPointsJson: [
          {'entrance_id': 1, 'node_id': 'start', 'description': 'Gate 1'}
        ],
        stallNodesJson: {'id_target': 'goal'},
      );

      final path = service.aStarPath(startNodeId: 'start', goalNodeId: 'goal');
      expect(path, ['start', 'mid', 'goal']);
    });

    test('A* pathfinding returns single element when start equals goal', () {
      final nodes = {
        'start': {
          'x': 0.0,
          'y': 0.0,
          'neighbors': [],
        },
      };

      service.initializeWithRawData(
        mapNodesJson: nodes,
        entryPointsJson: [],
        stallNodesJson: {},
      );

      final path = service.aStarPath(startNodeId: 'start', goalNodeId: 'start');
      expect(path, ['start']);
    });

    test('A* returns empty list when no path exists between disconnected components', () {
      final nodes = {
        'node_a': {
          'x': 0.0,
          'y': 0.0,
          'neighbors': [],
        },
        'node_b': {
          'x': 100.0,
          'y': 100.0,
          'neighbors': [],
        },
      };

      service.initializeWithRawData(
        mapNodesJson: nodes,
        entryPointsJson: [],
        stallNodesJson: {},
      );

      final path = service.aStarPath(startNodeId: 'node_a', goalNodeId: 'node_b');
      expect(path, isEmpty);
    });

    test('Generates structured turn-by-turn navigation instructions', () {
      // Path that turns right at (100, 0)
      final nodes = {
        'n1': {'x': 0.0, 'y': 0.0, 'neighbors': ['n2']},
        'n2': {'x': 100.0, 'y': 0.0, 'neighbors': ['n1', 'n3']},
        'n3': {'x': 100.0, 'y': 100.0, 'neighbors': ['n2']},
      };

      service.initializeWithRawData(
        mapNodesJson: nodes,
        entryPointsJson: [
          {'entrance_id': 1, 'node_id': 'n1', 'description': 'Main Entrance'}
        ],
        stallNodesJson: {'id_dest': 'n3'},
      );

      final route = service.findRoute(
        entranceNodeId: 'n1',
        destinationStallId: 'id_dest',
        destinationName: 'Fresh Pork Corner',
      );

      expect(route, isNotNull);
      expect(route!.nodeIds, ['n1', 'n2', 'n3']);
      expect(route.points.length, 3);
      expect(route.steps.length, 3);

      // Step 1: Start
      expect(route.steps[0].direction, TurnDirection.start);
      expect(route.steps[0].instruction, contains('Main Entrance'));

      // Step 2: Turn Right
      expect(route.steps[1].direction, TurnDirection.turnRight);

      // Step 3: Arrive
      expect(route.steps[2].direction, TurnDirection.arrive);
      expect(route.steps[2].instruction, contains('Fresh Pork Corner'));
    });
  });

  group('Real Bundled Assets Routing Tests', () {
    late PathfindingService service;

    setUp(() {
      service = PathfindingService();

      // Load actual JSON files directly from assets folder on disk for unit test
      final mapNodesFile = File('assets/map/map_nodes.json');
      final entryPointsFile = File('assets/map/market_entry_points.json');
      final stallNodesFile = File('assets/map/stall_nodes.json');

      final mapNodesJson = jsonDecode(mapNodesFile.readAsStringSync()) as Map<String, dynamic>;
      final entryPointsJson = jsonDecode(entryPointsFile.readAsStringSync()) as List<dynamic>;
      final stallNodesJson = jsonDecode(stallNodesFile.readAsStringSync()) as Map<String, dynamic>;

      service.initializeWithRawData(
        mapNodesJson: mapNodesJson,
        entryPointsJson: entryPointsJson,
        stallNodesJson: stallNodesJson,
      );
    });

    test('Real graph has 143 nodes and 14 entry points', () {
      expect(service.nodes.length, 143);
      expect(service.entryPoints.length, 14);
      expect(service.stallToNodes.length, 231); // 134 assigned + 97 vacant slots
    });

    test('Computes route from Entrance #1 to sample stall id_1', () {
      final entrance = service.entryPoints.first; // Entrance #1 (node_ex_1)
      expect(entrance.nodeId, 'node_ex_1');

      final route = service.findRoute(
        entranceNodeId: entrance.nodeId,
        destinationStallId: 'id_1',
        destinationName: "2 CEE'S STORE",
      );

      expect(route, isNotNull);
      expect(route!.isNotEmpty, true);
      expect(route.nodeIds.first, 'node_ex_1');
      expect(route.steps.isNotEmpty, true);
      expect(route.totalDistance, greaterThan(0));
    });

    test('Computes route across market from Entrance #7 (Rosco Building) to id_80 (Eateries)', () {
      final entrance = service.getEntryPointById(7); // Entrance #7 (node_ex_6)
      expect(entrance, isNotNull);

      final route = service.findRoute(
        entranceNodeId: entrance!.nodeId,
        destinationStallId: 'id_80',
        destinationName: 'FRANCISCO CARINDERIA I',
      );

      expect(route, isNotNull);
      expect(route!.nodeIds.first, 'node_ex_6');
      expect(route.steps.last.direction, TurnDirection.arrive);
    });

    test('Computes stall-to-stall route between two distinct stalls (id_1 to id_80)', () {
      final route = service.findStallToStallRoute(
        originStallId: 'id_1',
        destinationStallId: 'id_80',
        originName: "2 CEE'S STORE",
        destinationName: 'FRANCISCO CARINDERIA I',
      );

      expect(route, isNotNull);
      expect(route!.isNotEmpty, true);
      expect(route.originType, NavigationOriginType.stall);
      expect(route.entrance, isNull);
      expect(route.originStallId, 'id_1');
      expect(route.destinationStallId, 'id_80');
      expect(route.totalDistance, greaterThan(0));

      // Steps verification
      expect(route.steps.first.direction, TurnDirection.start);
      expect(route.steps.first.instruction, contains("2 CEE'S STORE"));
      expect(route.steps.last.direction, TurnDirection.arrive);
      expect(route.steps.last.instruction, contains('FRANCISCO CARINDERIA I'));
    });

    test('Computes stall-to-stall route when origin equals destination', () {
      final route = service.findStallToStallRoute(
        originStallId: 'id_1',
        destinationStallId: 'id_1',
        originName: "2 CEE'S STORE",
        destinationName: "2 CEE'S STORE",
      );

      expect(route, isNotNull);
      expect(route!.originType, NavigationOriginType.stall);
      expect(route.entrance, isNull);
      expect(route.totalDistance, 0.0);
      expect(route.steps.length, 1);
      expect(route.steps.first.direction, TurnDirection.arrive);
      expect(route.steps.first.instruction, contains("already at 2 CEE'S STORE"));
    });

    test('Redirection preserves previous origin stall (Stall A -> B redirected to Stall A -> C)', () {
      // 1. Initial route: Stall A (id_1) to Stall B (id_80)
      final initialRoute = service.findStallToStallRoute(
        originStallId: 'id_1',
        destinationStallId: 'id_80',
        originName: "2 CEE'S STORE",
        destinationName: 'FRANCISCO CARINDERIA I',
      );
      expect(initialRoute, isNotNull);
      expect(initialRoute!.originStallId, 'id_1');
      expect(initialRoute.destinationStallId, 'id_80');

      // 2. Redirection: Keep origin A (id_1) from previous route, change to destination C (id_81)
      final redirectedRoute = service.findStallToStallRoute(
        originStallId: initialRoute.originStallId!,
        destinationStallId: 'id_81',
        originName: initialRoute.originStallName,
        destinationName: 'FRANCISCO CARINDERIA II',
      );

      expect(redirectedRoute, isNotNull);
      expect(redirectedRoute!.originStallId, 'id_1');
      expect(redirectedRoute.originStallName, "2 CEE'S STORE");
      expect(redirectedRoute.destinationStallId, 'id_81');
      expect(redirectedRoute.destinationStallName, 'FRANCISCO CARINDERIA II');
      expect(redirectedRoute.steps.first.instruction, contains("2 CEE'S STORE"));
      expect(redirectedRoute.steps.last.instruction, contains('FRANCISCO CARINDERIA II'));
    });

    test('Zone-aware: Outdoor stall to outdoor stall stays on the street without entering buildings', () {
      // id_202 to id_126: Both in Extension V on North Street
      final route = service.findStallToStallRoute(
        originStallId: 'id_202',
        destinationStallId: 'id_126',
        originName: 'R. LLOBIT RICE GRINDING SERVICES',
        destinationName: 'LEANNE AND MARIA SARI SARI STORE',
      );

      expect(route, isNotNull);
      expect(route!.nodeIds, isNotEmpty);
      // All nodes in this outdoor route must be street nodes ('node_ex_*')
      for (final nodeId in route.nodeIds) {
        expect(
          PathfindingService.getNodeZone(nodeId),
          'ex',
          reason: 'Node $nodeId should be on outdoor street network (ex), not inside building',
        );
      }
      expect(route.nodeIds.first, 'node_ex_n4');
      expect(route.nodeIds.last, 'node_ex_n1');
    });

    test('Zone-aware: Gate to indoor Meat Section stall stays on street then enters building doorway', () {
      // Gate 1 (node_ex_1) to id_3 (Meat Section)
      final route = service.findRoute(
        entranceNodeId: 'node_ex_1',
        destinationStallId: 'id_3',
        destinationName: "4E'S LLOBET MEATSHOP CORPORATION",
      );

      expect(route, isNotNull);
      expect(route!.nodeIds, isNotEmpty);
      expect(route.nodeIds.first, 'node_ex_1');
      expect(PathfindingService.getNodeZone(route.nodeIds.first), 'ex');
      expect(PathfindingService.getNodeZone(route.nodeIds.last), 'wm');

      // The path must only consist of outdoor street ('ex') and target building ('wm')
      for (final nodeId in route.nodeIds) {
        final zone = PathfindingService.getNodeZone(nodeId);
        expect(
          zone == 'ex' || zone == 'wm',
          isTrue,
          reason: 'Node $nodeId should be in ex or wm zone, not cutting through other buildings',
        );
      }
    });

    test('Zone-aware: Indoor to indoor stall in same building stays inside building corridors', () {
      // id_3 (Meat Section) to id_10 (Fish Section) - both in Wet Market (wm)
      final route = service.findStallToStallRoute(
        originStallId: 'id_3',
        destinationStallId: 'id_10',
        originName: "4E'S LLOBET MEATSHOP CORPORATION",
        destinationName: 'ADVZ FISH RETAILING',
      );

      expect(route, isNotNull);
      expect(route!.nodeIds, isNotEmpty);
      for (final nodeId in route.nodeIds) {
        expect(
          PathfindingService.getNodeZone(nodeId),
          'wm',
          reason: 'Node $nodeId should remain within the Wet Market interior corridors',
        );
      }
    });

    test('Zone-aware: Traverses Fruit Section open thoroughfare instead of long outer perimeter detour', () {
      // id_23 (Extension V, North Street) to id_9 (New Camarin, Barlin Street)
      final route = service.findStallToStallRoute(
        originStallId: 'id_23',
        destinationStallId: 'id_9',
        originName: 'ARLES ARMARIO STORE',
        destinationName: 'ADELFA F. ADONES JEWELRY AND WATCH REPAIR SHOP I',
      );

      expect(route, isNotNull);
      expect(route!.nodeIds, isNotEmpty);

      // Verify route uses Fruit Section avenue
      final hasFruitSectionNodes = route.nodeIds.any((n) => n.startsWith('node_fs'));
      expect(hasFruitSectionNodes, isTrue, reason: 'Route should take direct Fruit Section avenue');

      // Distance must be direct (~2,000 px), not the outer detour (~4,880 px)
      expect(route.totalDistance, lessThan(2500.0));
    });

    test('Zone-aware: Outdoor stall to perimeter stall stays on street without cutting through Wet Market / Fish Section', () {
      // id_23 (North Street) to id_189 (Building I, South Street perimeter)
      final route = service.findStallToStallRoute(
        originStallId: 'id_23',
        destinationStallId: 'id_189',
        originName: 'ARLES ARMARIO STORE',
        destinationName: 'PAYOYO-LOPEZ STORE',
      );

      expect(route, isNotNull);
      expect(route!.nodeIds, isNotEmpty);

      // Must remain 100% on exterior streets without entering Wet Market / Fish Section stalls
      final hasWetMarketNodes = route.nodeIds.any((n) => n.startsWith('node_wm'));
      expect(hasWetMarketNodes, isFalse, reason: 'Route should stay on street, not cut through wet market');

      for (final nodeId in route.nodeIds) {
        expect(PathfindingService.getNodeZone(nodeId), 'ex');
      }
    });

    test('Zone-aware: Outdoor stall to indoor Fish Section stall stays on street until closest entrance doorway', () {
      // id_23 (North Street) to id_10 (ADVZ FISH RETAILING inside Fish Section)
      final route = service.findStallToStallRoute(
        originStallId: 'id_23',
        destinationStallId: 'id_10',
        originName: 'ARLES ARMARIO STORE',
        destinationName: 'ADVZ FISH RETAILING',
      );

      expect(route, isNotNull);
      expect(route!.nodeIds, isNotEmpty);
      expect(route.nodeIds.first, 'node_ex_n2');
      expect(PathfindingService.getNodeZone(route.nodeIds.first), 'ex');
      expect(PathfindingService.getNodeZone(route.nodeIds.last), 'wm');

      // Verify that it stays on the street for the majority of the path,
      // and enters through the doorway closest to the stall rather than cutting through counters.
      final streetPortion = route.nodeIds.takeWhile((n) => PathfindingService.isOpenThoroughfare(n)).toList();
      expect(streetPortion.length, greaterThanOrEqualTo(5), reason: 'Must stay on street until doorway');
    });

    test('Zone-aware: Route from Rice Section to Rosco Building stays strictly on Mercado Street without cutting through stalls or blank stalls', () {
      // id_154 (MARILOU M GUANZON STORE, Rice Section) to id_248 (TOY AND ME STORE I, Rosco Building)
      final route = service.findStallToStallRoute(
        originStallId: 'id_154',
        destinationStallId: 'id_248',
        originName: 'MARILOU M GUANZON STORE',
        destinationName: 'TOY AND ME STORE I',
      );

      expect(route, isNotNull);
      expect(route!.nodeIds, isNotEmpty);

      // Must terminate at node_ex_w2 (Mercado Street directly facing id_248)
      expect(route.nodeIds.last, 'node_ex_w2');

      // Must stay 100% on exterior streets / Mercado Street
      for (final nodeId in route.nodeIds) {
        expect(PathfindingService.getNodeZone(nodeId), 'ex');
      }

      // Must not use rogue node or cut through Rosco building
      expect(route.nodeIds.contains('node_ex_5'), isFalse);
      expect(route.nodeIds.contains('node_ex_w4'), isFalse);

      // Expected clean path along the street: node_ex_t16 -> node_ex_t17 -> node_ex_t18 -> node_ex_w3 -> node_ex_w2
      expect(route.nodeIds, ['node_ex_t16', 'node_ex_t17', 'node_ex_t18', 'node_ex_w3', 'node_ex_w2']);
    });

    test('Zone-aware: Marilyn Loria Store to Kyla and Kyle General uses internal Wet Market walkway', () {
      final route = service.findStallToStallRoute(
        originStallId: 'id_155',
        destinationStallId: 'id_119',
        originName: 'MARILYN LORIA STORE',
        destinationName: 'KYLA AND KYLE GENERAL MERCHANDISE',
      );

      expect(route, isNotNull);
      expect(route!.nodeIds, isNotEmpty);

      // Must traverse Wet Market internal corridor (node_wm_*)
      final hasWetMarketNodes = route.nodeIds.any((n) => n.startsWith('node_wm'));
      expect(hasWetMarketNodes, isTrue, reason: 'Route should cut through Wet Market walkway');

      // Must be direct internal route (~3,300 px), not outer perimeter detour (>10,000 px)
      expect(route.totalDistance, lessThan(3600.0));
    });

    test('Zone-aware: Marilyn Loria Store to Malou and Princess Store uses internal Wet Market walkway', () {
      final route = service.findStallToStallRoute(
        originStallId: 'id_155',
        destinationStallId: 'id_146',
        originName: 'MARILYN LORIA STORE',
        destinationName: 'MALOU AND PRINCESS STORE',
      );

      expect(route, isNotNull);
      expect(route!.nodeIds, isNotEmpty);

      // Must be direct internal route (~1,925 px), not outer perimeter detour (>11,000 px)
      expect(route.totalDistance, lessThan(2500.0));
    });

    test('Zone-aware: Yhesha Sari-Sari Store to Marixon Fruits and Vegetables uses internal wet market corridor', () {
      // id_261 (YHESHA'S SARI-SARI STORE) to id_157 (MARIXON FRUITS AND VEGETABLES STORE)
      final route = service.findStallToStallRoute(
        originStallId: 'id_261',
        destinationStallId: 'id_157',
        originName: "YHESHA'S SARI-SARI STORE",
        destinationName: 'MARIXON FRUITS AND VEGETABLES STORE',
      );

      expect(route, isNotNull);
      expect(route!.nodeIds, isNotEmpty);

      // Must follow the straight wet market aisle beside Meat Section
      expect(route.nodeIds, [
        'node_wm_x3',
        'node_wm_t18',
        'node_wm_x15',
        'node_wm_t19',
        'node_wm_x28',
        'node_wm_x36',
        'node_wm_x37',
        'node_wm_x39',
        'node_ex_x1',
        'node_ex_n3',
      ]);

      // Must not take western perimeter detour (node_ex_t9..node_ex_t13)
      expect(route.nodeIds.contains('node_ex_t9'), isFalse);
      expect(route.nodeIds.contains('node_ex_t10'), isFalse);
      expect(route.nodeIds.contains('node_ex_t11'), isFalse);
      expect(route.nodeIds.contains('node_ex_t12'), isFalse);
      expect(route.nodeIds.contains('node_ex_t13'), isFalse);

      // Distance should be ~1050 px, far shorter than western perimeter detour (>2000 px)
      expect(route.totalDistance, lessThan(1200.0));
    });

    test('Zone-aware: M. Bello Dried Fish Store to Jo Patingo Sari-Sari Store routes through aisle walkways without penetrating empty stalls', () {
      // id_143 (M. BELLO DRIED FISH STORE) to id_108 (JO PATINGO SARI-SARI STORE I)
      final route = service.findStallToStallRoute(
        originStallId: 'id_143',
        destinationStallId: 'id_108',
        originName: 'M. BELLO DRIED FISH STORE',
        destinationName: 'JO PATINGO SARI-SARI STORE I',
      );

      expect(route, isNotNull);
      expect(route!.nodeIds, isNotEmpty);

      // Must exit to North Street and enter South walkway via node_ex_t23 -> node_wm_t26
      expect(route.nodeIds, ['node_ex_n5', 'node_ex_t23', 'node_wm_t26']);

      // Destination node must be on the south aisle (node_wm_t26), not across the building on North Street (node_ex_n5)
      expect(route.nodeIds.last, 'node_wm_t26');
      expect(route.nodeIds.length, greaterThan(1));
    });

    test('Zone-aware: Route from north stall to RED ROS STORE uses direct interior Wet Market central corridor instead of perimeter detour', () {
      // id_157 (test stall 01 / Marixon Fruits and Vegetables) to id_208 (RED ROS STORE)
      final route = service.findStallToStallRoute(
        originStallId: 'id_157',
        destinationStallId: 'id_208',
        originName: 'test stall 01',
        destinationName: 'RED ROS STORE',
      );

      expect(route, isNotNull);
      expect(route!.nodeIds, isNotEmpty);

      // Must traverse through the central Wet Market corridor
      expect(route.nodeIds.first, 'node_ex_n3');
      expect(route.nodeIds.last, 'node_wm_x1');
      expect(route.nodeIds.contains('node_ex_x1'), isTrue);
      expect(route.nodeIds.contains('node_wm_x39'), isTrue);
      expect(route.nodeIds.contains('node_wm_x3'), isTrue);

      // Must not take western perimeter detour (node_ex_t7..node_ex_t13)
      expect(route.nodeIds.contains('node_ex_t9'), isFalse);
      expect(route.nodeIds.contains('node_ex_t10'), isFalse);
      expect(route.nodeIds.contains('node_ex_t11'), isFalse);
      expect(route.nodeIds.contains('node_ex_t12'), isFalse);
      expect(route.nodeIds.contains('node_ex_t13'), isFalse);

      // Direct corridor distance is ~1,148 px, far shorter than perimeter detour (>2,600 px)
      expect(route.totalDistance, lessThan(1200.0));
    });
  });
}

