import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../models/stall_model.dart';
import '../../../../providers/stall_provider.dart';
import '../../domain/navigation_models.dart';
import '../../providers/navigation_provider.dart';
import 'interactive_market_map.dart';

/// Available selection modes in the EntranceSelectorSheet
enum _EntranceViewMode {
  list,
  map,
}

/// Bottom sheet modal for selecting starting market entrance
class EntranceSelectorSheet extends ConsumerStatefulWidget {
  final ValueChanged<MarketEntryPoint>? onEntranceSelected;
  final String? targetStallId;
  final String? targetStallName;

  const EntranceSelectorSheet({
    super.key,
    this.onEntranceSelected,
    this.targetStallId,
    this.targetStallName,
  });

  static Future<MarketEntryPoint?> show(
    BuildContext context, {
    String? targetStallId,
    String? targetStallName,
  }) {
    return showModalBottomSheet<MarketEntryPoint>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.40),
      sheetAnimationStyle: AnimationStyle(
        duration: const Duration(milliseconds: 360),
        curve: const Cubic(0.16, 1.0, 0.3, 1.0),
        reverseDuration: const Duration(milliseconds: 260),
        reverseCurve: Curves.easeInCubic,
      ),
      builder: (context) => EntranceSelectorSheet(
        targetStallId: targetStallId,
        targetStallName: targetStallName,
      ),
    );
  }

  @override
  ConsumerState<EntranceSelectorSheet> createState() =>
      _EntranceSelectorSheetState();
}

