import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/stall_model.dart';
import '../../../providers/stall_provider.dart';
import '../../map/presentation/widgets/interactive_market_map.dart';
import '../../map/presentation/widgets/map_search_dropdown.dart';
import '../../map/providers/search_provider.dart';
import '../../stalls/presentation/stall_detail_sheet.dart';

/// Admin Map Screen with interactive vector map, search, and stall inspection/editing.
/// Designed for administrators with a clean, focused UI without customer navigation routes.
class AdminMapScreen extends ConsumerStatefulWidget {
  const AdminMapScreen({super.key});

  @override
  ConsumerState<AdminMapScreen> createState() => _AdminMapScreenState();
}

class _AdminMapScreenState extends ConsumerState<AdminMapScreen> {
  StallModel? _selectedStall;
  bool _isSearchDropdownOpen = false;

  @override
  void initState() {
    super.initState();
    // Pre-initialize search directory
    ref.read(marketSearchInitProvider);
  }

  @override
  Widget build(BuildContext context) {
    final stallsAsync = ref.watch(allStallsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Interactive Vector Map Layer
          stallsAsync.when(
            data: (stalls) => InteractiveMarketMap(
              stalls: stalls,
              selectedStall: _selectedStall,
              onStallSelected: (stall) {
                setState(() => _selectedStall = stall);
                StallDetailSheet.show(context, stall, isAdmin: true);
              },
              onMapTapped: () {
                if (_isSearchDropdownOpen) {
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
                  setState(() => _isSearchDropdownOpen = false);
                },
              ),
            ),

          // 2. Top Header Overlay (Search Bar)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: _buildTopSearchBar(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: MapSearchDropdown(
        isOpen: _isSearchDropdownOpen,
        showEntrance: false,
        onOpenChanged: (isOpen) {
          setState(() => _isSearchDropdownOpen = isOpen);
        },
        onStallSelected: (stall) {
          setState(() {
            _selectedStall = stall;
            _isSearchDropdownOpen = false;
          });
          StallDetailSheet.show(context, stall, isAdmin: true);
        },
      ),
    );
  }
}
