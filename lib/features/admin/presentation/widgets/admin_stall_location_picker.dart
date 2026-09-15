import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import '../../../../core/theme/app_colors.dart';
import '../../../../models/stall_model.dart';
import '../../../../providers/stall_provider.dart';
import '../../../map/domain/zone_palette.dart';
import '../../../map/services/stall_svg_parser.dart';

/// Result returned when a stall location is picked on the market map
class AdminStallLocationResult {
  final String stallId;
  final String zoneCode;
  final String sectionName;
  final String suggestedStallNumber;
  final Rect bounds;
  final Offset center;
  final bool isCleared;

  const AdminStallLocationResult({
    required this.stallId,
    required this.zoneCode,
    required this.sectionName,
    required this.suggestedStallNumber,
    required this.bounds,
    required this.center,
    this.isCleared = false,
  });

  const AdminStallLocationResult.cleared()
      : stallId = '',
        zoneCode = '',
        sectionName = '',
        suggestedStallNumber = '',
        bounds = Rect.zero,
        center = Offset.zero,
        isCleared = true;
}

/// Interactive vector map location picker for Admin Add & Edit Stall screens.
/// Enforces:
/// 1. Only light gray stalls (#E2E8F0) are counted and selectable as empty stalls.
/// 2. Occupied stalls display their canonical category colors and cannot be selected.
/// 3. When an empty stall is selected, it dynamically previews in the stall category color.
class AdminStallLocationPicker extends ConsumerStatefulWidget {
  final String? initialStallId;
  final String? stallCategory;
  final String? stallName;
  final ValueChanged<AdminStallLocationResult>? onLocationSelected;

  const AdminStallLocationPicker({
    super.key,
    this.initialStallId,
    this.stallCategory,
    this.stallName,
    this.onLocationSelected,
  });

  /// Static helper to open picker as a full-screen sheet/route
  static Future<AdminStallLocationResult?> show(
    BuildContext context, {
    String? initialStallId,
    String? stallCategory,
    String? stallName,
  }) {
    return Navigator.of(context).push<AdminStallLocationResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => AdminStallLocationPicker(
          initialStallId: initialStallId,
          stallCategory: stallCategory,
          stallName: stallName,
        ),
      ),
    );
  }

  @override
  ConsumerState<AdminStallLocationPicker> createState() =>
      _AdminStallLocationPickerState();
}

