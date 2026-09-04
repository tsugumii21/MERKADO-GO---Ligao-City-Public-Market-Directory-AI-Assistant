import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import '../../../../core/theme/app_colors.dart';
import '../../../../models/stall_model.dart';
import '../../domain/navigation_models.dart';
import '../../domain/zone_palette.dart';
import '../../services/stall_svg_parser.dart';

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
  final MarketEntryPoint? selectedEntrance;
  final ValueChanged<StallModel>? onStallSelected;
  final ValueChanged<MarketEntryPoint>? onEntranceTapped;
  final TransformationController? transformationController;
  final VoidCallback? onMapTapped;
  final int traversalTrigger;

  const InteractiveMarketMap({
    super.key,
    this.stalls = const [],
    this.selectedStall,
    this.activeRoute,
    this.entryPoints = const [],
    this.selectedEntrance,
    this.onStallSelected,
    this.onEntranceTapped,
    this.transformationController,
    this.onMapTapped,
    this.traversalTrigger = 0,
  });

  @override
  State<InteractiveMarketMap> createState() => _InteractiveMarketMapState();
}

class _InteractiveMarketMapState extends State<InteractiveMarketMap>
    with TickerProviderStateMixin {
  static const double _svgWidth = 8004.0;
  static const double _svgHeight = 8000.0;

  static const double _defaultZoom = 0.25;
  static const double _minScale = 0.25;
  static const double _maxScale = 3.5;
  static const Offset _marketCenter = Offset(3850, 3650);

  // Calibrated coordinate offsets between node space and SVG canvas space (0.0000 diff across 112 markers)
  static const double _nodeOffsetX = 7823.47;
  static const double _nodeOffsetY = 3174.00;

  late TransformationController _transformController;
  String? _rawSvgContent;
  String? _coloredSvgContent;
  bool _isLoadingSvg = true;
  Map<String, GraphNode> _allGraphNodes = {};
  List<MarketEntryPoint> _localEntryPoints = [];
  final Map<String, Offset> _stallCenterCache = {};
  final Map<String, Rect> _stallBoundsCache = {};
  bool _isClamping = false;
  Path? _cachedRoutePath;
  List<ui.PathMetric> _cachedRouteMetrics = [];
  double _cachedRouteLength = 0.0;

  List<MarketEntryPoint> get _effectiveEntryPoints =>
      widget.entryPoints.isNotEmpty ? widget.entryPoints : _localEntryPoints;

  double _getScale(Matrix4 matrix) {
    final s = matrix.storage;
    return math.sqrt(s[0] * s[0] + s[1] * s[1]);
  }

  double get _currentScale => _getScale(_transformController.value);

  bool get _canZoomOut => _currentScale > _minScale + 0.005;

  bool get _canZoomIn => _currentScale < _maxScale - 0.005;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late AnimationController _zoomAnimationController;
  Animation<Matrix4>? _zoomAnimation;

  late AnimationController _walkController;
  bool _isWalking = false;

  @override
  void initState() {
    super.initState();
    _transformController =
        widget.transformationController ?? TransformationController();
    _transformController.addListener(_onTransformChanged);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _zoomAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        if (_zoomAnimation != null) {
          _transformController.value = _zoomAnimation!.value;
        }
      });

    _walkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7000),
    )
      ..addListener(() {
        if (_isWalking && mounted) {
          _trackAvatarCamera();
        }
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {
            _isWalking = false;
          });
          _autoFrameRoute();
        }
      });

    _loadAndPrepareSvg();
    _loadGraphNodes();

    // Initial center on market complex after layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerOnMarket(animate: false);
      if (widget.activeRoute != null && widget.activeRoute!.nodes.isNotEmpty) {
        _startWalkingTraversal();
      }
    });
  }

  void _recomputeCachedRoute() {
    final points = _getRouteCanvasPoints();
    if (points.length < 2) {
      _cachedRoutePath = null;
      _cachedRouteMetrics = [];
      _cachedRouteLength = 0.0;
      return;
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    _cachedRoutePath = path;
    _cachedRouteMetrics = path.computeMetrics().toList();
    _cachedRouteLength =
        _cachedRouteMetrics.fold(0.0, (acc, m) => acc + m.length);
  }

  void _startWalkingTraversal() {
    if (widget.activeRoute == null || widget.activeRoute!.nodes.isEmpty) return;
    _recomputeCachedRoute();
    _walkController.stop();
    final stepsCount = widget.activeRoute!.steps.length;
    // Slower, calmer redirection speed: ~800ms per step, minimum 6.0s, max 14.0s
    final calculatedDuration = (stepsCount * 800).clamp(6000, 14000);
    _walkController.duration = Duration(milliseconds: calculatedDuration);
    if (mounted) {
      setState(() {
        _isWalking = true;
      });
    }
    _walkController.forward(from: 0.0);
  }

  void _onTransformChanged() {
    _clampScale();
    if (mounted && !_isWalking) {
      setState(() {});
    }
  }

  void _clampScale() {
    if (_isClamping) return;
    final currentMatrix = _transformController.value;
    final currentScale = _getScale(currentMatrix);

    if (currentScale < _minScale) {
      _isClamping = true;
      try {
        final factor = _minScale / currentScale;
        final renderBox = context.findRenderObject() as RenderBox?;
        final center = renderBox != null
            ? Offset(renderBox.size.width / 2, renderBox.size.height / 2)
            : Offset.zero;

        final clampedMatrix = Matrix4.identity()
          ..translateByVector3(Vector3(center.dx, center.dy, 0.0))
          ..scaleByVector3(Vector3(factor, factor, factor))
          ..translateByVector3(Vector3(-center.dx, -center.dy, 0.0))
          ..multiply(currentMatrix);

        _transformController.value = clampedMatrix;
      } finally {
        _isClamping = false;
      }
    } else if (currentScale > _maxScale) {
      _isClamping = true;
      try {
        final factor = _maxScale / currentScale;
        final renderBox = context.findRenderObject() as RenderBox?;
        final center = renderBox != null
            ? Offset(renderBox.size.width / 2, renderBox.size.height / 2)
            : Offset.zero;

        final clampedMatrix = Matrix4.identity()
          ..translateByVector3(Vector3(center.dx, center.dy, 0.0))
          ..scaleByVector3(Vector3(factor, factor, factor))
          ..translateByVector3(Vector3(-center.dx, -center.dy, 0.0))
          ..multiply(currentMatrix);

        _transformController.value = clampedMatrix;
      } finally {
        _isClamping = false;
      }
    }
  }

  Future<void> _loadGraphNodes() async {
    try {
      final bundle = DefaultAssetBundle.of(context);
      final str = await bundle.loadString('assets/map/map_nodes.json');
      final map = jsonDecode(str) as Map<String, dynamic>;
      final parsed = <String, GraphNode>{};
      for (final entry in map.entries) {
        parsed[entry.key] = GraphNode.fromJson(
            entry.key, entry.value as Map<String, dynamic>);
      }

      final entryStr =
          await bundle.loadString('assets/map/market_entry_points.json');
      final entryList = jsonDecode(entryStr) as List<dynamic>;
      final parsedEntries = entryList
          .map((e) => MarketEntryPoint.fromJson(e as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _allGraphNodes = parsed;
          _localEntryPoints = parsedEntries;
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

    if (widget.selectedEntrance != oldWidget.selectedEntrance &&
        widget.selectedEntrance != null &&
        widget.activeRoute == null) {
      _repositionMap(animate: true);
    }

    if (widget.traversalTrigger != oldWidget.traversalTrigger &&
        widget.activeRoute != null &&
        widget.activeRoute!.nodes.isNotEmpty) {
      _startWalkingTraversal();
    }

    if (widget.activeRoute != oldWidget.activeRoute) {
      if (widget.activeRoute != null && widget.activeRoute!.nodes.isNotEmpty) {
        _startWalkingTraversal();
      } else {
        _isWalking = false;
        _walkController.stop();
      }
    }
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
    _walkController.dispose();
    _zoomAnimationController.dispose();
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
      final parsedBounds = StallSvgParser.parseBounds(svgStr);
      _stallBoundsCache.clear();
      _stallBoundsCache.addAll(parsedBounds);
      _stallCenterCache.clear();
      for (final entry in parsedBounds.entries) {
        _stallCenterCache[entry.key] = entry.value.center;
      }
      if (mounted) {
        setState(() {
          _rawSvgContent = svgStr;
          _isLoadingSvg = false;
        });
        _applyCategoryColors();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _centerOnMarket(animate: false);
          }
        });
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

  /// Detects user tap on the interactive map canvas, matches touched stall, and triggers selection
  void _handleCanvasTap(Offset localPos) {
    String? hitStallId;
    double closestDistSq = double.infinity;

    // 1. Check all stall bounding boxes (inflated by 12px for forgiving finger tapping)
    for (final entry in _stallBoundsCache.entries) {
      final rect = entry.value;
      final hitRect = rect.inflate(12.0);
      if (hitRect.contains(localPos)) {
        final center = _stallCenterCache[entry.key] ?? rect.center;
        final distSq = (localPos - center).distanceSquared;
        if (distSq < closestDistSq) {
          closestDistSq = distSq;
          hitStallId = entry.key;
        }
      }
    }

    if (hitStallId != null) {
      StallModel? matchedStall;
      final hitLower = hitStallId.toLowerCase();
      final hitNum = hitLower.replaceFirst('id_', '');

      for (final stall in widget.stalls) {
        final sid = stall.stallId.toLowerCase();
        if (sid == hitLower ||
            sid == hitNum ||
            (stall.stallNumber != null &&
                stall.stallNumber!.toLowerCase() == hitNum)) {
          matchedStall = stall;
          break;
        }
      }

      if (matchedStall != null) {
        HapticFeedback.selectionClick();
        widget.onStallSelected?.call(matchedStall);
        return;
      }
    }

    // 2. Empty aisle/walkway tapped
    widget.onMapTapped?.call();
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

  void _centerOnMarket({bool animate = true}) {
    _animateToPoint(_marketCenter, _defaultZoom, animate: animate);
  }

  void _repositionMap({bool animate = true}) {
    if (widget.selectedEntrance != null) {
      final node = _findNodeInRouteOrService(widget.selectedEntrance!.nodeId);
      if (node != null) {
        final entrancePos = Offset(node.x + _nodeOffsetX, node.y + _nodeOffsetY);
        _animateToPoint(entrancePos, 0.45, animate: animate);
        return;
      }
    }
    _centerOnMarket(animate: animate);
  }

  void _animateToPoint(Offset target, double zoom, {bool animate = true}) {
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
      ..scaleByVector3(Vector3(zoom, zoom, zoom));

    if (animate) {
      _animateToMatrix(matrix);
    } else {
      _transformController.value = matrix;
    }
  }

  void _animateToMatrix(Matrix4 targetMatrix) {
    _zoomAnimationController.stop();
    _zoomAnimation = Matrix4Tween(
      begin: _transformController.value,
      end: targetMatrix,
    ).animate(CurvedAnimation(
      parent: _zoomAnimationController,
      curve: Curves.easeOutCubic,
    ));
    _zoomAnimationController.forward(from: 0.0);
  }

  List<Offset> _getRouteCanvasPoints() {
    if (widget.activeRoute == null || widget.activeRoute!.nodes.isEmpty) {
      return const [];
    }
    final points = widget.activeRoute!.nodes.map((node) {
      return Offset(node.x + _nodeOffsetX, node.y + _nodeOffsetY);
    }).toList();
    final destCenter = _stallCenterCache[widget.activeRoute!.destinationStallId];
    if (destCenter != null) {
      points.add(destCenter);
    }
    return points;
  }

  ui.Tangent? _getRouteTangent(double progress) {
    if (_cachedRouteMetrics.isEmpty || _cachedRouteLength <= 0) {
      _recomputeCachedRoute();
    }
    if (_cachedRouteMetrics.isEmpty || _cachedRouteLength <= 0) return null;
    final distance = progress.clamp(0.0, 1.0) * _cachedRouteLength;
    return _cachedRouteMetrics.first.getTangentForOffset(distance);
  }

  void _trackAvatarCamera() {
    final tangent = _getRouteTangent(_walkController.value);
    if (tangent == null) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final viewportSize = renderBox.size;
    const zoom = 0.55;
    final targetX = tangent.position.dx;
    final targetY = tangent.position.dy;

    final matrix = Matrix4.identity()
      ..translateByVector3(
        Vector3(
          viewportSize.width / 2 - targetX * zoom,
          viewportSize.height / 2 - targetY * zoom,
          0.0,
        ),
      )
      ..scaleByVector3(Vector3(zoom, zoom, zoom));

    _transformController.value = matrix;
  }

  void _skipWalking() {
    _walkController.stop();
    _walkController.value = 1.0;
    setState(() {
      _isWalking = false;
    });
    _autoFrameRoute();
  }

  void _autoFrameRoute() {
    final points = _getRouteCanvasPoints();
    if (points.length < 2) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    double minX = points.first.dx, maxX = points.first.dx;
    double minY = points.first.dy, maxY = points.first.dy;
    for (final pt in points) {
      if (pt.dx < minX) minX = pt.dx;
      if (pt.dx > maxX) maxX = pt.dx;
      if (pt.dy < minY) minY = pt.dy;
      if (pt.dy > maxY) maxY = pt.dy;
    }

    final routeWidth = maxX - minX;
    final routeHeight = maxY - minY;
    final center = Offset((minX + maxX) / 2, (minY + maxY) / 2);

    final viewport = renderBox.size;
    final scaleX = viewport.width / (routeWidth + 360);
    final scaleY = viewport.height / (routeHeight + 360);
    final targetScale = (scaleX < scaleY ? scaleX : scaleY).clamp(_minScale, 1.0);

    _animateToPoint(center, targetScale);
  }

  void _zoomBy(double factor) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final center = Offset(renderBox.size.width / 2, renderBox.size.height / 2);
    final currentMatrix = _transformController.value;
    final currentScale = _getScale(currentMatrix);

    if (factor < 1.0 && currentScale <= _minScale + 0.005) return;
    if (factor > 1.0 && currentScale >= _maxScale - 0.005) return;

    final targetScale = (currentScale * factor).clamp(_minScale, _maxScale);
    if ((targetScale - currentScale).abs() < 0.005) return;

    final actualFactor = targetScale / currentScale;

    final matrix = Matrix4.identity()
      ..translateByVector3(Vector3(center.dx, center.dy, 0.0))
      ..scaleByVector3(Vector3(actualFactor, actualFactor, actualFactor))
      ..translateByVector3(Vector3(-center.dx, -center.dy, 0.0))
      ..multiply(currentMatrix);

    _animateToMatrix(matrix);
  }

  void _zoomIn() {
    if (!_canZoomIn) return;
    _zoomBy(1.35);
  }

  void _zoomOut() {
    if (!_canZoomOut) return;
    _zoomBy(1 / 1.35);
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
              minScale: _minScale,
              maxScale: _maxScale,
              boundaryMargin: const EdgeInsets.all(2500),
              constrained: false,
              onInteractionUpdate: (_) => _clampScale(),
              onInteractionEnd: (_) => _clampScale(),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) => _handleCanvasTap(details.localPosition),
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

                      // Layer 1.5: Selected Stall Accent Highlight & Pulse
                      if (widget.selectedStall != null &&
                          _stallBoundsCache.containsKey(widget.selectedStall!.stallId))
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, _) {
                            return CustomPaint(
                              size: const Size(_svgWidth, _svgHeight),
                              painter: _SelectedStallHighlightPainter(
                                rect: _stallBoundsCache[widget.selectedStall!.stallId]!,
                                pulseScale: _pulseAnimation.value,
                              ),
                            );
                          },
                        ),

                    // Layer 2: A* Pathfinding Route Polyline Overlay
                    if (widget.activeRoute != null &&
                        widget.activeRoute!.nodes.isNotEmpty)
                      AnimatedBuilder(
                        animation: Listenable.merge([_pulseAnimation, _walkController]),
                        builder: (context, _) {
                          return CustomPaint(
                            size: const Size(_svgWidth, _svgHeight),
                            painter: RouteOverlayPainter(
                              route: widget.activeRoute!,
                              nodeOffsetX: _nodeOffsetX,
                              nodeOffsetY: _nodeOffsetY,
                              pulseScale: _pulseAnimation.value,
                              destinationStallCenter: _stallCenterCache[
                                  widget.activeRoute!.destinationStallId],
                              walkProgress: _walkController.value,
                              isWalking: _isWalking,
                              cachedPath: _cachedRoutePath,
                              cachedMetrics: _cachedRouteMetrics,
                              cachedLength: _cachedRouteLength,
                            ),
                          );
                        },
                      ),

                    // Layer 3: Demand-Driven 3D Vector Entrance Pins
                    ..._effectiveEntryPoints.where((entrance) {
                      if (widget.activeRoute != null) {
                        return entrance.entranceId ==
                            widget.activeRoute!.entrance.entranceId;
                      }
                      return true;
                    }).map((entrance) {
                      final node = _findNodeInRouteOrService(entrance.nodeId);
                      if (node == null) return const SizedBox.shrink();
                      final pos = Offset(
                        node.x + _nodeOffsetX,
                        node.y + _nodeOffsetY,
                      );
                      final isSelected = (widget.activeRoute != null &&
                              widget.activeRoute!.entrance.entranceId ==
                                  entrance.entranceId) ||
                          (widget.selectedEntrance?.entranceId ==
                              entrance.entranceId);

                      return Positioned(
                        left: pos.dx - 60,
                        top: pos.dy - 98,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => widget.onEntranceTapped?.call(entrance),
                          child: SizedBox(
                            width: 120,
                            height: 104,
                            child: CustomPaint(
                              painter: _EntrancePinCenteredPainter(
                                label: 'Gate ${entrance.entranceId}',
                                isSelected: isSelected,
                              ),
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
        ),

          // Floating Skip Walking Button during traversal
          if (_isWalking)
            Positioned(
              top: 16,
              right: 16,
              child: SafeArea(
                child: Material(
                  color: AppColors.surface,
                  elevation: 6,
                  shadowColor: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: _skipWalking,
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Skip',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.fast_forward_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Floating Map Controls (Replay, Zoom In, Zoom Out, Reposition)
          Positioned(
            right: 16,
            bottom: widget.activeRoute != null ? 84 : 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.activeRoute != null && !_isWalking) ...[
                  _buildMapControlButton(
                    icon: Icons.replay_rounded,
                    tooltip: 'Repeat Walk Redirection',
                    onPressed: _startWalkingTraversal,
                  ),
                  const SizedBox(height: 8),
                ],
                _buildMapControlButton(
                  icon: Icons.add_rounded,
                  tooltip: _canZoomIn ? 'Zoom In' : 'Maximum Zoom Reached',
                  onPressed: _zoomIn,
                  enabled: _canZoomIn,
                ),
                const SizedBox(height: 8),
                _buildMapControlButton(
                  icon: Icons.remove_rounded,
                  tooltip: _canZoomOut ? 'Zoom Out' : 'Minimum Zoom Reached',
                  onPressed: _zoomOut,
                  enabled: _canZoomOut,
                ),
                const SizedBox(height: 8),
                _buildMapControlButton(
                  icon: Icons.my_location_rounded,
                  tooltip: widget.selectedEntrance != null
                      ? 'Reposition to Gate ${widget.selectedEntrance!.entranceId}'
                      : 'Reposition to Center',
                  onPressed: _repositionMap,
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
    bool enabled = true,
  }) {
    return Material(
      color: enabled ? AppColors.surface : AppColors.surfaceDim,
      elevation: enabled ? 4 : 1,
      shadowColor: Colors.black.withValues(alpha: enabled ? 0.15 : 0.05),
      shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
      child: IconButton(
        onPressed: enabled ? onPressed : null,
        icon: Icon(
          icon,
          color: enabled
              ? AppColors.ink
              : AppColors.inkMuted.withValues(alpha: 0.35),
          size: 20,
        ),
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// CustomPainter for drawing two-layer glowing A* Pathfinding route polyline with walking avatar
class RouteOverlayPainter extends CustomPainter {
  final NavigationRoute route;
  final double nodeOffsetX;
  final double nodeOffsetY;
  final double pulseScale;
  final Offset? destinationStallCenter;
  final double walkProgress;
  final bool isWalking;
  final Path? cachedPath;
  final List<ui.PathMetric> cachedMetrics;
  final double cachedLength;

  RouteOverlayPainter({
    required this.route,
    required this.nodeOffsetX,
    required this.nodeOffsetY,
    required this.pulseScale,
    this.destinationStallCenter,
    this.walkProgress = 1.0,
    this.isWalking = false,
    this.cachedPath,
    this.cachedMetrics = const [],
    this.cachedLength = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (route.nodes.isEmpty) return;

    final Path path;
    final Offset startPt;
    final Offset endPt;

    if (cachedPath != null) {
      path = cachedPath!;
      startPt = Offset(
        route.nodes.first.x + nodeOffsetX,
        route.nodes.first.y + nodeOffsetY,
      );
      endPt = destinationStallCenter ??
          Offset(
            route.nodes.last.x + nodeOffsetX,
            route.nodes.last.y + nodeOffsetY,
          );
    } else {
      final canvasPoints = route.nodes.map((node) {
        return Offset(node.x + nodeOffsetX, node.y + nodeOffsetY);
      }).toList();

      if (destinationStallCenter != null) {
        canvasPoints.add(destinationStallCenter!);
      }

      if (canvasPoints.length < 2) return;

      path = Path();
      path.moveTo(canvasPoints.first.dx, canvasPoints.first.dy);
      for (int i = 1; i < canvasPoints.length; i++) {
        path.lineTo(canvasPoints[i].dx, canvasPoints[i].dy);
      }
      startPt = canvasPoints.first;
      endPt = canvasPoints.last;
    }

    // Solid flat direction line (no gradient, casing, or glow layers)
    final routePaint = Paint()
      ..color = const Color(0xFF1B5E20)
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, routePaint);

    // Draw Start Marker (Entrance Departure)
    final startPaint = Paint()..color = const Color(0xFF1B5E20);
    final startInner = Paint()..color = Colors.white;
    canvas.drawCircle(startPt, 22.0, startPaint);
    canvas.drawCircle(startPt, 9.0, startInner);

    // Draw Walking Pedestrian Avatar during traversal
    if (isWalking) {
      ui.Tangent? tangent;
      if (cachedMetrics.isNotEmpty && cachedLength > 0) {
        final currentDist = walkProgress.clamp(0.0, 1.0) * cachedLength;
        tangent = cachedMetrics.first.getTangentForOffset(currentDist);
      } else {
        final metrics = path.computeMetrics().toList();
        if (metrics.isNotEmpty) {
          final totalLength = metrics.fold(0.0, (acc, m) => acc + m.length);
          final currentDist = walkProgress.clamp(0.0, 1.0) * totalLength;
          tangent = metrics.first.getTangentForOffset(currentDist);
        }
      }

      if (tangent != null) {
        final avatarPos = tangent.position;
        // Outer halo
        canvas.drawCircle(
          avatarPos,
          24.0 * pulseScale,
          Paint()..color = const Color(0x441B5E20),
        );
        // Solid green disc
        canvas.drawCircle(
          avatarPos,
          16.0,
          Paint()..color = const Color(0xFF1B5E20),
        );
        // White rim
        canvas.drawCircle(
          avatarPos,
          16.0,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.0,
        );
        // Inner dot
        canvas.drawCircle(
          avatarPos,
          6.5,
          Paint()..color = Colors.white,
        );
      }
    }

    // Draw Destination Pulse Pin
    final pulsePaint = Paint()
      ..color = const Color(0xFFE53935).withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    final destPinPaint = Paint()..color = const Color(0xFFE53935);
    final destInner = Paint()..color = Colors.white;

    // Pulsing outer halo (Arrival celebration)
    canvas.drawCircle(endPt, 28.0 * pulseScale, pulsePaint);
    canvas.drawCircle(endPt, 18.0, destPinPaint);
    canvas.drawCircle(endPt, 7.0, destInner);
  }

  @override
  bool shouldRepaint(covariant RouteOverlayPainter oldDelegate) {
    return oldDelegate.route != route ||
        oldDelegate.pulseScale != pulseScale ||
        oldDelegate.destinationStallCenter != destinationStallCenter ||
        oldDelegate.walkProgress != walkProgress ||
        oldDelegate.isWalking != isWalking ||
        oldDelegate.cachedPath != cachedPath;
  }
}

/// 3D Vector Map Pin Painter for Entrance Gate Markers
/// Default: Red pin map icon. When pressed or chosen: turns vibrant emerald green.
class _EntrancePinCenteredPainter extends CustomPainter {
  final String label;
  final bool isSelected;

  _EntrancePinCenteredPainter({required this.label, this.isSelected = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final cx = w / 2; // 60.0
    final tipY = size.height - 4.0; // 100.0

    // Colors: Red when unselected, Emerald Green when selected/pressed
    final pinColor =
        isSelected ? const Color(0xFF1B5E20) : const Color(0xFFE53935);
    final bevelColor =
        isSelected ? const Color(0xFF0E3813) : const Color(0xFFC62828);
    final textColor =
        isSelected ? const Color(0xFF1B5E20) : const Color(0xFFC62828);

    // 1. Soft Ground Contact Shadow under needle pointer tip
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, tipY + 1.5), width: 22.0, height: 6.5),
      Paint()..color = Colors.black.withValues(alpha: 0.25),
    );

    // 2. Active Ground Beacon Ring (when chosen)
    if (isSelected) {
      canvas.drawCircle(
        Offset(cx, tipY),
        6.5,
        Paint()..color = const Color(0xFF4CAF50),
      );
      canvas.drawCircle(
        Offset(cx, tipY),
        3.0,
        Paint()..color = Colors.white,
      );
    }

    // 3. Teardrop Map Pin Path
    // Head center at (cx, 56.0), radius 21.0. Tip at (cx, tipY).
    final headCenter = Offset(cx, 56.0);
    const headRadius = 21.0;

    final pinPath = Path()
      ..moveTo(cx, tipY)
      ..lineTo(cx - 19.0, 63.0)
      ..arcToPoint(
        Offset(cx + 19.0, 63.0),
        radius: const Radius.circular(headRadius),
        largeArc: true,
      )
      ..close();

    // Elevated Pin Drop Shadow
    canvas.drawShadow(
      pinPath,
      isSelected ? const Color(0xFF1B5E20) : Colors.black,
      isSelected ? 6.0 : 4.5,
      false,
    );

    // Pin Fill
    canvas.drawPath(pinPath, Paint()..color = pinColor..style = PaintingStyle.fill);

    // 3D Shaded Right Bevel
    final bevelPath = Path()
      ..moveTo(cx, tipY)
      ..lineTo(cx, 35.0)
      ..arcToPoint(
        Offset(cx + 19.0, 63.0),
        radius: const Radius.circular(headRadius),
      )
      ..close();
    canvas.drawPath(bevelPath, Paint()..color = bevelColor..style = PaintingStyle.fill);

    // 4. Center White Disc
    canvas.drawCircle(headCenter, 13.5, Paint()..color = Colors.white);

    // Dedicated Vector Location Pin Icon inside Disc
    final iconPath = Path()
      ..moveTo(cx, 65.5)
      ..cubicTo(cx - 3.8, 61.2, cx - 6.0, 59.0, cx - 6.0, 55.5)
      ..arcToPoint(
        Offset(cx + 6.0, 55.5),
        radius: const Radius.circular(6.0),
      )
      ..cubicTo(cx + 6.0, 59.0, cx + 3.8, 61.2, cx, 65.5)
      ..close();
    canvas.drawPath(iconPath, Paint()..color = pinColor..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(cx, 55.5), 2.2, Paint()..color = Colors.white);

    // 5. Attached Label Pill Above Pin
    const pillW = 84.0;
    const pillH = 26.0;
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - pillW / 2, 4.0, pillW, pillH),
      const Radius.circular(13.0),
    );

    // Pill drop shadow
    canvas.drawShadow(
      Path()..addRRect(pillRect),
      Colors.black,
      3.0,
      false,
    );

    // Pill background
    canvas.drawRRect(
      pillRect,
      Paint()
        ..color = isSelected ? const Color(0xFF1B5E20) : Colors.white
        ..style = PaintingStyle.fill,
    );

    // Pill border (Red if unselected, White if selected)
    canvas.drawRRect(
      pillRect,
      Paint()
        ..color = isSelected ? Colors.white : const Color(0xFFE53935)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    // 6. Pill Typography ("Gate 12")
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: isSelected ? Colors.white : textColor,
          fontSize: 13.5,
          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(cx - textPainter.width / 2, 4.0 + (pillH - textPainter.height) / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _EntrancePinCenteredPainter oldDelegate) =>
      oldDelegate.label != label || oldDelegate.isSelected != isSelected;
}

/// Highlights the actively selected stall on the interactive vector map
class _SelectedStallHighlightPainter extends CustomPainter {
  final Rect rect;
  final double pulseScale;

  const _SelectedStallHighlightPainter({
    required this.rect,
    required this.pulseScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      rect.inflate(4.0),
      const Radius.circular(6.0),
    );

    // 1. Soft glowing outer pulse
    final glowPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.35 * pulseScale)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0 * pulseScale
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRRect(rrect, glowPaint);

    // 2. High-contrast crisp border
    final borderPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _SelectedStallHighlightPainter oldDelegate) {
    return oldDelegate.rect != rect || oldDelegate.pulseScale != pulseScale;
  }
}

