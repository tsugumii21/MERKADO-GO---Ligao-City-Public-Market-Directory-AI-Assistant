// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:merkado_go/features/map/services/pathfinding_service.dart';

void main() {
  test('Investigate routes for case 1 and case 2', () {
    final nodesStr = File('assets/map/map_nodes.json').readAsStringSync();
    final entriesStr = File('assets/map/market_entry_points.json').readAsStringSync();
    final stallNodesStr = File('assets/map/stall_nodes.json').readAsStringSync();

    final svc = PathfindingService();
    svc.initializeWithRawData(
      mapNodesJson: jsonDecode(nodesStr),
      entryPointsJson: jsonDecode(entriesStr),
      stallNodesJson: jsonDecode(stallNodesStr),
    );

    print('=== ROUTE 1: id_261 (Yhesha) -> id_157 (Marixon) ===');
    final r1 = svc.findStallToStallRoute(
      originStallId: 'id_261',
      destinationStallId: 'id_157',
      originName: "Yhesha's Sari-Sari Store",
      destinationName: 'Marixon Fruits and Vegetables Store',
    );
    if (r1 != null) {
      print('Total Distance: ${r1.totalDistance}');
      print('Nodes: ${r1.nodeIds.join(" -> ")}');
      for (final s in r1.steps) {
        print('  Step: ${s.instruction} (${s.distance.round()}px, ${s.direction})');
      }
    } else {
      print('Route 1 null!');
    }

    print('\n=== ROUTE 2: id_143 (M. Bello) -> id_108 (Jo Patingo I) ===');
    final r2 = svc.findStallToStallRoute(
      originStallId: 'id_143',
      destinationStallId: 'id_108',
      originName: 'M. Bello Dried Fish Store',
      destinationName: 'Jo Patingo Sari-Sari Store I',
    );
    if (r2 != null) {
      print('Total Distance: ${r2.totalDistance}');
      print('Nodes: ${r2.nodeIds.join(" -> ")}');
      for (final s in r2.steps) {
        print('  Step: ${s.instruction} (${s.distance.round()}px, ${s.direction})');
      }
    } else {
      print('Route 2 null!');
    }
  });
}
