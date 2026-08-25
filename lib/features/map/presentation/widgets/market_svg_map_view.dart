import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../models/stall_model.dart';

/// Predefined section bounds & focal points in the 3504 x 2571 SVG coordinate system
class MarketSectionArea {
  final String id;
  final String title;
  final String subtitle;
  final Color color;
  final Offset centerOffset;
  final double defaultZoom;

  const MarketSectionArea({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.centerOffset,
    this.defaultZoom = 2.0,
  });
}

const List<MarketSectionArea> kMarketSections = [
  MarketSectionArea(
    id: 'wet_market',
    title: 'Wet Market',
    subtitle: 'Fish & Meat Complex',
    color: Color(0xFFE53935),
    centerOffset: Offset(1855, 1715),
    defaultZoom: 1.8,
  ),
  MarketSectionArea(
    id: 'meat_section',
    title: 'Meat Section',
    subtitle: 'Pork, Beef & Poultry',
    color: Color(0xFFC62828),
    centerOffset: Offset(1427, 1730),
    defaultZoom: 2.2,
  ),
  MarketSectionArea(
    id: 'fish_section',
    title: 'Fish Section',
    subtitle: 'Fresh Seafood & Fish',
    color: Color(0xFF1565C0),
    centerOffset: Offset(2170, 1730),
    defaultZoom: 2.2,
  ),
  MarketSectionArea(
    id: 'fruits_section',
    title: 'Fruits Section',
    subtitle: 'Fresh Produce & Fruits',
    color: Color(0xFF2E7D32),
    centerOffset: Offset(950, 525),
    defaultZoom: 2.4,
  ),
  MarketSectionArea(
    id: 'rice_section',
    title: 'Rice Section',
    subtitle: 'Grains & Feed Supply',
    color: Color(0xFF4527A0),
    centerOffset: Offset(575, 1075),
    defaultZoom: 2.0,
  ),
  MarketSectionArea(
    id: 'dry_market',
    title: 'Dry Market',
    subtitle: 'Textiles & Groceries',
    color: Color(0xFF7B1FA2),
    centerOffset: Offset(1425, 725),
    defaultZoom: 2.0,
  ),
  MarketSectionArea(
    id: 'eateries',
    title: 'Eateries',
    subtitle: 'Karinderya & Cooked Food',
    color: Color(0xFF880E4F),
    centerOffset: Offset(2180, 646),
    defaultZoom: 2.0,
  ),
];

class MarketSvgMapView extends StatefulWidget {
  final List<StallModel> stalls;
  final StallModel? selectedStall;
  final ValueChanged<StallModel>? onStallSelected;
  final TransformationController? transformationController;
  final VoidCallback? onMapTapped;
  final ValueChanged<double>? onRotationChanged;

  const MarketSvgMapView({
    super.key,
    this.stalls = const [],
    this.selectedStall,
    this.onStallSelected,
    this.transformationController,
    this.onMapTapped,
    this.onRotationChanged,
  });

  static const double svgWidth = 3504.0;
  static const double svgHeight = 2571.0;

  @override
  State<MarketSvgMapView> createState() => MarketSvgMapViewState();
}

