import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:merkado_go/features/map/services/stall_svg_parser.dart';

void main() {
  group('StallSvgParser Unit Tests', () {
    test('Parses all 134 stalls accurately from Ligao Public Market SVG', () {
      final svgFile = File('assets/map/LigaoCity_PublicMarket_Map.svg');
      expect(svgFile.existsSync(), isTrue);

      final svgContent = svgFile.readAsStringSync();
      final bounds = StallSvgParser.parseBounds(svgContent);

      expect(bounds.length, equals(134));

      // Test specific known stalls from distinct zones
      // Rect stall
      expect(bounds.containsKey('id_79'), isTrue);
      final rect79 = bounds['id_79']!;
      expect(rect79.left, closeTo(4598.47, 0.01));
      expect(rect79.top, closeTo(3427.0, 0.01));
      expect(rect79.width, closeTo(91.0, 0.01));
      expect(rect79.height, closeTo(119.0, 0.01));

      // Path stall
      expect(bounds.containsKey('id_253'), isTrue);
      final path253 = bounds['id_253']!;
      expect(path253.left, closeTo(3999.47, 0.01));
      expect(path253.top, closeTo(3691.0, 0.01));
      expect(path253.width, closeTo(185.0, 0.01));
      expect(path253.height, closeTo(28.0, 0.01));

      // Group stall
      expect(bounds.containsKey('id_24'), isTrue);
      final group24 = bounds['id_24']!;
      expect(group24.left, closeTo(3802.47, 0.01));
      expect(group24.top, closeTo(3966.0, 0.01));
    });

    test('Centers of all stalls are well within SVG canvas dimensions', () {
      final svgFile = File('assets/map/LigaoCity_PublicMarket_Map.svg');
      final svgContent = svgFile.readAsStringSync();
      final bounds = StallSvgParser.parseBounds(svgContent);

      for (final entry in bounds.entries) {
        final center = entry.value.center;
        expect(center.dx, greaterThan(1000.0));
        expect(center.dx, lessThan(8004.0));
        expect(center.dy, greaterThan(1000.0));
        expect(center.dy, lessThan(5824.0));
      }
    });
  });
}
