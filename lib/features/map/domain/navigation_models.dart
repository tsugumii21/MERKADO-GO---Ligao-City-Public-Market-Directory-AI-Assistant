import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Single node in the pathway graph from `map_nodes.json`
class GraphNode {
  final String id;
  final double x;
  final double y;
  final List<String> neighbors;

  const GraphNode({
    required this.id,
    required this.x,
    required this.y,
    required this.neighbors,
  });

  Offset get offset => Offset(x, y);

  /// Calculate Euclidean distance to another node
  double distanceTo(GraphNode other) {
    final dx = other.x - x;
    final dy = other.y - y;
    return math.sqrt(dx * dx + dy * dy);
  }

  factory GraphNode.fromJson(String id, Map<String, dynamic> json) {
    final rawNeighbors = json['neighbors'] as List? ?? [];
    return GraphNode(
      id: id,
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      neighbors: rawNeighbors
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(),
    );
  }

  @override
  String toString() => 'GraphNode($id, x: $x, y: $y, neighbors: ${neighbors.length})';
}

/// Physical entrance point from `market_entry_points.json`
class MarketEntryPoint {
  final int entranceId;
  final String nodeId;
  final String description;

  const MarketEntryPoint({
    required this.entranceId,
    required this.nodeId,
    required this.description,
  });

  factory MarketEntryPoint.fromJson(Map<String, dynamic> json) {
    return MarketEntryPoint(
      entranceId: (json['entrance_id'] as num?)?.toInt() ?? 0,
      nodeId: (json['node_id'] as String? ?? '').trim(),
      description: (json['description'] as String? ?? '').trim(),
    );
  }

  @override
  String toString() => 'MarketEntryPoint(#$entranceId: $description -> $nodeId)';
}

/// Turn direction classification for navigation steps
enum TurnDirection {
  start,
  straight,
  slightLeft,
  turnLeft,
  sharpLeft,
  slightRight,
  turnRight,
  sharpRight,
  uTurn,
  arrive;

  IconData get icon {
    switch (this) {
      case TurnDirection.start:
        return Icons.login_rounded;
      case TurnDirection.straight:
        return Icons.straight_rounded;
      case TurnDirection.slightLeft:
        return Icons.turn_slight_left_rounded;
      case TurnDirection.turnLeft:
        return Icons.turn_left_rounded;
      case TurnDirection.sharpLeft:
        return Icons.turn_sharp_left_rounded;
      case TurnDirection.slightRight:
        return Icons.turn_slight_right_rounded;
      case TurnDirection.turnRight:
        return Icons.turn_right_rounded;
      case TurnDirection.sharpRight:
        return Icons.turn_sharp_right_rounded;
      case TurnDirection.uTurn:
        return Icons.u_turn_left_rounded;
      case TurnDirection.arrive:
        return Icons.location_on_rounded;
    }
  }

  String get label {
    switch (this) {
      case TurnDirection.start:
        return 'Start';
      case TurnDirection.straight:
        return 'Go straight';
      case TurnDirection.slightLeft:
        return 'Slight left';
      case TurnDirection.turnLeft:
        return 'Turn left';
      case TurnDirection.sharpLeft:
        return 'Sharp left';
      case TurnDirection.slightRight:
        return 'Slight right';
      case TurnDirection.turnRight:
        return 'Turn right';
      case TurnDirection.sharpRight:
        return 'Sharp right';
      case TurnDirection.uTurn:
        return 'Make a U-turn';
      case TurnDirection.arrive:
        return 'Arrive at destination';
    }
  }
}

/// Single turn-by-turn navigation instruction
class NavigationStep {
  final int stepNumber;
  final String instruction;
  final double distance;
  final TurnDirection direction;
  final String nodeId;
  final String? fromNodeId;
  final String? toNodeId;

  const NavigationStep({
    required this.stepNumber,
    required this.instruction,
    required this.distance,
    required this.direction,
    required this.nodeId,
    this.fromNodeId,
    this.toNodeId,
  });

  /// Approximate distance in meters for display (100 SVG canvas units â‰ˆ 2.5 meters)
  double get estimatedMeters => (distance * 0.025).clamp(1.0, 500.0);

  String get distanceFormatted {
    final meters = estimatedMeters;
    if (meters < 1.5) return '';
    return '${meters.toStringAsFixed(0)} m';
  }

  @override
  String toString() => 'Step $stepNumber: $instruction ($distanceFormatted)';
}

/// Resolved complete navigation route from entrance to destination stall
class NavigationRoute {
  final List<String> nodeIds;
  final List<GraphNode> nodes;
  final List<Offset> points;
  final List<NavigationStep> steps;
  final double totalDistance;
  final MarketEntryPoint entrance;
  final String destinationStallId;
  final String destinationStallName;

  const NavigationRoute({
    required this.nodeIds,
    required this.nodes,
    required this.points,
    required this.steps,
    required this.totalDistance,
    required this.entrance,
    required this.destinationStallId,
    required this.destinationStallName,
  });

  bool get isEmpty => nodeIds.isEmpty;
  bool get isNotEmpty => nodeIds.isNotEmpty;

  /// Approximate total distance in meters
  double get totalEstimatedMeters => (totalDistance * 0.025).clamp(1.0, 1000.0);

  /// Approximate walking time in seconds (average walking speed ~ 1.2 m/s)
  int get estimatedWalkingSeconds => (totalEstimatedMeters / 1.2).ceil();

  String get estimatedWalkingTimeFormatted {
    final minutes = (estimatedWalkingSeconds / 60).ceil();
    if (minutes <= 1) return '< 1 min walk';
    return '$minutes min walk';
  }
}
