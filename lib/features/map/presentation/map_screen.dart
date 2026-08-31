import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    // Pre-initialize graph pathfinding engine & search directory
    ref.read(pathfindingInitProvider);
    ref.read(marketSearchInitProvider);
  }

  void resetUI() {
    if (!mounted) return;
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

    return Scaffold(
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
              onStallSelected: (stall) {
                setState(() => _selectedStall = stall);
                StallDetailSheet.show(context, stall);
              },
              onEntranceTapped: (entrance) {
                EntranceSelectorSheet.show(context);
              },
              onMapTapped: () {
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

          // 2. Top Header Overlay (Active Route Card OR Search & Entrance Bar)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: activeRoute != null
                  ? RouteNavigationCard(
                      route: activeRoute,
                      onChangeEntrance: () =>
                          EntranceSelectorSheet.show(context),
                      onClose: () {
                        ref.read(activeRouteProvider.notifier).clearRoute();
                      },
                    )
                  : _buildTopSearchAndEntranceBar(selectedEntrance),
            ),
          ),

          // 3. Floating Aling Suki Chat Button
          Positioned(
            right: 16,
            bottom: 60,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Chat bubble callout
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B5E20),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        size: 14,
                        color: Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Ask Aling Suki',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // Floating Action Button
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF1B5E20).withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() => _isChatOpen = true);
                            _showAlingSukiOverlay();
                          },
                          borderRadius: BorderRadius.circular(28),
                          child: const Center(
                            child: CircleAvatar(
                              backgroundColor: Colors.transparent,
                              backgroundImage:
                                  AssetImage('assets/images/aling_suki.png'),
                              radius: 24,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Unread indicator dot
                    if (!_isChatOpen && ref.watch(chatProvider).length > 1)
                      Positioned(
                        top: 2,
                        right: 2,
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
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
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
                        size: 22,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Search 134 stalls, fish, meat...',
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
              const VerticalDivider(
                color: AppColors.border,
                width: 16,
                indent: 4,
                endIndent: 4,
              ),
              InkWell(
                onTap: () => EntranceSelectorSheet.show(context),
                borderRadius: BorderRadius.circular(AppSpacing.xs),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.door_front_door_rounded,
                        color: AppColors.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        selectedEntrance != null
                            ? 'Gate ${selectedEntrance.entranceId}'
                            : 'Entrance',
                        style: AppTextStyles.captionSmall.copyWith(
                          color: AppColors.primary,
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
