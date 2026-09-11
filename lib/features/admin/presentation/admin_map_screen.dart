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
import '../../map/presentation/widgets/map_search_dropdown.dart';
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
  bool _isSearchDropdownOpen = false;
  final GlobalKey<MapSearchDropdownState> _searchDropdownKey =
      GlobalKey<MapSearchDropdownState>();

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
              selectedEntrance: selectedEntrance,
              onStallSelected: (stall) {
                setState(() => _selectedStall = stall);
                StallDetailSheet.show(context, stall);
              },
              onEntranceTapped: (entrance) {
                EntranceSelectorSheet.show(context);
              },
              onMapTapped: () {
                if (_isSearchDropdownOpen) {
                  _searchDropdownKey.currentState?.close();
                  setState(() => _isSearchDropdownOpen = false);
                }
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

          // Tap-outside backdrop scrim to dismiss search dropdown
          if (_isSearchDropdownOpen)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  _searchDropdownKey.currentState?.close();
                  setState(() => _isSearchDropdownOpen = false);
                },
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
      child: MapSearchDropdown(
        key: _searchDropdownKey,
        isOpen: _isSearchDropdownOpen,
        selectedEntrance: selectedEntrance,
        onOpenChanged: (isOpen) {
          setState(() => _isSearchDropdownOpen = isOpen);
        },
        onEntranceTap: () => EntranceSelectorSheet.show(context),
        onStallSelected: (stall) {
          setState(() {
            _selectedStall = stall;
            _isSearchDropdownOpen = false;
          });
          StallDetailSheet.show(context, stall);
        },
      ),
    );
  }
}
