import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import '../domain/navigation_models.dart';

/// A* Pathfinding and Navigation Service for Ligao City Public Market
class PathfindingService {
  final Map<String, GraphNode> _nodes = {};
  final List<MarketEntryPoint> _entryPoints = [];
  final Map<String, List<String>> _stallToNodes = {};
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  List<MarketEntryPoint> get entryPoints => List.unmodifiable(_entryPoints);
  Map<String, GraphNode> get nodes => Map.unmodifiable(_nodes);
  Map<String, List<String>> get stallToNodes => Map.unmodifiable(_stallToNodes);

  /// Load graph data from bundled assets in `assets/map/`
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final mapNodesStr = await rootBundle.loadString('assets/map/map_nodes.json');
      final entryPointsStr = await rootBundle.loadString('assets/map/market_entry_points.json');
      final stallNodesStr = await rootBundle.loadString('assets/map/stall_nodes.json');

      final mapNodesJson = jsonDecode(mapNodesStr) as Map<String, dynamic>;
      final entryPointsJson = jsonDecode(entryPointsStr) as List<dynamic>;
      final stallNodesJson = jsonDecode(stallNodesStr) as Map<String, dynamic>;

      initializeWithRawData(
        mapNodesJson: mapNodesJson,
        entryPointsJson: entryPointsJson,
        stallNodesJson: stallNodesJson,
      );
    } catch (e) {
      throw Exception('Failed to initialize PathfindingService: $e');
    }
  }

  /// Initialize with in-memory decoded JSON (enables fast unit testing without rootBundle)
  void initializeWithRawData({
    required Map<String, dynamic> mapNodesJson,
    required List<dynamic> entryPointsJson,
    required Map<String, dynamic> stallNodesJson,
  }) {
    _nodes.clear();
    _entryPoints.clear();
    _stallToNodes.clear();

    // 1. Parse graph nodes
    for (final entry in mapNodesJson.entries) {
      final nodeData = entry.value as Map<String, dynamic>;
      final node = GraphNode.fromJson(entry.key, nodeData);
      _nodes[entry.key] = node;
    }

    // Validate graph symmetry (bidirectional verification)
    _validateGraphSymmetry();

    // 2. Parse 14 entry points
    for (final item in entryPointsJson) {
      final entryMap = item as Map<String, dynamic>;
      final entryPoint = MarketEntryPoint.fromJson(entryMap);
      _entryPoints.add(entryPoint);
    }

    // 3. Parse stall-to-node mappings (handles polymorphic String or List<String>)
    for (final entry in stallNodesJson.entries) {
      final stallId = entry.key;
      final rawValue = entry.value;

      if (rawValue is String) {
        _stallToNodes[stallId] = [rawValue.trim()];
      } else if (rawValue is List) {
        final candidateNodes = rawValue
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toSet() // Deduplicate anomalies like duplicate node_ex_6 in id_39
            .toList();
        _stallToNodes[stallId] = candidateNodes;
      }
    }

    _isInitialized = true;
  }

  /// Check graph bidirectional symmetry and log warnings
  void _validateGraphSymmetry() {
    for (final node in _nodes.values) {
      for (final neighborId in node.neighbors) {
        final neighbor = _nodes[neighborId];
        if (neighbor == null) {
          // Dangling reference
          continue;
        }
        if (!neighbor.neighbors.contains(node.id)) {
          // Asymmetric edge detected: log for data integrity
          // print('Graph warning: Asymmetric edge between ${node.id} and $neighborId');
        }
      }
    }
  }

  /// Get primary nearest snap node for a stall (Index 0 rule)
  String? getPrimaryNodeForStall(String stallId) {
    final candidateNodes = _stallToNodes[stallId];
    if (candidateNodes == null || candidateNodes.isEmpty) return null;
    return candidateNodes.first;
  }

  /// Get all candidate access nodes for a stall
  List<String> getCandidateNodesForStall(String stallId) {
    return _stallToNodes[stallId] ?? const [];
  }

  /// Find market entry point by ID
  MarketEntryPoint? getEntryPointById(int entranceId) {
    try {
      return _entryPoints.firstWhere((e) => e.entranceId == entranceId);
    } catch (_) {
      return null;
    }
  }

  /// Find market entry point by its graph node ID
  MarketEntryPoint? getEntryPointByNodeId(String nodeId) {
    try {
      return _entryPoints.firstWhere((e) => e.nodeId == nodeId);
    } catch (_) {
      return null;
    }
  }

  /// Find the complete navigation route from entrance to destination stall
  NavigationRoute? findRoute({
    required String entranceNodeId,
    required String destinationStallId,
    String? destinationName,
  }) {
    if (!_isInitialized) {
      throw StateError('PathfindingService must be initialized before finding routes.');
    }

    final entrance = getEntryPointByNodeId(entranceNodeId) ??
        MarketEntryPoint(
          entranceId: 0,
          nodeId: entranceNodeId,
          description: 'Selected Entrance',
        );

    final candidateNodes = getCandidateNodesForStall(destinationStallId);
    if (candidateNodes.isEmpty) return null;

    // Evaluate all candidate access nodes for multi-entrance/corner stalls
    // and select the optimal valid path with lowest true walking distance from the entrance gate.
    List<String> pathNodeIds = const [];
    double bestDistance = double.infinity;

    for (final candidateId in candidateNodes) {
      if (!_nodes.containsKey(candidateId)) continue;
      final path = aStarPath(
        startNodeId: entranceNodeId,
        goalNodeId: candidateId,
      );
      if (path.isNotEmpty) {
        double dist = 0.0;
        for (int i = 0; i < path.length - 1; i++) {
          dist += _nodes[path[i]]!.distanceTo(_nodes[path[i + 1]]!);
        }
        if (dist < bestDistance) {
          bestDistance = dist;
          pathNodeIds = path;
        }
      }
    }

    if (pathNodeIds.isEmpty) return null;

    final pathNodes = pathNodeIds.map((id) => _nodes[id]!).toList();
    final points = pathNodes.map((n) => n.offset).toList();

    // Calculate total Euclidean distance
    double totalDistance = 0.0;
    for (int i = 0; i < pathNodes.length - 1; i++) {
      totalDistance += pathNodes[i].distanceTo(pathNodes[i + 1]);
    }

    final stallName = destinationName ?? destinationStallId;

    final steps = generateTurnInstructions(
      pathNodeIds: pathNodeIds,
      entrance: entrance,
      destinationName: stallName,
    );

    return NavigationRoute(
      nodeIds: pathNodeIds,
      nodes: pathNodes,
      points: points,
      steps: steps,
      totalDistance: totalDistance,
      entrance: entrance,
      destinationStallId: destinationStallId,
      destinationStallName: stallName,
    );
  }

  /// Core A* Pathfinding Algorithm
  List<String> aStarPath({
    required String startNodeId,
    required String goalNodeId,
  }) {
    final startNode = _nodes[startNodeId];
    final goalNode = _nodes[goalNodeId];

    if (startNode == null || goalNode == null) {
      return const [];
    }

    if (startNodeId == goalNodeId) {
      return [startNodeId];
    }

    // gScore[nodeId] = cost of cheapest path from start to nodeId
    final Map<String, double> gScore = {startNodeId: 0.0};

    // fScore[nodeId] = gScore[nodeId] + heuristic(nodeId, goalNodeId)
    final Map<String, double> fScore = {startNodeId: startNode.distanceTo(goalNode)};

    // cameFrom[nodeId] = previous node on cheapest known path
    final Map<String, String> cameFrom = {};

    // Open set for nodes to evaluate
    final Set<String> openSet = {startNodeId};
    final Set<String> closedSet = {};

    while (openSet.isNotEmpty) {
      // Pick node in openSet with lowest fScore
      String currentId = openSet.first;
      double lowestF = fScore[currentId] ?? double.infinity;

      for (final nodeId in openSet) {
        final score = fScore[nodeId] ?? double.infinity;
        if (score < lowestF) {
          lowestF = score;
          currentId = nodeId;
        }
      }

      // Reached the destination goal!
      if (currentId == goalNodeId) {
        return _reconstructPath(cameFrom, currentId);
      }

      openSet.remove(currentId);
      closedSet.add(currentId);

      final currentNode = _nodes[currentId]!;

      for (final neighborId in currentNode.neighbors) {
        if (closedSet.contains(neighborId)) continue;

        final neighborNode = _nodes[neighborId];
        if (neighborNode == null) continue;

        final tentativeGScore = (gScore[currentId] ?? double.infinity) +
            currentNode.distanceTo(neighborNode);

        if (tentativeGScore < (gScore[neighborId] ?? double.infinity)) {
          cameFrom[neighborId] = currentId;
          gScore[neighborId] = tentativeGScore;
          fScore[neighborId] = tentativeGScore + neighborNode.distanceTo(goalNode);

          openSet.add(neighborId);
        }
      }
    }

    // No path found
    return const [];
  }

  /// Reconstruct ordered node path from cameFrom map
  List<String> _reconstructPath(Map<String, String> cameFrom, String current) {
    final path = <String>[current];
    var curr = current;
    while (cameFrom.containsKey(curr)) {
      curr = cameFrom[curr]!;
      path.add(curr);
    }
    return path.reversed.toList();
  }

  /// Pre-compute human-readable turn-by-turn navigation instructions (No live GPS)
  List<NavigationStep> generateTurnInstructions({
    required List<String> pathNodeIds,
    required MarketEntryPoint entrance,
    required String destinationName,
  }) {
    if (pathNodeIds.isEmpty) return const [];

    final steps = <NavigationStep>[];

    // Single-node path
    if (pathNodeIds.length == 1) {
      steps.add(NavigationStep(
        stepNumber: 1,
        instruction: 'You are already at $destinationName (Entrance: ${entrance.description})',
        distance: 0.0,
        direction: TurnDirection.arrive,
        nodeId: pathNodeIds.first,
      ));
      return steps;
    }

    final pathNodes = pathNodeIds.map((id) => _nodes[id]!).toList();

    // Step 1: Start at entrance
    final initialDist = pathNodes[0].distanceTo(pathNodes[1]);
    steps.add(NavigationStep(
      stepNumber: 1,
      instruction: 'Enter via ${entrance.description} and head into the aisle',
      distance: initialDist,
      direction: TurnDirection.start,
      nodeId: pathNodes[0].id,
      fromNodeId: pathNodes[0].id,
      toNodeId: pathNodes[1].id,
    ));

    // For triplets (A, B, C), calculate signed bearing delta at B
    double accumulatedStraightDist = 0.0;

    for (int i = 0; i < pathNodes.length - 2; i++) {
      final nodeA = pathNodes[i];
      final nodeB = pathNodes[i + 1];
      final nodeC = pathNodes[i + 2];

      final segDist = nodeB.distanceTo(nodeC);

      // Bearings in degrees
      final bearingAB = _calculateBearing(nodeA, nodeB);
      final bearingBC = _calculateBearing(nodeB, nodeC);

      final delta = _normalizeAngleDelta(bearingBC - bearingAB);
      final direction = _classifyTurnDirection(delta);

      if (direction == TurnDirection.straight) {
        accumulatedStraightDist += segDist;
      } else {
        // Flush accumulated straight distance if significant (> 50 units)
        if (accumulatedStraightDist > 50.0) {
          steps.add(NavigationStep(
            stepNumber: steps.length + 1,
            instruction: 'Continue straight along the corridor',
            distance: accumulatedStraightDist,
            direction: TurnDirection.straight,
            nodeId: nodeA.id,
          ));
        }
        accumulatedStraightDist = 0.0;

        final zoneName = _getZoneDescription(nodeB.id);
        final turnText = '${direction.label} at the intersection towards $zoneName';

        steps.add(NavigationStep(
          stepNumber: steps.length + 1,
          instruction: turnText,
          distance: segDist,
          direction: direction,
          nodeId: nodeB.id,
          fromNodeId: nodeA.id,
          toNodeId: nodeC.id,
        ));
      }
    }

    // Flush remaining straight distance before arrival
    if (accumulatedStraightDist > 50.0 && pathNodes.length >= 2) {
      steps.add(NavigationStep(
        stepNumber: steps.length + 1,
        instruction: 'Continue straight towards your destination',
        distance: accumulatedStraightDist,
        direction: TurnDirection.straight,
        nodeId: pathNodes[pathNodes.length - 2].id,
      ));
    }

    // Final Step: Arrive at destination
    final lastNode = pathNodes.last;
    steps.add(NavigationStep(
      stepNumber: steps.length + 1,
      instruction: 'Arrive at $destinationName on your pathway',
      distance: 0.0,
      direction: TurnDirection.arrive,
      nodeId: lastNode.id,
    ));

    return steps;
  }

  /// Calculate bearing angle in degrees from node A to node B
  double _calculateBearing(GraphNode a, GraphNode b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final rad = math.atan2(dy, dx);
    return rad * (180.0 / math.pi);
  }

  /// Normalize angle delta to [-180, 180]
  double _normalizeAngleDelta(double delta) {
    var d = delta;
    while (d > 180.0) {
      d -= 360.0;
    }
    while (d < -180.0) {
      d += 360.0;
    }
    return d;
  }

  /// Classify signed delta into discrete TurnDirection enum
  TurnDirection _classifyTurnDirection(double delta) {
    final absDelta = delta.abs();

    if (absDelta <= 18.0) {
      return TurnDirection.straight;
    }

    if (delta > 0) {
      // Right turns
      if (delta <= 45.0) return TurnDirection.slightRight;
      if (delta <= 135.0) return TurnDirection.turnRight;
      if (delta <= 165.0) return TurnDirection.sharpRight;
      return TurnDirection.uTurn;
    } else {
      // Left turns
      final negDelta = delta.abs();
      if (negDelta <= 45.0) return TurnDirection.slightLeft;
      if (negDelta <= 135.0) return TurnDirection.turnLeft;
      if (negDelta <= 165.0) return TurnDirection.sharpLeft;
      return TurnDirection.uTurn;
    }
  }

  /// Get zone description from node naming convention: node_[zone]_[type]
  String _getZoneDescription(String nodeId) {
    if (nodeId.startsWith('node_wm')) return 'Wet Market';
    if (nodeId.startsWith('node_ea')) return 'Eateries Section';
    if (nodeId.startsWith('node_dm')) return 'Dry Market';
    if (nodeId.startsWith('node_rs')) return 'Rice Section';
    if (nodeId.startsWith('node_fs')) return 'Fruits Section';
    if (nodeId.startsWith('node_ex')) return 'Main Corridor';
    return 'Market Walkway';
  }

  /// Calculate exact walking distance along aisles from entrance to stall
  double getPathWalkingCost({
    required String entranceNodeId,
    required String goalNodeId,
  }) {
    final pathNodeIds = aStarPath(
      startNodeId: entranceNodeId,
      goalNodeId: goalNodeId,
    );
    if (pathNodeIds.length < 2) return double.infinity;

    double cost = 0.0;
    for (int i = 0; i < pathNodeIds.length - 1; i++) {
      final nodeU = _nodes[pathNodeIds[i]];
      final nodeV = _nodes[pathNodeIds[i + 1]];
      if (nodeU != null && nodeV != null) {
        cost += nodeU.distanceTo(nodeV);
      }
    }
    return cost;
  }

  /// Find nearest entrance by true corridor walking distance
  MarketEntryPoint? findNearestEntranceByWalkingDistance(String destinationStallId) {
    final candidateNodes = getCandidateNodesForStall(destinationStallId);
    if (candidateNodes.isEmpty || _entryPoints.isEmpty) return null;

    MarketEntryPoint? nearest;
    double minCost = double.infinity;

    for (final entrance in _entryPoints) {
      for (final candidateId in candidateNodes) {
        final cost = getPathWalkingCost(
          entranceNodeId: entrance.nodeId,
          goalNodeId: candidateId,
        );
        if (cost < minCost) {
          minCost = cost;
          nearest = entrance;
        }
      }
    }

    return nearest;
  }
}
