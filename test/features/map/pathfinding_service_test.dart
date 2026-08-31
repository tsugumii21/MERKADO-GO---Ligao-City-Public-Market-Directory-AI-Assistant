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

    test('Real graph has 116 nodes and 14 entry points', () {
      expect(service.nodes.length, 116);
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
  });
}
