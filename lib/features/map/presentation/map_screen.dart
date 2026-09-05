import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/stall_model.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/stall_provider.dart';
import '../../chat/presentation/aling_suki_chat_screen.dart';
import '../../stalls/presentation/stall_detail_sheet.dart';
import '../providers/navigation_provider.dart';
import '../providers/search_provider.dart';
import 'widgets/entrance_selector_sheet.dart';
import 'widgets/interactive_market_map.dart';
import 'widgets/map_search_modal.dart';
import 'widgets/route_navigation_card.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => MapScreenState();
}

class MapScreenState extends ConsumerState<MapScreen> {
  bool _isChatOpen = false;
  StallModel? _selectedStall;
  bool _isPickingEntranceOnMap = false;

  @override
  void initState() {
    super.initState();
    // Pre-initialize graph pathfinding engine & search directory
    ref.read(pathfindingInitProvider);
    ref.read(marketSearchInitProvider);
  }

  void resetUI() {
    if (!mounted) return;
    _isPickingEntranceOnMap = false;
    if (_isChatOpen) {

      setState(() => _isChatOpen = false);
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stallsAsync = ref.watch(allStallsProvider);
    final activeRoute = ref.watch(activeRouteProvider);
    final selectedEntrance = ref.watch(selectedEntranceProvider);
    final entryPoints = ref.watch(entryPointsProvider);
    final traversalTrigger = ref.watch(routeTraversalTriggerProvider);

    return PopScope(
      canPop: !_isPickingEntranceOnMap,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isPickingEntranceOnMap) {
          setState(() => _isPickingEntranceOnMap = false);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // 1. Interactive Vector Map Layer
            stallsAsync.when(
              data: (stalls) => InteractiveMarketMap(
                stalls: stalls,
                selectedStall: _selectedStall,
                activeRoute: activeRoute,
                entryPoints: entryPoints,
                selectedEntrance: selectedEntrance,
                showEntrancePins: _isPickingEntranceOnMap,
                traversalTrigger: traversalTrigger,
                onStallSelected: (stall) {
                  if (_isPickingEntranceOnMap) return;
                  setState(() => _selectedStall = stall);
                  StallDetailSheet.show(context, stall);
                },
                onEntranceTapped: (entrance) {
                  final current = ref.read(selectedEntranceProvider);
                  HapticFeedback.selectionClick();
                  if (_isPickingEntranceOnMap) {
                    ref.read(selectedEntranceProvider.notifier).state = entrance;
                    setState(() => _isPickingEntranceOnMap = false);
                    final activeRoute = ref.read(activeRouteProvider);
                    if (activeRoute != null) {
                      ref.read(activeRouteProvider.notifier).navigateToStall(
                            stallId: activeRoute.destinationStallId,
                            entranceOverride: entrance,
                          );
                    }
                    return;
                  }
                  if (current?.entranceId == entrance.entranceId) {
                    // Gate pressed again: unchoose/deselect it
                    ref.read(selectedEntranceProvider.notifier).state = null;
                    final activeRoute = ref.read(activeRouteProvider);
                    if (activeRoute != null) {
                      ref.read(activeRouteProvider.notifier).clearRoute();
                    }
                  } else {
                    // Gate chosen: select it and recalculate active route if navigating
                    ref.read(selectedEntranceProvider.notifier).state = entrance;
                    final activeRoute = ref.read(activeRouteProvider);
                    if (activeRoute != null) {
                      ref.read(activeRouteProvider.notifier).navigateToStall(
                            stallId: activeRoute.destinationStallId,
                            entranceOverride: entrance,
                          );
                    }
                  }
                },
                onMapTapped: () {
                  if (_isPickingEntranceOnMap) return;
                  if (_selectedStall != null) {
                    setState(() => _selectedStall = null);
                  }
                },
              ),
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.error,
                        size: 40,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Failed to load market stalls',
                        style: AppTextStyles.cardTitle,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Please check your internet connection and try again.',
                        style: AppTextStyles.caption,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 2. Top Header (Search & Entrance Bar OR Picking Mode Guidance Banner)
            if (activeRoute == null)
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: _isPickingEntranceOnMap
                        ? _buildPickingEntranceBanner()
                        : _buildTopSearchAndEntranceBar(selectedEntrance),
                  ),
                ),
              ),

            // 3. Bottom Navigation Guidance Card (Two-State: Minimized bar or Expanded sheet)
            if (activeRoute != null)
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: RouteNavigationCard(
                      route: activeRoute,
                      onChangeEntrance: () =>
                          EntranceSelectorSheet.show(context),
                      onRepeatRoute: () {
                        ref.read(routeTraversalTriggerProvider.notifier).state++;
                      },
                      onClose: () {
                        ref.read(activeRouteProvider.notifier).clearRoute();
                      },
                    ),
                  ),
                ),
              ),

            // 4. Floating Aling Suki Avatar Button (Hidden during active navigation or picking mode)
            if (activeRoute == null && !_isPickingEntranceOnMap)

            Positioned(
              left: 16,
              bottom: 24,
              child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white,
                      width: 2.5,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() => _isChatOpen = true);
                        _showAlingSukiOverlay();
                      },
                      borderRadius: BorderRadius.circular(26),
                      child: const Center(
                        child: CircleAvatar(
                          backgroundColor: Colors.white,
                          backgroundImage:
                              AssetImage('assets/images/aling_suki.png'),
                          radius: 23,
                        ),
                      ),
                    ),
                  ),
                ),

                // Unread indicator dot
                if (!_isChatOpen && ref.watch(chatProvider).length > 1)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}


  Widget _buildTopSearchAndEntranceBar(selectedEntrance) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Material(
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 4,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => MapSearchModal.show(context),
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        color: AppColors.inkMuted,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Search stalls, fish, meat...',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.inkMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                height: 24,
                width: 1,
                color: AppColors.border,
                margin: const EdgeInsets.symmetric(horizontal: 8),
              ),
              InkWell(
                onTap: () async {
                  final result = await EntranceSelectorSheet.show(context);
                  if (result == 'pick_on_map') {
                    setState(() {
                      _isPickingEntranceOnMap = true;
                      _selectedStall = null;
                    });
                  }
                },
                borderRadius: BorderRadius.circular(AppSpacing.xs),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        color: selectedEntrance != null
                            ? AppColors.primary
                            : const Color(0xFFE53935),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        selectedEntrance != null
                            ? 'Gate ${selectedEntrance.entranceId}'
                            : 'Entrance',
                        style: AppTextStyles.captionSmall.copyWith(
                          color: selectedEntrance != null
                              ? AppColors.primary
                              : AppColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_drop_down_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickingEntranceBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Material(
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        color: const Color(0xFF1B5E20),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: const Color(0xFF81C784), width: 1.2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.touch_app_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tap any gate pin on the map to set entrance',
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isPickingEntranceOnMap = false);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  void _showAlingSukiOverlay() {
    AlingSukiChatScreen.show(context).then((_) {
      if (mounted) {
        setState(() {
          _isChatOpen = false;
        });
      }
    });
  }
}
