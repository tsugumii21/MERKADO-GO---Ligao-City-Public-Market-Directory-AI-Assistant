import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/stall_model.dart';
import '../../../providers/stall_provider.dart';
import '../../map/domain/navigation_models.dart';
import '../../map/presentation/widgets/entrance_selector_sheet.dart';
import '../../map/presentation/widgets/interactive_market_map.dart';
import '../../map/presentation/widgets/map_search_modal.dart';
import '../../map/presentation/widgets/route_navigation_card.dart';
import '../../map/providers/navigation_provider.dart';
import '../../map/providers/search_provider.dart';
import '../../stalls/presentation/stall_detail_sheet.dart';

/// Admin Map Screen with interactive vector map, pathfinding navigation, search, and stall inspection.
/// Designed for administrators with a clean, focused UI (no floating chatbots or non-standard emojis).
class AdminMapScreen extends ConsumerStatefulWidget {
  const AdminMapScreen({super.key});

  @override
  ConsumerState<AdminMapScreen> createState() => _AdminMapScreenState();
}

class _AdminMapScreenState extends ConsumerState<AdminMapScreen> {
  StallModel? _selectedStall;

  @override
  void initState() {
    super.initState();
    // Pre-initialize graph pathfinding engine & search directory
    ref.read(pathfindingInitProvider);
    ref.read(marketSearchInitProvider);
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
        ],
      ),
    );
  }

  Widget _buildTopSearchAndEntranceBar(MarketEntryPoint? selectedEntrance) {
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
              Container(
                height: 24,
                width: 1,
                color: AppColors.border,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
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
}
