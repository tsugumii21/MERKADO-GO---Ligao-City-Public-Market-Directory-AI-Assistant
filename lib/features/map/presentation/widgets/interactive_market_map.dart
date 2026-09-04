import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
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
      _extractStallCenters(svgStr);
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

  /// Parse SVG stall rectangles once to resolve exact center points
  void _extractStallCenters(String svgStr) {
    _stallCenterCache.clear();
    final rectRegex = RegExp(r'<rect\s+([^>]*?)>', caseSensitive: false);
    for (final match in rectRegex.allMatches(svgStr)) {
      final attrs = match.group(1);
      if (attrs == null) continue;
      final idMatch = RegExp(r'id="([^"]+)"').firstMatch(attrs);
      final xMatch = RegExp(r'x="([0-9.-]+)"').firstMatch(attrs);
      final yMatch = RegExp(r'y="([0-9.-]+)"').firstMatch(attrs);
      final wMatch = RegExp(r'width="([0-9.-]+)"').firstMatch(attrs);
      final hMatch = RegExp(r'height="([0-9.-]+)"').firstMatch(attrs);

      if (idMatch != null && xMatch != null && yMatch != null && wMatch != null && hMatch != null) {
        final id = idMatch.group(1)!;
        final x = double.tryParse(xMatch.group(1)!);
        final y = double.tryParse(yMatch.group(1)!);
        final w = double.tryParse(wMatch.group(1)!);
        final h = double.tryParse(hMatch.group(1)!);
        if (x != null && y != null && w != null && h != null) {
          _stallCenterCache[id] = Offset(x + w / 2, y + h / 2);
        }
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
                        left: pos.dx - 45,
                        top: pos.dy - 77,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => widget.onEntranceTapped?.call(entrance),
                          child: SizedBox(
                            width: 90,
                            height: 110,
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

    // Layer 1: Translucent Route Track Casing
    final casingPaint = Paint()
      ..color = const Color(0x291B5E20) // rgba(27, 94, 32, 0.16)
      ..strokeWidth = 24.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, casingPaint);

    // Layer 2: Route outer glow
    final glowPaint = Paint()
      ..color = const Color(0xFF4CAF50).withValues(alpha: 0.35)
      ..strokeWidth = 18.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, glowPaint);

    // Layer 3: Flowing Forest Green main line
    final routePaint = Paint()
      ..color = const Color(0xFF1B5E20)
      ..strokeWidth = 12.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, routePaint);

    // Layer 4: Light green inner line
    final innerPaint = Paint()
      ..color = const Color(0xFF81C784)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, innerPaint);

    // Draw Start Marker (Entrance Departure)
    final startPaint = Paint()..color = const Color(0xFF2E7D32);
    final startInner = Paint()..color = Colors.white;
    canvas.drawCircle(startPt, 18.0, startPaint);
    canvas.drawCircle(startPt, 8.0, startInner);

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

/// 3D Vector Pin Painter for Entrance Gate Markers with Location Pin Icon
class _EntrancePinCenteredPainter extends CustomPainter {
  final String label;
  final bool isSelected;

  _EntrancePinCenteredPainter({required this.label, this.isSelected = false});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height * 0.70);
    canvas.scale(0.85);

    final primaryColor =
        isSelected ? const Color(0xFF2E7D32) : const Color(0xFFE53935);
    final shadowColor =
        isSelected ? const Color(0xFF1B5E20) : const Color(0xFFC62828);

    final paint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    // 1. Draw Teardrop Contour
    final pinPath = Path()
      ..moveTo(0, 0)
      ..lineTo(-32.6, -54.5)
      ..arcToPoint(
        const Offset(32.6, -54.5),
        radius: const Radius.circular(38),
        largeArc: true,
      )
      ..close();
    canvas.drawPath(pinPath, paint);

    // 2. 3D Shaded Right Bevel
    final bevelPaint = Paint()..color = shadowColor;
    final bevelPath = Path()
      ..moveTo(0, 0)
      ..lineTo(0, -92.5)
      ..arcToPoint(
        const Offset(32.6, -54.5),
        radius: const Radius.circular(38),
      )
      ..close();
    canvas.drawPath(bevelPath, bevelPaint);

    // 3. Inner White Disc
    canvas.drawCircle(const Offset(0, -54.5), 26, Paint()..color = Colors.white);

    // 4. Dedicated Location Pin Icon in center of disc
    final iconPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;
    final pinIconPath = Path()
      ..moveTo(0, -42)
      ..cubicTo(-7, -50, -11, -54, -11, -59)
      ..arcToPoint(
        const Offset(11, -59),
        radius: const Radius.circular(11),
      )
      ..cubicTo(11, -54, 7, -50, 0, -42)
      ..close();
    canvas.drawPath(pinIconPath, iconPaint);
    // Inner hole of location pin icon
    canvas.drawCircle(const Offset(0, -59), 4.2, Paint()..color = Colors.white);

    // 5. White Pill Badge
    final badgeRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-58, 7, 116, 36),
      const Radius.circular(18),
    );
    canvas.drawRRect(badgeRect, Paint()..color = Colors.white);
    canvas.drawRRect(
      badgeRect,
      Paint()
        ..color = primaryColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // 6. Badge Label Typography
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: isSelected ? const Color(0xFF1B5E20) : const Color(0xFF1E293B),
          fontSize: 19,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(-textPainter.width / 2, 14));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EntrancePinCenteredPainter oldDelegate) =>
      oldDelegate.label != label || oldDelegate.isSelected != isSelected;
}
