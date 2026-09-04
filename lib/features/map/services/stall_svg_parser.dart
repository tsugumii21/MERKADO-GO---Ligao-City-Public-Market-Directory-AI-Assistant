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

  /// Extracts bounding boxes for all 134 stalls from the SVG content
  static Map<String, Rect> parseBounds(String svgContent) {
    final bounds = <String, Rect>{};

    // 1. Parse <rect> elements
    final rectRegex = RegExp(r'<rect\s+([^>]*?)>', caseSensitive: false);
    for (final match in rectRegex.allMatches(svgContent)) {
      final attrs = match.group(1);
      if (attrs == null) continue;
      final idMatch = RegExp(r'\bid="(id_[^"]+)"').firstMatch(attrs);
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
      final idMatch = RegExp(r'\bid="(id_[^"]+)"').firstMatch(attrs);
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

    // 3. Parse <g> elements with id="id_..."
    final gRegex = RegExp(
      r'<g\s+[^>]*?\bid="(id_[^"]+)"[^>]*?>',
      caseSensitive: false,
    );
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
}