class _EntranceSelectorSheetState extends ConsumerState<EntranceSelectorSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  MarketEntryPoint? _selectedEntrance;
  _EntranceViewMode _viewMode = _EntranceViewMode.list;

  @override
  void initState() {
    super.initState();
    _selectedEntrance = ref.read(selectedEntranceProvider);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  void _confirmSelection() {
    final entrance = _selectedEntrance;
    HapticFeedback.mediumImpact();
    ref.read(selectedEntranceProvider.notifier).state = entrance;

    // If route is active and we are just changing entrance from the map card
    final activeRoute = ref.read(activeRouteProvider);
    if (activeRoute != null && widget.targetStallId == null) {
      if (entrance != null) {
        ref.read(activeRouteProvider.notifier).navigateToStall(
              stallId: activeRoute.destinationStallId,
              stallName: activeRoute.destinationStallName,
              entranceOverride: entrance,
            );
      } else {
        ref.read(activeRouteProvider.notifier).clearRoute();
      }
    }

    if (entrance != null) {
      widget.onEntranceSelected?.call(entrance);
    }
    Navigator.of(context).pop(entrance);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Authentic landmark and zone hints for the 14 Ligao Public Market gates
  String _getLandmarkContext(int entranceId) {
    switch (entranceId) {
      case 1:
        return 'South Plaza • Church Entrance';
      case 2:
        return 'West Corridor • Back of LCC';
      case 3:
        return 'West Walkway • Side of LCC';
      case 4:
        return 'West Aisle • Wet Market Access';
      case 5:
        return 'Northwest Side • Rice Section';
      case 6:
        return 'North Intersection • Rice Section';
      case 7:
        return 'North Corridor • Rosco Building';
      case 8:
        return 'Northeast Arcade • Fruit Section';
      case 9:
        return 'East Rear Walkway • Dry Market';
      case 10:
        return 'Southwest Aisle • Side of LCC';
      case 11:
        return 'Southwest Plaza • Back of LCC';
      case 12:
        return 'Central Arcade • Eateries Section';
      case 13:
        return 'Middle Gate • Wet Market Center';
      case 14:
        return 'Central Junction • Wet & Dry Market';
      default:
        return 'Market Entry Corridor';
    }
  }

  @override
  Widget build(BuildContext context) {
    final entryPoints = ref.watch(entryPointsProvider);
    final service = ref.watch(pathfindingServiceProvider);
    final stallsAsync = ref.watch(allStallsProvider);
    final stalls = stallsAsync.value ?? const [];
    final targetStall = widget.targetStallId != null
        ? stalls.where((s) => s.stallId == widget.targetStallId).firstOrNull
        : null;
    final nearestEntrance = (widget.targetStallId != null && service.isInitialized)
        ? service.findNearestEntranceByWalkingDistance(widget.targetStallId!)
        : null;
    final effectiveSelected = _selectedEntrance;
    final isMapMode = _viewMode == _EntranceViewMode.map && widget.targetStallId != null;
    final screenHeight = MediaQuery.of(context).size.height;

    final filteredEntryPoints = entryPoints.where((e) {
      if (_searchQuery.isEmpty) return true;
      final gateStr = 'gate ${e.entranceId}'.toLowerCase();
      final idStr = e.entranceId.toString();
      final descStr = e.description.toLowerCase();
      final landmarkStr = _getLandmarkContext(e.entranceId).toLowerCase();
      return gateStr.contains(_searchQuery) ||
          idStr == _searchQuery ||
          descStr.contains(_searchQuery) ||
          landmarkStr.contains(_searchQuery);
    }).toList();

    return Container(
      height: isMapMode ? screenHeight * 0.70 : null,
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.70,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: isMapMode ? MainAxisSize.max : MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 38,
                height: 4.5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 6,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: effectiveSelected != null
                          ? AppColors.primaryLight
                          : const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.location_on_rounded,
                      color: effectiveSelected != null
                          ? AppColors.primary
                          : const Color(0xFFE53935),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Starting Entrance',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          widget.targetStallName != null
                              ? 'Choose where you will enter the market'
                              : 'Select a gate to reposition the map view',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: AppColors.inkMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.inkMuted,
                    splashRadius: 20,
                  ),
                ],
              ),
            ),

            // Destination Context Banner (when navigating to a stall)
            if (widget.targetStallName != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F8F4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8E2)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TARGET DESTINATION',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            widget.targetStallName!,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A241A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (nearestEntrance != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFF81C784),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          'Gate ${nearestEntrance.entranceId} is closest',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1B5E20),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            // View mode toggle: [ List View ] | [ Pick on Map ] (strictly on stall page)
            if (widget.targetStallId != null)
              _buildViewModeToggle(),

            if (!isMapMode) ...[
              // Search filter field
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1.0,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search by gate number or landmark...',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF94A3B8),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.primary,
                      size: 19,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.cancel_rounded, size: 17),
                            color: const Color(0xFF94A3B8),
                            splashRadius: 16,
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                  ),
                ),
              ),

              const Divider(color: Color(0xFFE2E8F0), height: 1),

              // Entrance list
              if (entryPoints.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (filteredEntryPoints.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.search_off_rounded,
                        size: 38,
                        color: AppColors.inkSubtle,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No entrances found for "$_searchQuery"',
                        style: AppTextStyles.bodyMuted,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => _searchController.clear(),
                        child: const Text('Clear search'),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 8,
                    ),
                    itemCount: filteredEntryPoints.length,
                    itemBuilder: (context, index) {
                      final entrance = filteredEntryPoints[index];
                      final isSelected =
                          effectiveSelected?.entranceId == entrance.entranceId;
                      final isNearest =
                          nearestEntrance?.entranceId == entrance.entranceId;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: isSelected
                              ? const Color(0xFFF0F7F0)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                if (_selectedEntrance?.entranceId ==
                                    entrance.entranceId) {
                                  _selectedEntrance = null;
                                } else {
                                  _selectedEntrance = entrance;
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : const Color(0xFFE5E7EB),
                                  width: isSelected ? 1.8 : 1.0,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.12),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  // Gate badge icon
                                  Container(
                                    width: 58,
                                    height: 54,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primary
                                            : const Color(0xFFCBD5E1),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.location_on_rounded,
                                          color: isSelected
                                              ? Colors.white
                                              : const Color(0xFFE53935),
                                          size: 24,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Gate ${entrance.entranceId}',
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: isSelected
                                                ? Colors.white
                                                : const Color(0xFF1E293B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Gate details & context
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'Entrance Gate ${entrance.entranceId}',
                                              style: GoogleFonts.outfit(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.ink,
                                              ),
                                            ),
                                            if (isNearest) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 1.5,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFE8F5E9),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'Shortest Walk',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF1B5E20),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          _getLandmarkContext(
                                              entrance.entranceId),
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: AppColors.inkMuted,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          entrance.description,
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: AppColors.inkSubtle,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Selection radio indicator
                                  Icon(
                                    isSelected
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: isSelected
                                        ? AppColors.primary
                                        : const Color(0xFFCBD5E1),
                                    size: 22,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ] else ...[
              // Interactive Market Map View
              _buildInteractiveMapView(
                entryPoints: entryPoints,
                stalls: stalls,
                targetStall: targetStall,
                nearestEntrance: nearestEntrance,
              ),
            ],
            // Bottom Action Bar: Select Starting Entrance Button
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Color(0xFFE5E7EB), width: 1.0),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: effectiveSelected != null
                        ? _confirmSelection
                        : (widget.targetStallId == null &&
                                ref.read(selectedEntranceProvider) != null
                            ? _confirmSelection
                            : null),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: effectiveSelected != null
                          ? AppColors.primary
                          : (widget.targetStallId == null &&
                                  ref.read(selectedEntranceProvider) != null
                              ? AppColors.surface
                              : const Color(0xFFE2E8F0)),
                      disabledBackgroundColor: const Color(0xFFE2E8F0),
                      foregroundColor: effectiveSelected != null
                          ? Colors.white
                          : (widget.targetStallId == null &&
                                  ref.read(selectedEntranceProvider) != null
                              ? AppColors.ink
                              : const Color(0xFF94A3B8)),
                      disabledForegroundColor: const Color(0xFF94A3B8),
                      elevation: effectiveSelected != null ? 1 : 0,
                      side: (effectiveSelected == null &&
                              widget.targetStallId == null &&
                              ref.read(selectedEntranceProvider) != null)
                          ? const BorderSide(
                              color: Color(0xFFD1D5DB),
                              width: 1.2,
                            )
                          : BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          effectiveSelected != null
                              ? Icons.directions_walk_rounded
                              : (widget.targetStallId == null &&
                                      ref.read(selectedEntranceProvider) != null
                                  ? Icons.clear_rounded
                                  : Icons.directions_walk_rounded),
                          size: 19,
                          color: effectiveSelected != null
                              ? Colors.white
                              : (widget.targetStallId == null &&
                                      ref.read(selectedEntranceProvider) != null
                                  ? AppColors.ink
                                  : const Color(0xFF94A3B8)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          effectiveSelected != null
                              ? 'Select Starting Entrance • Gate ${effectiveSelected.entranceId}'
                              : (widget.targetStallId == null &&
                                      ref.read(selectedEntranceProvider) != null
                                  ? 'Clear Selected Entrance'
                                  : 'Select Starting Entrance'),
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: effectiveSelected != null
                                ? Colors.white
                                : (widget.targetStallId == null &&
                                        ref.read(selectedEntranceProvider) !=
                                            null
                                    ? AppColors.ink
                                    : const Color(0xFF94A3B8)),
                          ),
                        ),
                        if (effectiveSelected != null) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 17,
                            color: Colors.white,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Segmented capsule switch for toggling between List View and Map View
  Widget _buildViewModeToggle() {
    final isMapMode = _viewMode == _EntranceViewMode.map;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
      ),
      padding: const EdgeInsets.all(2.5),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleSegment(
              title: 'List View',
              icon: Icons.format_list_bulleted_rounded,
              isSelected: !isMapMode,
              onTap: () {
                if (_viewMode != _EntranceViewMode.list) {
                  HapticFeedback.selectionClick();
                  setState(() => _viewMode = _EntranceViewMode.list);
                }
              },
            ),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: _buildToggleSegment(
              title: 'Pick on Map',
              icon: Icons.map_rounded,
              isSelected: isMapMode,
              onTap: () {
                if (_viewMode != _EntranceViewMode.map) {
                  HapticFeedback.selectionClick();
                  setState(() => _viewMode = _EntranceViewMode.map);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleSegment({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected ? Colors.white : Colors.transparent,
      elevation: isSelected ? 1 : 0,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: const Color(0xFFCBD5E1), width: 0.8)
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? AppColors.primary : AppColors.inkMuted,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Embedded Interactive SVG Map view for picking starting entrance directly on the map canvas
  Widget _buildInteractiveMapView({
    required List<MarketEntryPoint> entryPoints,
    required List<StallModel> stalls,
    required StallModel? targetStall,
    required MarketEntryPoint? nearestEntrance,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // The Interactive SVG Map showing stalls, destination highlight, and 14 entrance pins
            InteractiveMarketMap(
              stalls: stalls,
              selectedStall: targetStall,
              entryPoints: entryPoints,
              selectedEntrance: _selectedEntrance,
              showEntrancePins: true,
              onEntranceTapped: (entrance) {
                HapticFeedback.selectionClick();
                setState(() {
                  if (_selectedEntrance?.entranceId == entrance.entranceId) {
                    _selectedEntrance = null; // Toggle unchoose
                  } else {
                    _selectedEntrance = entrance; // Select gate
                  }
                });
              },
            ),

            // Top Guidance Pill
            Positioned(
              top: 10,
              left: 12,
              right: 12,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(
                      color: const Color(0xFFCBD5E1),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.touch_app_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _selectedEntrance != null
                            ? 'Selected: Gate ${_selectedEntrance!.entranceId} (tap pin to toggle)'
                            : 'Tap any Gate pin on the map to select',
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _selectedEntrance != null
                              ? AppColors.primary
                              : AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Selected Gate Preview Card (left-floated to not overlap map zoom controls)
            if (_selectedEntrance != null)
              Positioned(
                bottom: 12,
                left: 12,
                right: 76,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'G${_selectedEntrance!.entranceId}',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Gate ${_selectedEntrance!.entranceId}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink,
                                  ),
                                ),
                                if (nearestEntrance?.entranceId ==
                                    _selectedEntrance!.entranceId) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8F5E9),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Closest',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1B5E20),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              _getLandmarkContext(_selectedEntrance!.entranceId),
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppColors.inkMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedEntrance = null);
                        },
                        icon: const Icon(Icons.close_rounded, size: 18),
                        color: AppColors.inkMuted,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        tooltip: 'Unchoose entrance',
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