class MarketSvgMapViewState extends State<MarketSvgMapView>
    with TickerProviderStateMixin {
  late TransformationController _controller;
  Animation<Matrix4>? _animation;
  late AnimationController _animController;
  Size _viewportSize = Size.zero;

  // Rotation Gesture & Animation State
  double _rotationAngle = 0.0;
  double _gestureStartAngle = 0.0;
  bool _isRotating = false;
  late AnimationController _rotationAnimController;
  Animation<double>? _rotationAnimation;

  double get rotationAngle => _rotationAngle;

  bool _initializedFraming = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.transformationController ?? TransformationController();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _rotationAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _rotationAnimController.dispose();
    if (widget.transformationController == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  /// Reset rotation smoothly back to 0.0 (True North)
  void resetRotation() {
    if (_rotationAngle == 0.0) return;
    _rotationAnimation = Tween<double>(
      begin: _rotationAngle,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _rotationAnimController,
      curve: Curves.easeOutCubic,
    ))..addListener(() {
      setState(() {
        _rotationAngle = _rotationAnimation!.value;
      });
      widget.onRotationChanged?.call(_rotationAngle);
    });
    _rotationAnimController.forward(from: 0.0);
  }

  /// Step zoom in
  void zoomIn() {
    _zoomBy(1.3);
  }

  /// Step zoom out
  void zoomOut() {
    _zoomBy(0.77);
  }

  void _zoomBy(double factor) {
    if (_viewportSize == Size.zero) return;
    final currentMatrix = _controller.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();
    final targetScale = (currentScale * factor).clamp(1.0, 5.0);
    final actualFactor = targetScale / currentScale;

    final center = Offset(_viewportSize.width / 2, _viewportSize.height / 2);

    // ignore: deprecated_member_use
    final targetMatrix = Matrix4.identity()
      // ignore: deprecated_member_use
      ..translate(center.dx, center.dy)
      // ignore: deprecated_member_use
      ..scale(actualFactor)
      // ignore: deprecated_member_use
      ..translate(-center.dx, -center.dy)
      ..multiply(currentMatrix);

    _animateMatrix(targetMatrix);
  }

  /// Focus on specific market section
  void focusOnSection(MarketSectionArea section) {
    animateTo(section.centerOffset, zoom: section.defaultZoom);
  }

  /// Reset map view to full fit (default zoom = max zoom out)
  void resetView() {
    resetRotation();
    if (_viewportSize == Size.zero) return;
    final mapWidth = MarketSvgMapView.svgWidth * (_viewportSize.height / MarketSvgMapView.svgHeight);
    final targetX = (_viewportSize.width - mapWidth) / 2;
    final targetMatrix = Matrix4.identity()..setTranslationRaw(targetX, 0, 0);
    _animateMatrix(targetMatrix);
  }

  /// Smoothly animate camera to coordinate and zoom
  void animateTo(Offset targetInSvg, {double zoom = 2.0}) {
    if (_viewportSize == Size.zero) return;

    final mapWidth = MarketSvgMapView.svgWidth * (_viewportSize.height / MarketSvgMapView.svgHeight);
    final mapHeight = _viewportSize.height;
    final scaleX = mapWidth / MarketSvgMapView.svgWidth;
    final scaleY = mapHeight / MarketSvgMapView.svgHeight;

    final targetScale = zoom.clamp(1.0, 5.0);
    final targetX = -targetInSvg.dx * scaleX * targetScale + (_viewportSize.width / 2);
    final targetY = -targetInSvg.dy * scaleY * targetScale + (_viewportSize.height / 2);

    final targetMatrix = Matrix4.identity()
      ..setTranslationRaw(targetX, targetY, 0)
      // ignore: deprecated_member_use
      ..scale(targetScale, targetScale, 1.0);

    _animateMatrix(targetMatrix);
  }

  void _animateMatrix(Matrix4 targetMatrix) {
    _animation = Matrix4Tween(
      begin: _controller.value,
      end: targetMatrix,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _animation!.addListener(() {
      _controller.value = _animation!.value;
    });

    _animController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
        final mapWidth = MarketSvgMapView.svgWidth *
            (constraints.maxHeight / MarketSvgMapView.svgHeight);
        final mapHeight = constraints.maxHeight;

        // Auto-center and fill viewport on first layout (Scale = 1.0, Default zoom = Max zoom out)
        if (!_initializedFraming && constraints.maxWidth > 0 && constraints.maxHeight > 0) {
          _initializedFraming = true;
          final targetX = (constraints.maxWidth - mapWidth) / 2;
          _controller.value = Matrix4.identity()
            ..setTranslationRaw(targetX, 0, 0);
        }

        return GestureDetector(
          onTap: widget.onMapTapped,
          onDoubleTap: () {
            if (_controller.value.getMaxScaleOnAxis() > 1.2) {
              resetView();
            } else {
              _zoomBy(1.8);
            }
          },
          child: Container(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            color: Colors.white,
            child: InteractiveViewer(
              transformationController: _controller,
              panEnabled: true,
              scaleEnabled: true,
              minScale: 1.0,
              maxScale: 5.0,
              boundaryMargin: EdgeInsets.zero,
              constrained: false,
              onInteractionStart: (details) {
                _gestureStartAngle = _rotationAngle;
                _isRotating = false;
              },
              onInteractionUpdate: (details) {
                // Hard-clamp scale in real-time to prevent sub-1.0 zoom during fast pinch
                final currentScale = _controller.value.getMaxScaleOnAxis();
                if (currentScale < 1.0) {
                  final m = _controller.value.clone();
                  final factor = 1.0 / currentScale;
                  final cx = constraints.maxWidth / 2;
                  final cy = constraints.maxHeight / 2;
                  final snap = Matrix4.identity()
                    // ignore: deprecated_member_use
                    ..translate(cx, cy)
                    // ignore: deprecated_member_use
                    ..scale(factor)
                    // ignore: deprecated_member_use
                    ..translate(-cx, -cy)
                    ..multiply(m);
                  _controller.value = snap;
                }

                if (details.pointerCount >= 2) {
                  // Deadzone threshold: ~4.0 degrees (~0.07 rad)
                  const double deadzone = 0.07;
                  if (!_isRotating && details.rotation.abs() > deadzone) {
                    _isRotating = true;
                  }
                  if (_isRotating) {
                    setState(() {
                      _rotationAngle = _gestureStartAngle + details.rotation;
                    });
                    widget.onRotationChanged?.call(_rotationAngle);
                  }
                }
              },
              onInteractionEnd: (_) {
                _isRotating = false;
                // Snap back if pinch released below minimum scale
                final currentScale = _controller.value.getMaxScaleOnAxis();
                if (currentScale < 1.0) {
                  resetView();
                }
              },
              child: Transform.rotate(
                angle: _rotationAngle,
                alignment: Alignment.center,
                child: SizedBox(
                  width: mapWidth,
                  height: mapHeight,
                  child: SvgPicture.asset(
                    'assets/images/LigaoCity_PublicMarket_Map.svg',
                    width: mapWidth,
                    height: mapHeight,
                    fit: BoxFit.fill,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

