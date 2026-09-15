import 'dart:ui';

/// Parses bounding boxes and center points for all 134 stalls in the Ligao Public Market SVG map.
class StallSvgParser {
  const StallSvgParser._();

  /// Parse orthogonal path d string into a list of Offset points
  static List<Offset> _parseOrthogonalPathPoints(String d) {
    final tokens = RegExp(r'[A-Za-z]|[-+]?[0-9]*\.?[0-9]+')
        .allMatches(d)
        .map((m) => m.group(0)!)
        .toList();
    final points = <Offset>[];
    var i = 0;
    var cmd = '';
    var curX = 0.0;
    var curY = 0.0;

    while (i < tokens.length) {
      final t = tokens[i];
      if (RegExp(r'^[A-Za-z]$').hasMatch(t)) {
        cmd = t.toUpperCase();
        i++;
      } else {
        if (cmd == 'M') {
          curX = double.tryParse(t) ?? curX;
          i++;
          if (i < tokens.length) {
            curY = double.tryParse(tokens[i]) ?? curY;
            i++;
          }
          points.add(Offset(curX, curY));
        } else if (cmd == 'H') {
          curX = double.tryParse(t) ?? curX;
          i++;
          points.add(Offset(curX, curY));
        } else if (cmd == 'V') {
          curY = double.tryParse(t) ?? curY;
          i++;
          points.add(Offset(curX, curY));
        } else {
          i++;
        }
      }
    }
    return points;
  }

  /// Calculates the bounding Rect of a collection of points
  static Rect? _calculateBoundingBox(List<Offset> points) {
    if (points.isEmpty) return null;
    var minX = points.first.dx;
    var maxX = points.first.dx;
    var minY = points.first.dy;
    var maxY = points.first.dy;

    for (var j = 1; j < points.length; j++) {
      final p = points[j];
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }

    if (minX <= maxX && minY <= maxY) {
      return Rect.fromLTRB(minX, minY, maxX, maxY);
    }
    return null;
  }

  /// Extracts bounding boxes for stalls from the SVG content.
  /// If [includeSlots] is true, includes both assigned stalls (id_#) and empty slots (slot_[zone]_#).
  static Map<String, Rect> parseBounds(
    String svgContent, {
    bool includeSlots = false,
  }) {
    final bounds = <String, Rect>{};
    final idPattern =
        includeSlots ? r'\bid="((?:id_|slot_)[^"]+)"' : r'\bid="(id_[^"]+)"';
    final gPattern = includeSlots
        ? r'<g\s+[^>]*?\bid="((?:id_|slot_)[^"]+)"[^>]*?>'
        : r'<g\s+[^>]*?\bid="(id_[^"]+)"[^>]*?>';

    // 1. Parse <rect> elements
    final rectRegex = RegExp(r'<rect\s+([^>]*?)>', caseSensitive: false);
    for (final match in rectRegex.allMatches(svgContent)) {
      final attrs = match.group(1);
      if (attrs == null) continue;
      final idMatch = RegExp(idPattern).firstMatch(attrs);
      final xMatch = RegExp(r'\bx="([0-9.-]+)"').firstMatch(attrs);
      final yMatch = RegExp(r'\by="([0-9.-]+)"').firstMatch(attrs);
      final wMatch = RegExp(r'\bwidth="([0-9.-]+)"').firstMatch(attrs);
      final hMatch = RegExp(r'\bheight="([0-9.-]+)"').firstMatch(attrs);

      if (idMatch != null &&
          xMatch != null &&
          yMatch != null &&
          wMatch != null &&
          hMatch != null) {
        final id = idMatch.group(1)!;
        final x = double.tryParse(xMatch.group(1)!);
        final y = double.tryParse(yMatch.group(1)!);
        final w = double.tryParse(wMatch.group(1)!);
        final h = double.tryParse(hMatch.group(1)!);
        if (x != null && y != null && w != null && h != null) {
          bounds[id] = Rect.fromLTWH(x, y, w, h);
        }
      }
    }

    // 2. Parse <path> elements
    final pathRegex = RegExp(r'<path\s+([^>]*?)>', caseSensitive: false);
    for (final match in pathRegex.allMatches(svgContent)) {
      final attrs = match.group(1);
      if (attrs == null) continue;
      final idMatch = RegExp(idPattern).firstMatch(attrs);
      final dMatch = RegExp(r'\bd="([^"]+)"').firstMatch(attrs);

      if (idMatch != null && dMatch != null) {
        final id = idMatch.group(1)!;
        final points = _parseOrthogonalPathPoints(dMatch.group(1)!);
        final rect = _calculateBoundingBox(points);
        if (rect != null) {
          bounds[id] = rect;
        }
      }
    }

    // 3. Parse <g> elements with matching id
    final gRegex = RegExp(gPattern, caseSensitive: false);
    for (final match in gRegex.allMatches(svgContent)) {
      final id = match.group(1)!;
      final startIdx = match.end;
      final endIdx = svgContent.indexOf('</g>', startIdx);
      if (endIdx != -1) {
        final inside = svgContent.substring(startIdx, endIdx);
        final points = <Offset>[];

        for (final rm in rectRegex.allMatches(inside)) {
          final rattrs = rm.group(1);
          if (rattrs == null) continue;
          final rx = RegExp(r'\bx="([0-9.-]+)"').firstMatch(rattrs);
          final ry = RegExp(r'\by="([0-9.-]+)"').firstMatch(rattrs);
          final rw = RegExp(r'\bwidth="([0-9.-]+)"').firstMatch(rattrs);
          final rh = RegExp(r'\bheight="([0-9.-]+)"').firstMatch(rattrs);
          if (rx != null && ry != null && rw != null && rh != null) {
            final x = double.tryParse(rx.group(1)!) ?? 0;
            final y = double.tryParse(ry.group(1)!) ?? 0;
            final w = double.tryParse(rw.group(1)!) ?? 0;
            final h = double.tryParse(rh.group(1)!) ?? 0;
            points.add(Offset(x, y));
            points.add(Offset(x + w, y + h));
          }
        }

        for (final pm in pathRegex.allMatches(inside)) {
          final pattrs = pm.group(1);
          if (pattrs == null) continue;
          final d = RegExp(r'\bd="([^"]+)"').firstMatch(pattrs);
          if (d != null) {
            points.addAll(_parseOrthogonalPathPoints(d.group(1)!));
          }
        }

        final rect = _calculateBoundingBox(points);
        if (rect != null) {
          bounds[id] = rect;
        }
      }
    }

    return bounds;
  }

