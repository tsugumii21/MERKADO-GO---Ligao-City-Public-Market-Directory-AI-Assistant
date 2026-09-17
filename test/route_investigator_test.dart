// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:merkado_go/features/map/services/pathfinding_service.dart';
import 'package:merkado_go/features/map/services/stall_svg_parser.dart';

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

    print('\n=== INVESTIGATING id_157 -> id_208 ===');
    final rDirect = svc.findStallToStallRoute(
      originStallId: 'id_157',
      destinationStallId: 'id_208',
      originName: 'test stall 01',
      destinationName: 'RED ROS STORE',
    );
    print('rDirect: ${rDirect?.nodeIds.join(" -> ")} (dist: ${rDirect?.totalDistance})');
    expect(rDirect, isNotNull);
    expect(rDirect!.nodeIds.last, 'node_wm_x1');
    expect(rDirect.nodeIds.contains('node_wm_x39'), isTrue);
    expect(rDirect.totalDistance, lessThan(1200.0));

    final rReverse = svc.findStallToStallRoute(
      originStallId: 'id_208',
      destinationStallId: 'id_157',
      originName: 'RED ROS STORE',
      destinationName: 'test stall 01',
    );
    print('rReverse (id_208 -> id_157): ${rReverse?.nodeIds.join(" -> ")} (dist: ${rReverse?.totalDistance})');
    expect(rReverse, isNotNull);
    expect(rReverse!.nodeIds.first, 'node_wm_x1');
    expect(rReverse.totalDistance, lessThan(1200.0));

    print('\n=== INVESTIGATING id_23 -> id_189 ===');
    final r23_189 = svc.findStallToStallRoute(
      originStallId: 'id_23',
      destinationStallId: 'id_189',
      originName: 'ARLES ARMARIO STORE',
      destinationName: 'PAYOYO-LOPEZ STORE',
    );
    print('r23_189: ${r23_189?.nodeIds.join(" -> ")} (dist: ${r23_189?.totalDistance})');

    const nodeOffX = 7823.47;
    const nodeOffY = 3174.00;
    final svgStr = File('assets/map/LigaoCity_PublicMarket_Map.svg').readAsStringSync();
    final boundsMap = StallSvgParser.parseAllBounds(svgStr);
    final allMapNodes = (jsonDecode(nodesStr) as Map<String, dynamic>);
    final id208Bounds = boundsMap['id_208'];
    final id157Bounds = boundsMap['id_157'];

    print('\n=== SOUTH ROW STALLS INSPECTION ===');
    for (final stallId in ['id_92', 'id_93', 'id_101', 'id_102', 'id_105', 'id_208', 'id_252']) {
      final b = boundsMap[stallId];
      if (b == null) continue;
      print('$stallId: bounds=$b, center=${b.center}');
      for (final nId in ['node_wm_x1', 'node_wm_e2', 'node_ex_t2', 'node_wm_t1', 'node_wm_t3', 'node_ex_t1']) {
        final nodeData = allMapNodes[nId];
        if (nodeData == null) continue;
        final nx = nodeData['x'] + nodeOffX;
        final ny = nodeData['y'] + nodeOffY;
        final dist = (Offset(nx, ny) - b.center).distance;
        if (dist < 350) {
          print('   -> $nId: dist=${dist.toStringAsFixed(1)}');
        }
      }
    }
    for (final entry in allMapNodes.entries) {
      final nx = entry.value['x'] + nodeOffX;
      final ny = entry.value['y'] + nodeOffY;
      final nodeOffset = Offset(nx, ny);
      final dist208 = (nodeOffset - (id208Bounds?.center ?? Offset.zero)).distance;
      if (dist208 < 300) {
        print('  ${entry.key}: pos=($nx, $ny), dist to id_208 center=${dist208.toStringAsFixed(1)}');
      }
    }

    print('\nNodes near id_157:');
    for (final entry in allMapNodes.entries) {
      final nx = entry.value['x'] + nodeOffX;
      final ny = entry.value['y'] + nodeOffY;
      final nodeOffset = Offset(nx, ny);
      final dist157 = (nodeOffset - (id157Bounds?.center ?? Offset.zero)).distance;
      if (dist157 < 300) {
        print('  ${entry.key}: pos=($nx, $ny), dist to id_157 center=${dist157.toStringAsFixed(1)}');
      }
    }
  });
}
