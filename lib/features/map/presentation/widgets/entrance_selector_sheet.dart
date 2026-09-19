import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/navigation_models.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/entrance_provider.dart';
import 'entrance_detail_sheet.dart';


/// Bottom sheet modal for selecting starting market entrance
class EntranceSelectorSheet extends ConsumerStatefulWidget {
  final ValueChanged<MarketEntryPoint>? onEntranceSelected;
  final String? targetStallId;
  final String? targetStallName;
  final VoidCallback? onPickOnMap;

  const EntranceSelectorSheet({
    super.key,
    this.onEntranceSelected,
    this.targetStallId,
    this.targetStallName,
    this.onPickOnMap,
  });

  static Future<dynamic> show(
    BuildContext context, {
    String? targetStallId,
    String? targetStallName,
    VoidCallback? onPickOnMap,
  }) {
    return showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
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
        onPickOnMap: onPickOnMap,
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

  void _clearSelection() {
    HapticFeedback.selectionClick();
    ref.read(selectedEntranceProvider.notifier).state = null;

    final activeRoute = ref.read(activeRouteProvider);
    if (activeRoute != null && widget.targetStallId == null) {
      ref.read(activeRouteProvider.notifier).clearRoute();
    }

    Navigator.of(context).pop(null);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Starting entrance selection cleared',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF334155),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _triggerPickOnMap() {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop('pick_on_map');
    widget.onPickOnMap?.call();
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
    final entryPoints = ref.watch(marketEntrancesProvider);
    final service = ref.watch(pathfindingServiceProvider);
    final nearestEntrance = (widget.targetStallId != null && service.isInitialized)
        ? service.findNearestEntranceByWalkingDistance(widget.targetStallId!)
        : null;
    final activeEntrance = ref.watch(selectedEntranceProvider);
    final effectiveSelected = _selectedEntrance;
    final isClearAction = widget.targetStallId == null &&
        activeEntrance != null &&
        (effectiveSelected == null ||
            effectiveSelected.entranceId == activeEntrance.entranceId);
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
          mainAxisSize: MainAxisSize.min,
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
                          style: GoogleFonts.plusJakartaSans(
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

            // Pick on the Map Banner (Always rendered for repositioning & target stall navigation)
            _buildPickOnMapBanner(),

              // Search filter field
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                height: 44,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFCBD5E1),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
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
                      color: Color(0xFF64748B),
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
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
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
                                    padding: const EdgeInsets.symmetric(vertical: 4),
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
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.location_on_rounded,
                                          color: isSelected
                                              ? Colors.white
                                              : const Color(0xFFE53935),
                                          size: 22,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Gate ${entrance.entranceId}',
                                          style: GoogleFonts.plusJakartaSans(
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
                                              style: GoogleFonts.plusJakartaSans(
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

                                  // Info Details Button
                                  IconButton(
                                    icon: const Icon(
                                      Icons.info_outline_rounded,
                                      size: 20,
                                      color: Color(0xFF64748B),
                                    ),
                                    tooltip: 'Entrance details',
                                    visualDensity: VisualDensity.compact,
                                    splashRadius: 18,
                                    onPressed: () {
                                      HapticFeedback.selectionClick();
                                      EntranceDetailSheet.show(context, entrance);
                                    },
                                  ),
                                  const SizedBox(width: 4),

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
                    onPressed: isClearAction
                        ? _clearSelection
                        : (effectiveSelected != null ? _confirmSelection : null),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isClearAction
                          ? const Color(0xFFFEF2F2)
                          : (effectiveSelected != null
                              ? AppColors.primary
                              : const Color(0xFFE2E8F0)),
                      disabledBackgroundColor: const Color(0xFFE2E8F0),
                      foregroundColor: isClearAction
                          ? const Color(0xFFDC2626)
                          : (effectiveSelected != null
                              ? Colors.white
                              : const Color(0xFF94A3B8)),
                      disabledForegroundColor: const Color(0xFF94A3B8),
                      elevation: isClearAction
                          ? 0
                          : (effectiveSelected != null ? 1 : 0),
                      side: isClearAction
                          ? const BorderSide(
                              color: Color(0xFFFECACA),
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
                          isClearAction
                              ? Icons.clear_rounded
                              : Icons.directions_walk_rounded,
                          size: 19,
                          color: isClearAction
                              ? const Color(0xFFDC2626)
                              : (effectiveSelected != null
                                  ? Colors.white
                                  : const Color(0xFF94A3B8)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isClearAction
                              ? 'Clear Selected Entrance'
                              : (effectiveSelected != null
                                  ? 'Select Starting Entrance • Gate ${effectiveSelected.entranceId}'
                                  : 'Select Starting Entrance'),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isClearAction
                                ? const Color(0xFFDC2626)
                                : (effectiveSelected != null
                                    ? Colors.white
                                    : const Color(0xFF94A3B8)),
                          ),
                        ),
                        if (!isClearAction && effectiveSelected != null) ...[
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

  /// Action banner to switch to full-screen map entrance picking mode
  Widget _buildPickOnMapBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: _triggerPickOnMap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF86EFAC),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.map_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pick on the Map',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF14532D),
                        ),
                      ),
                      Text(
                        'Zoom out to view and tap all 14 gates',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF166534),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Pick',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.touch_app_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

