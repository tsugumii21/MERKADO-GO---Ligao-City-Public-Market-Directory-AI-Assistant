import 'dart:async';

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
    ref.read(selectedOriginStallProvider.notifier).state = null;
    if (_isChatOpen) {
      setState(() => _isChatOpen = false);
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  /// Handles hardware/system back button presses on the Map tab.
  /// Returns `true` if an internal state was cancelled/handled (preventing app exit).
  bool handleBackPressed() {
    if (!mounted) return false;

    // 1. Cancel active stall-to-stall origin picker
    if (ref.read(pickingOriginTargetStallProvider) != null) {
      ref.read(pickingOriginTargetStallProvider.notifier).state = null;
      ref.read(selectedOriginStallProvider.notifier).state = null;
      return true;
    }

    // 2. Clear active navigation route
    if (ref.read(activeRouteProvider) != null) {
      ref.read(activeRouteProvider.notifier).clearRoute();
      return true;
    }

    // 3. Exit gate/entrance picking mode on map
    if (_isPickingEntranceOnMap) {
      setState(() => _isPickingEntranceOnMap = false);
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final stallsAsync = ref.watch(allStallsProvider);
    final activeRoute = ref.watch(activeRouteProvider);
    final selectedEntrance = ref.watch(selectedEntranceProvider);
    final entryPoints = ref.watch(entryPointsProvider);
    final traversalTrigger = ref.watch(routeTraversalTriggerProvider);
    final pickingOriginTargetStall = ref.watch(pickingOriginTargetStallProvider);
    final selectedOriginStall = ref.watch(selectedOriginStallProvider);

    return Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // 1. Interactive Vector Map Layer
            stallsAsync.when(
              data: (stalls) => InteractiveMarketMap(
                stalls: stalls,
                selectedStall: pickingOriginTargetStall ?? _selectedStall,
                selectedOriginStall: selectedOriginStall,
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
                            'You are already navigating to ${stall.name}. Choose a different starting stall.',
                            style: GoogleFonts.poppins(fontSize: 12.5),
                          ),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: AppColors.ink,
                        ),
                      );
                      return;
                    }

                    unawaited(HapticFeedback.selectionClick());

                    // Pop up StallDetailSheet so user can review details and tap confirm
                    setState(() => _selectedStall = stall);
                    await StallDetailSheet.show(context, stall);
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

            // 2. Top Header (Direction Card in Navigation or Picking Mode, else Search Bar)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: activeRoute != null
                      ? _buildActiveNavigationDirectionHeader(activeRoute)
                      : (pickingOriginTargetStall != null
                          ? _buildPickingStallOriginHeader(
                              pickingOriginTargetStall,
                              selectedOriginStall,
                            )
                          : (_isPickingEntranceOnMap
                              ? _buildPickingEntranceBanner()
                              : _buildTopSearchAndEntranceBar(selectedEntrance))),
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

  Widget _buildPickingStallOriginHeader(
    StallModel targetStall,
    StallModel? selectedOriginStall,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.14),
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left: Waypoint Track (Green circle -> 20px line -> Red pin)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
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
                        height: 20,
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
                  const SizedBox(width: 10),

                  // Middle: Origin & Destination Inputs
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Origin Field (Tap to search or pick)
                        Material(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            onTap: () async {
                              unawaited(HapticFeedback.selectionClick());
                              if (!mounted) return;
                              final result = await StallOriginPickerSheet.show(
                                context,
                                targetStallId: targetStall.stallId,
                                targetStallName: targetStall.name,
                              );
                              if (!mounted || result == null) return;
                              if (result == 'pick_on_map') {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Tap any stall on the map to set your starting point.',
                                      style: GoogleFonts.poppins(fontSize: 12.5),
                                    ),
                                    duration: const Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: AppColors.primary,
                                  ),
                                );
                                return;
                              }
                              if (result is! StallModel) return;
                              setState(() => _selectedStall = result);
                              await StallDetailSheet.show(context, result);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 38),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: selectedOriginStall != null
                                      ? const Color(0xFF81C784)
                                      : const Color(0xFFE2E8F0),
                                  width: selectedOriginStall != null ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      selectedOriginStall != null
                                          ? 'From: ${selectedOriginStall.name}'
                                          : 'Tap map or search starting stall...',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12.5,
                                        fontWeight: selectedOriginStall != null
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: selectedOriginStall != null
                                            ? AppColors.ink
                                            : const Color(0xFF64748B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(
                                    selectedOriginStall != null
                                        ? Icons.edit_rounded
                                        : Icons.search_rounded,
                                    size: 16,
                                    color: const Color(0xFF1B5E20),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Destination Field (Tappable to redirect)
                        Material(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            onTap: () async {
                              await HapticFeedback.selectionClick();
                              if (!mounted) return;
                              final newTarget = await StallOriginPickerSheet.show(
                                context,
                                targetStallId: targetStall.stallId,
                                targetStallName: targetStall.name,
                                title: 'Change Destination Stall',
                                subtitle: 'Choose where you want to go',
                              );
                              if (!mounted || newTarget == null) return;
                              if (newTarget == 'pick_on_map') {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Tap any stall on the map to set destination.',
                                      style: GoogleFonts.poppins(fontSize: 12.5),
                                    ),
                                    duration: const Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: AppColors.primary,
                                  ),
                                );
                                return;
                              }
                              if (newTarget is! StallModel) return;
                              ref.read(pickingOriginTargetStallProvider.notifier).state = newTarget;
                              setState(() => _selectedStall = newTarget);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 38),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'To: ${targetStall.name}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.ink,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.edit_location_alt_rounded,
                                    size: 16,
                                    color: Color(0xFFE53935),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Right Action Column: Close [✕] & Reverse [⇅]
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Close Button [✕]
                      InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref.read(pickingOriginTargetStallProvider.notifier).state = null;
                          ref.read(selectedOriginStallProvider.notifier).state = null;
                        },
                        borderRadius: BorderRadius.circular(15),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFF64748B),
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Reverse Location Button [⇅]
                      InkWell(
                        onTap: selectedOriginStall == null
                            ? null
                            : () {
                                HapticFeedback.selectionClick();
                                final oldTarget = targetStall;
                                final oldOrigin = selectedOriginStall;
                                ref.read(pickingOriginTargetStallProvider.notifier).state = oldOrigin;
                                ref.read(selectedOriginStallProvider.notifier).state = oldTarget;
                                setState(() => _selectedStall = oldOrigin);
                              },
                        borderRadius: BorderRadius.circular(15),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: selectedOriginStall != null
                                ? const Color(0xFFE8F5E9)
                                : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.swap_vert_rounded,
                            color: selectedOriginStall != null
                                ? const Color(0xFF1B5E20)
                                : const Color(0xFFCBD5E1),
                            size: 17,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Start Navigation button when origin is selected (Clean Material button, zero clipping)
              if (selectedOriginStall != null) ...[
                const SizedBox(height: 10),
                Material(
                  color: const Color(0xFF1B5E20),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: () async {
                      await HapticFeedback.mediumImpact();
                      final origin = selectedOriginStall;
                      final target = targetStall;

                      if (!mounted) return;
                      await NavigationLoadingDialog.show(
                        context,
                        stallName: target.name,
                        originName: origin.name,
                      );
                      if (!mounted) return;

                      await ref.read(activeRouteProvider.notifier).navigateStallToStall(
                            originStallId: origin.stallId,
                            destinationStallId: target.stallId,
                            originStallName: origin.name,
                            destinationStallName: target.name,
                          );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 42,
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.navigation_rounded,
                            color: Colors.white,
                            size: 17,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Start Navigation',
                            style: GoogleFonts.poppins(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveNavigationDirectionHeader(NavigationRoute route) {
    final originLabel = route.originType == NavigationOriginType.stall
        ? 'From: ${route.originStallName ?? "Starting Stall"}'
        : 'From Gate ${route.entrance?.entranceId ?? ""}: ${route.entrance?.description ?? ""}';

    final canReverse = route.originType == NavigationOriginType.stall &&
        route.originStallId != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.14),
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: Waypoint Track (Green dot -> 20px line -> Red pin)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
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
                    height: 20,
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
              const SizedBox(width: 10),

              // Middle: Origin & Destination fields (Both interactive for redirection!)
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Origin Row (Tap to change starting point)
                    Material(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: () async {
                          unawaited(HapticFeedback.selectionClick());
                          if (!mounted) return;
                          if (route.originType == NavigationOriginType.stall) {
                            final result = await StallOriginPickerSheet.show(
                              context,
                              targetStallId: route.destinationStallId,
                              targetStallName: route.destinationStallName,
                              title: 'Change Starting Stall',
                              subtitle: 'Choose where you are currently standing',
                            );
                            if (!mounted || result == null) return;
                            if (result == 'pick_on_map') {
                              final allStalls = ref.read(allStallsProvider).asData?.value ?? [];
                              StallModel? destStall;
                              for (final s in allStalls) {
                                if (s.stallId == route.destinationStallId) {
                                  destStall = s;
                                  break;
                                }
                              }
                              if (destStall != null) {
                                ref.read(pickingOriginTargetStallProvider.notifier).state = destStall;
                                ref.read(selectedOriginStallProvider.notifier).state = null;
                                ref.read(activeRouteProvider.notifier).clearRoute();
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Tap any stall on the map to select starting point.',
                                    style: GoogleFonts.poppins(fontSize: 12.5),
                                  ),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: AppColors.primary,
                                ),
                              );
                              return;
                            }
                            if (result is! StallModel) return;
                            setState(() => _selectedStall = result);
                            await StallDetailSheet.show(
                              context,
                              result,
                              isChangingOrigin: true,
                            );
                          } else {
                            final result = await EntranceSelectorSheet.show(
                              context,
                              targetStallId: route.destinationStallId,
                            );
                            if (result == 'pick_on_map') {
                              setState(() {
                                _isPickingEntranceOnMap = true;
                              });
                            }
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 38),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  originLabel,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(
                                Icons.alt_route_rounded,
                                size: 16,
                                color: Color(0xFF1B5E20),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Destination Row (Tap to redirect to another stall, preserving origin!)
                    Material(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: () async {
                          unawaited(HapticFeedback.selectionClick());
                          if (!mounted) return;
                          // Pick replacement destination stall
                          final result = await StallOriginPickerSheet.show(
                            context,
                            targetStallId: route.destinationStallId,
                            targetStallName: route.destinationStallName,
                            title: 'Redirect to Stall',
                            subtitle: 'Choose a new destination to navigate to',
                          );
                          if (!mounted || result == null) return;
                          if (result == 'pick_on_map') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Tap any stall on the map to redirect your route.',
                                  style: GoogleFonts.poppins(fontSize: 12.5),
                                ),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: AppColors.primary,
                              ),
                            );
                            return;
                          }
                          if (result is! StallModel) return;

                          // Pop up StallDetailSheet so user can review details and tap confirm
                          setState(() => _selectedStall = result);
                          await StallDetailSheet.show(context, result);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 38),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'To: ${route.destinationStallName}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(
                                Icons.search_rounded,
                                size: 16,
                                color: Color(0xFFE53935),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Right Action Column: Close [✕] & Reverse [⇅]
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Close Button [✕] (End Navigation)
                  InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(activeRouteProvider.notifier).clearRoute();
                    },
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF64748B),
                        size: 16,
                      ),
                    ),
                  ),
                  if (canReverse) ...[
                    const SizedBox(height: 6),
                    // Reverse Location Button [⇅]
                    InkWell(
                      onTap: () async {
                        unawaited(HapticFeedback.selectionClick());
                        final oldDestId = route.destinationStallId;
                        final oldDestName = route.destinationStallName;
                        final oldOriginId = route.originStallId!;
                        final oldOriginName = route.originStallName;

                        await NavigationLoadingDialog.show(
                          context,
                          stallName: oldOriginName ?? 'Stall',
                          originName: oldDestName,
                        );
                        if (!mounted) return;

                        await ref.read(activeRouteProvider.notifier).navigateStallToStall(
                              originStallId: oldDestId,
                              destinationStallId: oldOriginId,
                              originStallName: oldDestName,
                              destinationStallName: oldOriginName,
                            );
                      },
                      borderRadius: BorderRadius.circular(15),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE8F5E9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.swap_vert_rounded,
                          color: Color(0xFF1B5E20),
                          size: 17,
                        ),
                      ),
                    ),
                  ],
                ],
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