  /// Convenience helper to extract all 231 stall and slot bounding boxes
  static Map<String, Rect> parseAllBounds(String svgContent) =>
      parseBounds(svgContent, includeSlots: true);

  /// Efficiently applies fill and stroke colors to multiple stalls and slots in a single pass.
  /// [colorMap] maps stall or slot ID to fill, stroke, and optional strokeWidth.
  static String applyStallColorsBatch(
    String svgContent,
    Map<String, ({String fill, String stroke, double? strokeWidth})> colorMap,
  ) {
    if (colorMap.isEmpty) return svgContent;

    var modified = svgContent;

    // 1. Direct single tags: <rect ... id="..." ...>, <path ... id="..." ...>, etc.
    final singleTagRegex = RegExp(
      r'<([a-zA-Z0-9]+)\b([^>]*?\bid="([^"]+)"[^>]*)>',
      caseSensitive: false,
    );

    modified = modified.replaceAllMapped(singleTagRegex, (match) {
      final tagName = match.group(1)!;
      final id = match.group(3)!;

      if (tagName.toLowerCase() == 'g' || !colorMap.containsKey(id)) {
        return match.group(0)!;
      }

      final colorConfig = colorMap[id]!;
      final fillHex = colorConfig.fill;
      final strokeHex = colorConfig.stroke;
      final strokeWidth = colorConfig.strokeWidth ?? 2.0;

      var attrs = match.group(2)!;

      // Handle self-closing tags (e.g. <rect ... />)
      final isSelfClosing = attrs.trimRight().endsWith('/');
      if (isSelfClosing) {
        attrs = attrs.trimRight();
        attrs = attrs.substring(0, attrs.length - 1).trimRight();
      }

      // Update or insert fill
      if (RegExp(r'\bfill="[^"]*"').hasMatch(attrs)) {
        attrs = attrs.replaceAll(RegExp(r'\bfill="[^"]*"'), 'fill="$fillHex"');
      } else {
        attrs += ' fill="$fillHex"';
      }

      // Update or insert stroke
      if (RegExp(r'\bstroke="[^"]*"').hasMatch(attrs)) {
        attrs = attrs.replaceAll(RegExp(r'\bstroke="[^"]*"'), 'stroke="$strokeHex"');
      } else {
        attrs += ' stroke="$strokeHex"';
      }

      // Update or insert stroke-width
      if (RegExp(r'\bstroke-width="[^"]*"').hasMatch(attrs)) {
        attrs = attrs.replaceAll(
          RegExp(r'\bstroke-width="[^"]*"'),
          'stroke-width="$strokeWidth"',
        );
      } else {
        attrs += ' stroke-width="$strokeWidth"';
      }

      return isSelfClosing ? '<$tagName$attrs/>' : '<$tagName$attrs>';
    });

    // 2. Group tags: <g ... id="..."> ... </g>
    final groupRegex = RegExp(
      r'(<g\b[^>]*?\bid="([^"]+)"[^>]*?>)([\s\S]*?)(<\/g>)',
      caseSensitive: false,
    );

    modified = modified.replaceAllMapped(groupRegex, (match) {
      final gStart = match.group(1)!;
      final id = match.group(2)!;
      var inner = match.group(3)!;
      final gEnd = match.group(4)!;

      if (!colorMap.containsKey(id)) {
        return match.group(0)!;
      }

      final colorConfig = colorMap[id]!;
      final fillHex = colorConfig.fill;
      final strokeHex = colorConfig.stroke;

      // Replace fill on inner elements
      if (RegExp(r'\bfill="[^"]*"').hasMatch(inner)) {
        inner = inner.replaceAll(RegExp(r'\bfill="[^"]*"'), 'fill="$fillHex"');
      }
      // Replace stroke on inner elements
      if (RegExp(r'\bstroke="[^"]*"').hasMatch(inner)) {
        inner = inner.replaceAll(RegExp(r'\bstroke="[^"]*"'), 'stroke="$strokeHex"');
      }

      return '$gStart$inner$gEnd';
    });

    return modified;
  }

  /// Safely updates fill and stroke color for a stall or slot by ID without
  /// stripping geometry attributes (x, y, width, height, d) or element tags.
  /// Handles both direct elements (`<rect>`, `<path>`, `<polygon>`) and group elements (`<g>`).
  static String applyStallColor(
    String svgContent,
    String stallId,
    String fillHex,
    String strokeHex, {
    double strokeWidth = 2.0,
  }) {
    if (stallId.trim().isEmpty) return svgContent;
    return applyStallColorsBatch(
      svgContent,
      {
        stallId.trim(): (
          fill: fillHex,
          stroke: strokeHex,
          strokeWidth: strokeWidth,
        ),
      },
    );
  }
}

