import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/navigation_models.dart';
import '../../providers/navigation_provider.dart';

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
      backgroundColor: Colors.transparent,
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
    final nearestEntrance = (widget.targetStallId != null && service.isInitialized)
        ? service.findNearestEntranceByWalkingDistance(widget.targetStallId!)
        : null;
    final effectiveSelected = _selectedEntrance;

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
        maxHeight: MediaQuery.of(context).size.height * 0.80,
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

            // Search filter field
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8E2)),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A241A),
                ),
                decoration: InputDecoration(
                  hintText: 'Search by gate number or landmark...',
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF9E9E9E),
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF667066),
                    size: 18,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.cancel_rounded, size: 16),
                          color: const Color(0xFF667066),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 9),
                ),
              ),
            ),

            const Divider(color: AppColors.border, height: 1),

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
                                        color: const Color(0xFF1B5E20)
                                            .withValues(alpha: 0.08),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                // Bespoke Gate Map Pin Badge (Red by default, Green when chosen)
                                Container(
                                  width: 58,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary
                                        : const Color(0xFFFFF5F5),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : const Color(0xFFFFCDD2),
                                      width: 1.4,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.location_on_rounded,
                                        size: 24,
                                        color: isSelected
                                            ? Colors.white
                                            : const Color(0xFFE53935),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        'Gate ${entrance.entranceId}',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: isSelected
                                              ? Colors.white
                                              : const Color(0xFFC62828),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Gate Landmark & Zone Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entrance.description,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                          color: isSelected
                                              ? AppColors.primary
                                              : const Color(0xFF1A241A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _getLandmarkContext(
                                            entrance.entranceId),
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w400,
                                          color: isSelected
                                              ? const Color(0xFF2E7D32)
                                              : AppColors.inkMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Shortest Walk Badge & Radio Selection Indicator
                                if (isNearest) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8F5E9),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: const Color(0xFF81C784),
                                        width: 0.9,
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.bolt_rounded,
                                          size: 13,
                                          color: Color(0xFF1B5E20),
                                        ),
                                        SizedBox(width: 2),
                                        Text(
                                          'Shortest',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF1B5E20),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                ],

                                // Selection Checkmark / Radio
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
}

