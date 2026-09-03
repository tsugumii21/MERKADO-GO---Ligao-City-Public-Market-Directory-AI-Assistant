import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import '../../../../core/theme/app_colors.dart';
import '../../../../models/stall_model.dart';
import '../../domain/navigation_models.dart';
import '../../domain/zone_palette.dart';

/// Predefined market zones for quick-focus navigation
class MarketZoneArea {
  final String id;
  final String title;
  final String subtitle;
  final Color color;
  final Offset centerOffset;
  final double defaultZoom;

  const MarketZoneArea({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.centerOffset,
    this.defaultZoom = 2.4,
  });
}

const List<MarketZoneArea> kMarketZoneAreas = [
  MarketZoneArea(
    id: 'wet_market',
    title: 'Wet Market',
    subtitle: 'Fish, Meat & Poultry',
    color: Color(0xFFE57373),
    centerOffset: Offset(3900, 3900),
    defaultZoom: 2.2,
  ),
  MarketZoneArea(
    id: 'eateries',
    title: 'Eateries',
    subtitle: 'Carinderia & Cooked Food',
    color: Color(0xFFFF8A65),
    centerOffset: Offset(4260, 2800),
    defaultZoom: 2.5,
  ),
  MarketZoneArea(
    id: 'dry_market',
    title: 'Dry Market',
    subtitle: 'Textiles & Goods',
    color: Color(0xFFFFD54F),
    centerOffset: Offset(3500, 2900),
    defaultZoom: 2.2,
  ),
  MarketZoneArea(
    id: 'rice_section',
    title: 'Rice Section',
    subtitle: 'Grains & Feeds',
    color: Color(0xFFE5A93C),
    centerOffset: Offset(3000, 4200),
    defaultZoom: 2.3,
  ),
  MarketZoneArea(
    id: 'fruits_section',
    title: 'Fruits Section',
    subtitle: 'Fresh Fruits & Vegetables',
    color: Color(0xFF4CAF50),
    centerOffset: Offset(4600, 4200),
    defaultZoom: 2.4,
  ),
];

/// Interactive SVG Vector Market Map with dynamic coloring and A* route overlay
class InteractiveMarketMap extends StatefulWidget {
  final List<StallModel> stalls;
  final StallModel? selectedStall;
  final NavigationRoute? activeRoute;
  final List<MarketEntryPoint> entryPoints;
  final ValueChanged<StallModel>? onStallSelected;
  final ValueChanged<MarketEntryPoint>? onEntranceTapped;
  final TransformationController? transformationController;
  final VoidCallback? onMapTapped;

  const InteractiveMarketMap({
    super.key,
    this.stalls = const [],
    this.selectedStall,
    this.activeRoute,
    this.entryPoints = const [],
    this.onStallSelected,
    this.onEntranceTapped,
    this.transformationController,
    this.onMapTapped,
  });

  @override
  State<InteractiveMarketMap> createState() => _InteractiveMarketMapState();
}

