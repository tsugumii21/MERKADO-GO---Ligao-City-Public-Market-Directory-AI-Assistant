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

    test('Parses all 231 stalls and slots when includeSlots is true', () {
      final svgFile = File('assets/map/LigaoCity_PublicMarket_Map.svg');
      expect(svgFile.existsSync(), isTrue);

      final svgContent = svgFile.readAsStringSync();
      final allBounds = StallSvgParser.parseAllBounds(svgContent);

      // 134 official stalls + 97 vacant slots = 231 total
      expect(allBounds.length, equals(231));

      // Test specific vacant slots in each zone
      expect(allBounds.containsKey('slot_wm_29'), isTrue);
      expect(allBounds.containsKey('slot_fs_1'), isTrue);
      expect(allBounds.containsKey('slot_dm_6'), isTrue);
      expect(allBounds.containsKey('slot_ea_1'), isTrue);
      expect(allBounds.containsKey('slot_rs_1'), isTrue);

      // Verify slot counts per zone
      final slotKeys = allBounds.keys.where((k) => k.startsWith('slot_')).toList();
      expect(slotKeys.length, equals(97));

      final wmSlots = slotKeys.where((k) => k.startsWith('slot_wm_')).length;
      final fsSlots = slotKeys.where((k) => k.startsWith('slot_fs_')).length;
      final dmSlots = slotKeys.where((k) => k.startsWith('slot_dm_')).length;
      final rsSlots = slotKeys.where((k) => k.startsWith('slot_rs_')).length;
      final eaSlots = slotKeys.where((k) => k.startsWith('slot_ea_')).length;

      expect(wmSlots, equals(53));
      expect(fsSlots, equals(6));
      expect(dmSlots, equals(10));
      expect(rsSlots, equals(16));
      expect(eaSlots, equals(12));
    });

    test('applyStallColor modifies fill and stroke without altering element geometry', () {
      const rectSvg = '<rect id="slot_wm_29" x="4335.47" y="3898" width="73" height="28" fill="#E2E8F0" stroke="#94A3B8" stroke-width="2"/>';
      final recolored = StallSvgParser.applyStallColor(
        rectSvg,
        'slot_wm_29',
        '#E53935',
        '#B71C1C',
        strokeWidth: 3.0,
      );

      // Verify geometry attributes are intact
      expect(recolored.contains('x="4335.47"'), isTrue);
      expect(recolored.contains('y="3898"'), isTrue);
      expect(recolored.contains('width="73"'), isTrue);
      expect(recolored.contains('height="28"'), isTrue);

      // Verify fill and stroke are updated
      expect(recolored.contains('fill="#E53935"'), isTrue);
      expect(recolored.contains('stroke="#B71C1C"'), isTrue);
      expect(recolored.contains('stroke-width="3.0"'), isTrue);
      expect(recolored.contains('#E2E8F0'), isFalse);
    });

    test('applyStallColor updates child elements in group tags', () {
      const groupSvg = '<g id="id_24"><path d="M3802.47 4029H3829.47V4074H3802.47V4029Z" fill="#E57373"/></g>';
      final recolored = StallSvgParser.applyStallColor(
        groupSvg,
        'id_24',
        '#1B5E20',
        '#004D40',
      );

      expect(recolored.contains('fill="#1B5E20"'), isTrue);
      expect(recolored.contains('d="M3802.47'), isTrue);
    });

    test('applyStallColorsBatch recolors multiple stalls in single pass and preserves geometry', () {
      const complexSvg = '''<svg>
<rect width="8004" height="8000" fill="#FFFFFF"/>
<rect id="id_1" x="100" y="200" width="50" height="60" fill="#E2E8F0" stroke="#94A3B8" stroke-width="2"/>
<path id="id_2" d="M10 20H30V40H10Z" fill="#CCCCCC"/>
<g id="id_24">
<path d="M1 2H3V4H1Z" fill="#E57373"/>
</g>
</svg>''';

      final recolored = StallSvgParser.applyStallColorsBatch(
        complexSvg,
        {
          'id_1': (fill: '#1B5E20', stroke: '#004D40', strokeWidth: 2.0),
          'id_2': (fill: '#3B82F6', stroke: '#1D4ED8', strokeWidth: 2.5),
          'id_24': (fill: '#F59E0B', stroke: '#B45309', strokeWidth: null),
        },
      );

      // Verify id_1
      expect(recolored.contains('fill="#1B5E20"'), isTrue);
      expect(recolored.contains('stroke="#004D40"'), isTrue);
      expect(recolored.contains('x="100"'), isTrue);
      expect(recolored.contains('width="50"'), isTrue);

      // Verify id_2
      expect(recolored.contains('fill="#3B82F6"'), isTrue);
      expect(recolored.contains('stroke="#1D4ED8"'), isTrue);
      expect(recolored.contains('stroke-width="2.5"'), isTrue);
      expect(recolored.contains('d="M10 20H30V40H10Z"'), isTrue);

      // Verify id_24 group
      expect(recolored.contains('fill="#F59E0B"'), isTrue);
      expect(recolored.contains('d="M1 2H3V4H1Z"'), isTrue);

      // Verify non-stall elements untouched
      expect(recolored.contains('width="8004" height="8000" fill="#FFFFFF"'), isTrue);
    });

    test('applyStallColorsBatch properly preserves self-closing tags without stroke attribute', () {
      const selfClosingSvg = '<rect id="id_114" x="3802.47" y="3885" width="27" height="45" fill="#E57373"/>';
      final recolored = StallSvgParser.applyStallColorsBatch(
        selfClosingSvg,
        {'id_114': (fill: '#1B5E20', stroke: '#004D40', strokeWidth: 2.0)},
      );

      // Must not contain trailing slash before stroke
      expect(recolored.contains('/ stroke='), isFalse);
      expect(recolored.endsWith('/>'), isTrue);
      expect(recolored.contains('fill="#1B5E20"'), isTrue);
      expect(recolored.contains('stroke="#004D40"'), isTrue);
      expect(recolored.contains('stroke-width="2.0"'), isTrue);
    });

    test('applyStallColorsBatch recolors full market map SVG without corrupting XML tags', () {
      final svgFile = File('assets/map/LigaoCity_PublicMarket_Map.svg');
      final svgContent = svgFile.readAsStringSync();
      final colorMap =
          <String, ({String fill, String stroke, double? strokeWidth})>{};

      for (var i = 1; i <= 265; i++) {
        colorMap['id_$i'] =
            (fill: '#1B5E20', stroke: '#004D40', strokeWidth: 2.0);
      }

      final recolored =
          StallSvgParser.applyStallColorsBatch(svgContent, colorMap);

      // Verify no corrupted slash stroke
      expect(recolored.contains('/ stroke='), isFalse);
      expect(recolored.contains('/ fill='), isFalse);
      expect(recolored.contains('/ stroke-width='), isFalse);

      // Verify id_114 was cleanly recolored
      expect(
        recolored.contains(
            'id="id_114" x="3802.47" y="3885" width="27" height="45" fill="#1B5E20" stroke="#004D40" stroke-width="2.0"/>'),
        isTrue,
      );
    });
  });
}
