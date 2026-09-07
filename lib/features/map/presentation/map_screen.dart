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
import '../domain/navigation_models.dart';
import '../providers/navigation_provider.dart';
import '../providers/search_provider.dart';
import 'widgets/entrance_selector_sheet.dart';
import 'widgets/interactive_market_map.dart';
import 'widgets/map_search_modal.dart';
import 'widgets/navigation_loading_dialog.dart';
import 'widgets/navigation_origin_sheet.dart';
import 'widgets/route_navigation_card.dart';
import 'widgets/stall_origin_picker_sheet.dart';

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
    ref.read(pickingOriginTargetStallProvider.notifier).state = null;
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
    final pickingOriginTargetStall = ref.watch(pickingOriginTargetStallProvider);

    return PopScope(
      canPop: !_isPickingEntranceOnMap && pickingOriginTargetStall == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (pickingOriginTargetStall != null) {
            ref.read(pickingOriginTargetStallProvider.notifier).state = null;
          } else if (_isPickingEntranceOnMap) {
            setState(() => _isPickingEntranceOnMap = false);
          }
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
                selectedStall: pickingOriginTargetStall ?? _selectedStall,
                activeRoute: activeRoute,
                entryPoints: entryPoints,
                selectedEntrance: selectedEntrance,
                showEntrancePins: _isPickingEntranceOnMap,
                traversalTrigger: traversalTrigger,
                onStallSelected: (stall) async {
                  if (_isPickingEntranceOnMap) return;

                  if (pickingOriginTargetStall != null) {
                    if (stall.stallId == pickingOriginTargetStall.stallId) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'You are already at ${stall.name}. Choose a different starting stall.',
                            style: GoogleFonts.poppins(fontSize: 12.5),
                          ),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: AppColors.ink,
                        ),
                      );
                      return;
                    }

                    final target = pickingOriginTargetStall;
                    ref.read(pickingOriginTargetStallProvider.notifier).state = null;

                    await NavigationLoadingDialog.show(
                      context,
                      stallName: target.name,
                      originName: stall.name,
                    );
                    if (!mounted) return;

                    await ref.read(activeRouteProvider.notifier).navigateStallToStall(
                          originStallId: stall.stallId,
                          destinationStallId: target.stallId,
                          originStallName: stall.name,
                          destinationStallName: target.name,
                        );
                    return;
                  }

                  setState(() => _selectedStall = stall);
                  await StallDetailSheet.show(context, stall);
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
                  if (pickingOriginTargetStall != null) return;
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
                    child: pickingOriginTargetStall != null
                        ? _buildPickingStallOriginHeader(pickingOriginTargetStall)
                        : (_isPickingEntranceOnMap
                            ? _buildPickingEntranceBanner()
                            : _buildTopSearchAndEntranceBar(selectedEntrance)),
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
                      onChangeEntrance: () async {
                        if (activeRoute.originType == NavigationOriginType.stall) {
                          final originResult = await NavigationOriginSheet.show(
                            context,
                            targetStallId: activeRoute.destinationStallId,
                            targetStallName: activeRoute.destinationStallName,
                          );
                          if (originResult == null || !mounted) return;
                          if (originResult is EntranceOriginResult) {
                            await ref.read(activeRouteProvider.notifier).navigateToStall(
                                  stallId: activeRoute.destinationStallId,
                                  stallName: activeRoute.destinationStallName,
                                  entranceOverride: originResult.entrance,
                                );
                          } else if (originResult is StallOriginResult) {
                            await ref.read(activeRouteProvider.notifier).navigateStallToStall(
                                  originStallId: originResult.stall.stallId,
                                  destinationStallId: activeRoute.destinationStallId,
                                  originStallName: originResult.stall.name,
                                  destinationStallName: activeRoute.destinationStallName,
                                );
                          }
                        } else {
                          await EntranceSelectorSheet.show(context);
                        }
                      },
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
            if (activeRoute == null && !_isPickingEntranceOnMap && pickingOriginTargetStall == null)

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

  Widget _buildPickingStallOriginHeader(StallModel targetStall) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Material(
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.20),
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: Google Maps Waypoint track (Green circle -> line -> Red pin)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1.5,
                    height: 16,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: const Color(0xFFCBD5E1),
                  ),
                  const Icon(
                    Icons.location_on_rounded,
                    color: Color(0xFFE53935),
                    size: 15,
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Middle: Origin input & Destination label
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Origin row: Tap on map hint or tap to open search
                    Material(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: () async {
                          await HapticFeedback.selectionClick();
                          if (!mounted) return;
                          final stall = await StallOriginPickerSheet.show(
                            context,
                            targetStallId: targetStall.stallId,
                            targetStallName: targetStall.name,
                          );
                          if (stall == null || !mounted) return;
                          ref.read(pickingOriginTargetStallProvider.notifier).state = null;
                          await NavigationLoadingDialog.show(
                            context,
                            stallName: targetStall.name,
                            originName: stall.name,
                          );
                          if (!mounted) return;
                          await ref.read(activeRouteProvider.notifier).navigateStallToStall(
                                originStallId: stall.stallId,
                                destinationStallId: targetStall.stallId,
                                originStallName: stall.name,
                                destinationStallName: targetStall.name,
                              );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Tap map or search starting stall...',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(
                                Icons.search_rounded,
                                size: 16,
                                color: Color(0xFF1B5E20),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Destination row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        'To: ${targetStall.name}',
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Cancel button [✕]
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(pickingOriginTargetStallProvider.notifier).state = null;
                },
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF64748B),
                    size: 18,
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