class _AdminStallLocationPickerState
    extends ConsumerState<AdminStallLocationPicker>
    with TickerProviderStateMixin {
  static const double _svgWidth = 8004.0;
  static const double _svgHeight = 8000.0;
  static const double _defaultZoom = 0.25;
  static const double _minScale = 0.15;
  static const double _maxScale = 3.5;
  static const Offset _marketCenter = Offset(3850, 3650);

  late final TransformationController _transformController;
  late final AnimationController _pulseController;
  late final AnimationController _panZoomController;
  late final Animation<double> _pulseAnimation;

  String? _rawSvgContent;
  String? _coloredSvgContent;
  bool _isLoadingSvg = true;

  final Map<String, Rect> _allBounds = {};
  final Map<String, Offset> _allCenters = {};

  String? _selectedSlotId;

  @override
  void initState() {
    super.initState();
    _selectedSlotId = widget.initialStallId;
    _transformController = TransformationController();

    _panZoomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadSvgMap();
  }

  @override
  void dispose() {
    _panZoomController.dispose();
    _pulseController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _loadSvgMap() async {
    try {
      var svgStr = await DefaultAssetBundle.of(context)
          .loadString('assets/map/LigaoCity_PublicMarket_Map.svg');
      svgStr = svgStr.replaceFirst('fill="#1E1E1E"', 'fill="#FFFFFF"');

      final bounds = StallSvgParser.parseAllBounds(svgStr);
      _allBounds.clear();
      _allBounds.addAll(bounds);
      _allCenters.clear();
      for (final entry in bounds.entries) {
        _allCenters[entry.key] = entry.value.center;
      }

      if (mounted) {
        setState(() {
          _rawSvgContent = svgStr;
          _isLoadingSvg = false;
        });
        _buildColoredSvg();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            if (_selectedSlotId != null && _allCenters.containsKey(_selectedSlotId)) {
              _animateToPoint(_allCenters[_selectedSlotId]!, 0.65, animate: false);
            } else {
              _centerOnMarket(animate: false);
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading SVG map in picker: $e');
      if (mounted) setState(() => _isLoadingSvg = false);
    }
  }

  /// Repaint occupied stalls in their category colors, and preview selected empty slot in pending category
  void _buildColoredSvg() {
    if (_rawSvgContent == null) return;
    final colorMap =
        <String, ({String fill, String stroke, double? strokeWidth})>{};

    final stallsAsync = ref.read(allStallsProvider);
    final stalls = stallsAsync.asData?.value ?? const <StallModel>[];

    // 1. Color all occupied stalls according to their category
    for (final stall in stalls) {
      if (!stall.hasMapLocation) continue;
      if (stall.mapStallId == widget.initialStallId &&
          stall.mapStallId != _selectedSlotId) {
        // Old position being edited: leave empty
        continue;
      }
      final colorSet = ZonePalette.getColorSet(stall.category);
      final fillHex = _colorToHex(colorSet.fill);
      final outlineHex = _colorToHex(colorSet.outline);
      final config = (fill: fillHex, stroke: outlineHex, strokeWidth: 2.0);

      colorMap[stall.mapStallId] = config;
    }

    // 2. Color selected empty slot with the pending category color
    if (_selectedSlotId != null) {
      final previewCat = widget.stallCategory ?? 'Unassigned';
      final colorSet = previewCat != 'Unassigned'
          ? ZonePalette.getColorSet(previewCat)
          : ZonePalette.produce;
      final fillHex = _colorToHex(colorSet.fill);
      final outlineHex = _colorToHex(colorSet.outline);

      colorMap[_selectedSlotId!] = (
        fill: fillHex,
        stroke: outlineHex,
        strokeWidth: 3.0,
      );
    }

    final modified =
        StallSvgParser.applyStallColorsBatch(_rawSvgContent!, colorMap);

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

  void _animateToPoint(Offset target, double zoom, {bool animate = true}) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;

    final matrix = Matrix4.identity()
      ..translateByVector3(Vector3(size.width / 2, size.height / 2, 0.0))
      ..scaleByVector3(Vector3(zoom, zoom, zoom))
      ..translateByVector3(Vector3(-target.dx, -target.dy, 0.0));

    if (animate) {
      _panZoomController.stop();
      _panZoomController.reset();
      final animation = Matrix4Tween(
        begin: _transformController.value,
        end: matrix,
      ).animate(CurvedAnimation(
        parent: _panZoomController,
        curve: Curves.easeOutCubic,
      ));

      void listener() {
        _transformController.value = animation.value;
      }

      animation.addListener(listener);
      _panZoomController.forward().whenComplete(() {
        animation.removeListener(listener);
      });
    } else {
      _transformController.value = matrix;
    }
  }

  void _handleCanvasTap(Offset localPos) {
    String? hitStallId;
    double closestDistSq = double.infinity;

    for (final entry in _allBounds.entries) {
      final hitRect = entry.value.inflate(14.0);
      if (hitRect.contains(localPos)) {
        final center = _allCenters[entry.key] ?? entry.value.center;
        final distSq = (localPos - center).distanceSquared;
        if (distSq < closestDistSq) {
          closestDistSq = distSq;
          hitStallId = entry.key;
        }
      }
    }

    if (hitStallId == null) return;

    // Tapping currently selected stall toggles/clears selection
    if (hitStallId == _selectedSlotId) {
      HapticFeedback.selectionClick();
      setState(() {
        _selectedSlotId = null;
      });
      _buildColoredSvg();
      return;
    }

    final stallsAsync = ref.read(allStallsProvider);
    final stalls = stallsAsync.asData?.value ?? const <StallModel>[];

    // Check if tapped stall is occupied by an active vendor with a map location
    StallModel? occupiedStall;
    final hitLower = hitStallId.toLowerCase();
    final hitNum = hitLower.replaceFirst('id_', '');

    for (final stall in stalls) {
      if (!stall.hasMapLocation) continue;
      final mapId = stall.mapStallId.toLowerCase();
      final physId = (stall.physicalStallId ?? '').toLowerCase();
      if (mapId == hitLower ||
          physId == hitLower ||
          mapId == hitNum ||
          (stall.stallNumber != null &&
              stall.stallNumber!.toLowerCase() == hitNum)) {
        occupiedStall = stall;
        break;
      }
    }

    // If occupied by another stall (not the current stall being edited), reject selection
    final isCurrentStall = widget.initialStallId != null &&
        (hitStallId == widget.initialStallId ||
            occupiedStall?.mapStallId == widget.initialStallId ||
            occupiedStall?.physicalStallId == widget.initialStallId);

    if (occupiedStall != null && !isCurrentStall) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Stall is occupied by "${occupiedStall.name}" (${occupiedStall.category}). Only light gray stalls are vacant.',
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 12.5),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    // Valid empty stall (or current stall being edited)
    HapticFeedback.selectionClick();
    setState(() {
      _selectedSlotId = hitStallId;
    });
    _buildColoredSvg();
  }

  AdminStallLocationResult _buildResultForSlot(String slotId) {
    final bounds = _allBounds[slotId] ?? Rect.fromLTWH(0, 0, 50, 50);
    final center = _allCenters[slotId] ?? bounds.center;

    String zoneCode = 'general';
    String sectionName = 'Market Section';
    String stallNum = slotId.toUpperCase();

    if (slotId.startsWith('slot_')) {
      final parts = slotId.split('_');
      if (parts.length >= 3) {
        zoneCode = parts[1];
        final numPart = parts[2];
        switch (zoneCode) {
          case 'wm':
            sectionName = 'MEAT SECTION';
            stallNum = 'STALL #$numPart WET MARKET';
            break;
          case 'dm':
            sectionName = 'DRY MARKET';
            stallNum = 'STALL #$numPart DRY MARKET';
            break;
          case 'ea':
            sectionName = 'CARENDERIA';
            stallNum = 'STALL #$numPart EATERIES';
            break;
          case 'rs':
            sectionName = 'BUILDING II';
            stallNum = 'STALL #$numPart RICE SECTION';
            break;
          case 'fs':
            sectionName = 'PRODUCE SECTION';
            stallNum = 'STALL #$numPart FRUITS & VEGETABLES';
            break;
          default:
            sectionName = 'BUILDING I';
            stallNum = 'STALL #$numPart';
        }
      }
    } else if (slotId.startsWith('id_')) {
      final num = slotId.replaceFirst('id_', '');
      stallNum = 'STALL #$num';
      sectionName = 'BUILDING I';
    }

    return AdminStallLocationResult(
      stallId: slotId,
      zoneCode: zoneCode,
      sectionName: sectionName,
      suggestedStallNumber: stallNum,
      bounds: bounds,
      center: center,
    );
  }

  String _formatSlotLabel(String slotId) {
    if (slotId.startsWith('slot_')) {
      final parts = slotId.split('_');
      if (parts.length >= 3) {
        final zone = parts[1].toUpperCase();
        final num = parts[2];
        final zoneTitle = switch (parts[1]) {
          'wm' => 'Wet Market',
          'dm' => 'Dry Market',
          'ea' => 'Eateries',
          'rs' => 'Rice Section',
          'fs' => 'Fruits Section',
          _ => 'Market',
        };
        return '$zoneTitle (Slot $zone-$num)';
      }
    } else if (slotId.startsWith('id_')) {
      return 'Official Stall #${slotId.replaceFirst('id_', '')}';
    }
    return slotId.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to stalls stream to refresh colors when data loads
    ref.listen(allStallsProvider, (_, next) {
      if (next.hasValue) _buildColoredSvg();
    });

    final selectedBounds =
        _selectedSlotId != null ? _allBounds[_selectedSlotId] : null;

    final categoryColorSet = widget.stallCategory != null &&
            widget.stallCategory!.isNotEmpty
        ? ZonePalette.getColorSet(widget.stallCategory!)
        : ZonePalette.produce;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Stall Location',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              'Tap an empty light gray stall to assign location',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.center_focus_strong_rounded, color: Color(0xFF1B5E20)),
            tooltip: 'Center Market',
            onPressed: () => _centerOnMarket(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // 1. Interactive Vector SVG Map
          if (_isLoadingSvg)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          else
            InteractiveViewer(
              transformationController: _transformController,
              minScale: _minScale,
              maxScale: _maxScale,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              constrained: false,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) => _handleCanvasTap(details.localPosition),
                child: SizedBox(
                  width: _svgWidth,
                  height: _svgHeight,
                  child: Stack(
                    children: [
                      // Base SVG Map
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

                      // Selection Ring Overlay over selected stall
                      if (selectedBounds != null)
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, _) {
                            final inflated =
                                selectedBounds.inflate(6.0 * _pulseAnimation.value);
                            return Positioned(
                              left: inflated.left,
                              top: inflated.top,
                              width: inflated.width,
                              height: inflated.height,
                              child: IgnorePointer(
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: const Color(0xFF1B5E20),
                                      width: 4.0,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF1B5E20).withValues(alpha: 0.35),
                                        blurRadius: 12 * _pulseAnimation.value,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),

          // 2. Legend / Color Hint Pill
          Positioned(
            bottom: _selectedSlotId != null ? 180 : 24,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      border: Border.all(color: const Color(0xFF94A3B8), width: 1.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Empty Stall (Available)',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color(0xFF475569),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: categoryColorSet.fill,
                      border: Border.all(color: categoryColorSet.outline, width: 1.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.stallCategory != null && widget.stallCategory!.isNotEmpty
                        ? widget.stallCategory!
                        : 'Category Color',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color(0xFF475569),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Selected Slot Confirmation Card
          if (_selectedSlotId != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1B5E20), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B5E20).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.place_rounded,
                            color: Color(0xFF1B5E20),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatSlotLabel(_selectedSlotId!),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: categoryColorSet.fill,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Will display in ${categoryColorSet.displayName} color',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: Text(
                            'Vacant Slot',
                            style: GoogleFonts.poppins(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF16A34A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        if (widget.initialStallId != null &&
                            widget.initialStallId!.isNotEmpty) ...[
                          Expanded(
                            flex: 1,
                            child: SizedBox(
                              height: 50,
                              child: OutlinedButton(
                                onPressed: () {
                                  widget.onLocationSelected?.call(
                                    const AdminStallLocationResult.cleared(),
                                  );
                                  Navigator.of(context).pop(
                                    const AdminStallLocationResult.cleared(),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xFFDC2626),
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.close_rounded,
                                      color: Color(0xFFDC2626),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Remove',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFFDC2626),
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          flex: (widget.initialStallId != null &&
                                  widget.initialStallId!.isNotEmpty)
                              ? 2
                              : 1,
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () {
                                final result =
                                    _buildResultForSlot(_selectedSlotId!);
                                widget.onLocationSelected?.call(result);
                                Navigator.of(context).pop(result);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1B5E20),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Confirm',
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // 2. Removal confirmation card when deselected
          if (_selectedSlotId == null &&
              widget.initialStallId != null &&
              widget.initialStallId!.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom > 0
                  ? MediaQuery.of(context).padding.bottom + 8
                  : 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.location_off_rounded,
                            color: Color(0xFFDC2626),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'No Location Selected',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Tap below to remove map location from this stall.',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () {
                          widget.onLocationSelected?.call(
                            const AdminStallLocationResult.cleared(),
                          );
                          Navigator.of(context).pop(
                            const AdminStallLocationResult.cleared(),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Color(0xFFDC2626),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.close_rounded,
                              color: Color(0xFFDC2626),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Remove Map Location',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFDC2626),
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
