import 'dart:ui';

/// Calibration constants and visual dimensions for Ligao Public Market map navigation
class MapCalibrationConstants {
  /// Verified translation vector from map_nodes.json coordinate space
  /// to LigaoCity_PublicMarket_Map.svg coordinate frame.
  static const Offset nodeToSvgOffset = Offset(7823.47, 3174.0);

  /// Center point of the market SVG floorplan
  static const Offset marketCenter = Offset(4002.0, 4000.0);

  /// Corridor route rendering dimensions
  static const double casingStrokeWidth = 54.0;
  static const double ribbonStrokeWidth = 28.0;

  /// High-contrast civic colors
  static const Color casingColor = Color(0x331B5E20); // rgba(27, 94, 32, 0.20)
  static const Color ribbonColor = Color(0xFF1B5E20); // Solid Forest Green
}