class _InteractiveMarketMapState extends State<InteractiveMarketMap>
    with SingleTickerProviderStateMixin {
  static const double _svgWidth = 8004.0;
  static const double _svgHeight = 8000.0;

  // Calibrated coordinate offsets between node space and SVG canvas space
  static const double _nodeOffsetX = 7706.4;
  static const double _nodeOffsetY = 3163.3;

  late TransformationController _transformController;
  String? _rawSvgContent;
  String? _coloredSvgContent;
  bool _isLoadingSvg = true;
  Map<String, GraphNode> _allGraphNodes = {};

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _transformController =
        widget.transformationController ?? TransformationController();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadAndPrepareSvg();
    _loadGraphNodes();

    // Initial center on market complex after layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerOnMarket();
    });
  }

  Future<void> _loadGraphNodes() async {
    try {
      final str = await DefaultAssetBundle.of(context)
          .loadString('assets/map/map_nodes.json');
      final map = jsonDecode(str) as Map<String, dynamic>;
      final parsed = <String, GraphNode>{};
      for (final entry in map.entries) {
        parsed[entry.key] = GraphNode.fromJson(
            entry.key, entry.value as Map<String, dynamic>);
      }
      if (mounted) {
        setState(() {
          _allGraphNodes = parsed;
        });
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant InteractiveMarketMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stalls != oldWidget.stalls ||
        widget.selectedStall != oldWidget.selectedStall) {
      _applyCategoryColors();
    }

    // Auto-center on selected stall if selection changed
    if (widget.selectedStall != null &&
        widget.selectedStall != oldWidget.selectedStall) {
      // Could center on stall
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    if (widget.transformationController == null) {
      _transformController.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAndPrepareSvg() async {
    try {
      var svgStr = await DefaultAssetBundle.of(context)
          .loadString('assets/map/LigaoCity_PublicMarket_Map.svg');
      // Set pure white background for the SVG map
      svgStr = svgStr.replaceFirst('fill="#1E1E1E"', 'fill="#FFFFFF"');
      if (mounted) {
        setState(() {
          _rawSvgContent = svgStr;
          _isLoadingSvg = false;
        });
        _applyCategoryColors();
      }
    } catch (e) {
      debugPrint('Error loading market SVG: $e');
      if (mounted) {
        setState(() {
          _isLoadingSvg = false;
        });
      }
    }
  }

  /// Inject dynamic 17-category palette colors into SVG elements matching stall IDs
  void _applyCategoryColors() {
    if (_rawSvgContent == null) return;

    var modified = _rawSvgContent!;

    // Replace color attributes for each stall
    for (final stall in widget.stalls) {
      final colorSet = ZonePalette.getColorSet(stall.category);
      final fillHex = _colorToHex(colorSet.fill);
      final outlineHex = _colorToHex(colorSet.outline);

      // Check if selected
      final isSelected = widget.selectedStall?.stallId == stall.stallId;
      final effectiveFill = isSelected ? _colorToHex(colorSet.accent) : fillHex;

      // Regex replace fill and stroke for id="stall_id"
      final pattern = RegExp(
        'id="${RegExp.escape(stall.stallId)}"[^>]*?(fill="[^"]*")?([^>]*?)(stroke="[^"]*")?',
      );

      modified = modified.replaceAllMapped(pattern, (match) {
        return 'id="${stall.stallId}" fill="$effectiveFill" stroke="$outlineHex" stroke-width="${isSelected ? 4 : 2}"';
      });
    }

    if (mounted) {
      setState(() {
        _coloredSvgContent = modified;
      });
    }
  }

  String _colorToHex(Color color) {
    return '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  void _centerOnMarket() {
    // Focus on center of market complex (3800, 3500)
    _animateToPoint(const Offset(3800, 3500), 1.2);
  }

  void _animateToPoint(Offset target, double zoom) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final viewportSize = renderBox.size;
    final targetX = target.dx;
    final targetY = target.dy;

    final matrix = Matrix4.identity()
      ..translateByVector3(
        Vector3(
          viewportSize.width / 2 - targetX * zoom,
          viewportSize.height / 2 - targetY * zoom,
          0.0,
        ),
      )
      ..scaleByVector3(Vector3(zoom, zoom, 1.0));

    _transformController.value = matrix;
  }

  void _zoomIn() {
    final currentScale = _transformController.value.getMaxScaleOnAxis();
    final newScale = (currentScale * 1.35).clamp(0.5, 6.0);
    _animateToScale(newScale);
  }

  void _zoomOut() {
    final currentScale = _transformController.value.getMaxScaleOnAxis();
    final newScale = (currentScale / 1.35).clamp(0.5, 6.0);
    _animateToScale(newScale);
  }

  void _animateToScale(double targetScale) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final viewportSize = renderBox.size;
    final currentMatrix = _transformController.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();

    final centerPoint = Offset(
      (-currentMatrix.getTranslation().x + viewportSize.width / 2) / currentScale,
      (-currentMatrix.getTranslation().y + viewportSize.height / 2) / currentScale,
    );

    _animateToPoint(centerPoint, targetScale);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingSvg) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return Container(
      color: Colors.white,
      child: Stack(
        children: [
          // Main Interactive Vector Map Canvas
          GestureDetector(
            onTap: widget.onMapTapped,
            child: InteractiveViewer(
              transformationController: _transformController,
              minScale: 0.4,
              maxScale: 6.0,
              boundaryMargin: const EdgeInsets.all(1200),
              constrained: false,
              child: SizedBox(
                width: _svgWidth,
                height: _svgHeight,
                child: Stack(
                  children: [
                    // Layer 1: Base SVG Map with dynamic 17-category coloring
                    if (_coloredSvgContent != null)
                      SvgPicture.string(
                        _coloredSvgContent!,
                        width: _svgWidth,
                        height: _svgHeight,
                        fit: BoxFit.fill,
                      )
                    else if (_rawSvgContent != null)
                      SvgPicture.string(
                        _rawSvgContent!,
                        width: _svgWidth,
                        height: _svgHeight,
                        fit: BoxFit.fill,
                      ),

                    // Layer 2: A* Pathfinding Route Polyline Overlay
                    if (widget.activeRoute != null &&
                        widget.activeRoute!.nodes.isNotEmpty)
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, _) {
                          return CustomPaint(
                            size: const Size(_svgWidth, _svgHeight),
                            painter: RouteOverlayPainter(
                              route: widget.activeRoute!,
                              nodeOffsetX: _nodeOffsetX,
                              nodeOffsetY: _nodeOffsetY,
                              pulseScale: _pulseAnimation.value,
                            ),
                          );
                        },
                      ),

                    // Layer 3: Entrance Gate Marker Badges
                    ...widget.entryPoints.map((entrance) {
                      final node = _findNodeInRouteOrService(entrance.nodeId);
                      if (node == null) return const SizedBox.shrink();
                      final pos = Offset(
                        node.x + _nodeOffsetX,
                        node.y + _nodeOffsetY,
                      );

                      return Positioned(
                        left: pos.dx - 24,
                        top: pos.dy - 24,
                        child: GestureDetector(
                          onTap: () => widget.onEntranceTapped?.call(entrance),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Gate ${entrance.entranceId}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),

          // Floating Map Controls (Zoom In, Zoom Out, Reset Center)
          Positioned(
            right: 16,
            bottom: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMapControlButton(
                  icon: Icons.add_rounded,
                  tooltip: 'Zoom In',
                  onPressed: _zoomIn,
                ),
                const SizedBox(height: 8),
                _buildMapControlButton(
                  icon: Icons.remove_rounded,
                  tooltip: 'Zoom Out',
                  onPressed: _zoomOut,
                ),
                const SizedBox(height: 8),
                _buildMapControlButton(
                  icon: Icons.center_focus_strong_rounded,
                  tooltip: 'Center Market',
                  onPressed: _centerOnMarket,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  GraphNode? _findNodeInRouteOrService(String nodeId) {
    if (widget.activeRoute != null) {
      for (final node in widget.activeRoute!.nodes) {
        if (node.id == nodeId) return node;
      }
    }
    return _allGraphNodes[nodeId];
  }

  Widget _buildMapControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: AppColors.surface,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: AppColors.ink, size: 20),
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// CustomPainter for drawing glowing A* Pathfinding route polyline
class RouteOverlayPainter extends CustomPainter {
  final NavigationRoute route;
  final double nodeOffsetX;
  final double nodeOffsetY;
  final double pulseScale;

  RouteOverlayPainter({
    required this.route,
    required this.nodeOffsetX,
    required this.nodeOffsetY,
    required this.pulseScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (route.nodes.isEmpty) return;

    final canvasPoints = route.nodes.map((node) {
      return Offset(node.x + nodeOffsetX, node.y + nodeOffsetY);
    }).toList();

    if (canvasPoints.length < 2) return;

    // Draw route outer glow
    final glowPaint = Paint()
      ..color = const Color(0xFF4CAF50).withValues(alpha: 0.35)
      ..strokeWidth = 18.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Draw route main line
    final routePaint = Paint()
      ..color = const Color(0xFF1B5E20)
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Draw route inner dash
    final innerPaint = Paint()
      ..color = const Color(0xFF81C784)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(canvasPoints.first.dx, canvasPoints.first.dy);
    for (int i = 1; i < canvasPoints.length; i++) {
      path.lineTo(canvasPoints[i].dx, canvasPoints[i].dy);
    }

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, routePaint);
    canvas.drawPath(path, innerPaint);

    // Draw Start Marker (Entrance)
    final startPt = canvasPoints.first;
    final startPaint = Paint()..color = const Color(0xFF2E7D32);
    final startInner = Paint()..color = Colors.white;
    canvas.drawCircle(startPt, 14.0, startPaint);
    canvas.drawCircle(startPt, 6.0, startInner);

    // Draw Destination Pulse Pin
    final endPt = canvasPoints.last;
    final pulsePaint = Paint()
      ..color = const Color(0xFFE53935).withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    final destPinPaint = Paint()..color = const Color(0xFFE53935);
    final destInner = Paint()..color = Colors.white;

    // Pulsing outer halo
    canvas.drawCircle(endPt, 22.0 * pulseScale, pulsePaint);
    canvas.drawCircle(endPt, 14.0, destPinPaint);
    canvas.drawCircle(endPt, 5.0, destInner);
  }

  @override
  bool shouldRepaint(covariant RouteOverlayPainter oldDelegate) {
    return oldDelegate.route != route ||
        oldDelegate.pulseScale != pulseScale;
  }
}
