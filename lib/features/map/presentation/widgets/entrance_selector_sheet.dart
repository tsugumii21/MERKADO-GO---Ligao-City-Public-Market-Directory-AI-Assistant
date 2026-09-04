import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/navigation_models.dart';
import '../../providers/navigation_provider.dart';

/// Bottom sheet modal for selecting starting market entrance
class EntranceSelectorSheet extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final entryPoints = ref.watch(entryPointsProvider);
    final selectedEntrance = ref.watch(selectedEntranceProvider);
    final service = ref.watch(pathfindingServiceProvider);
    final nearestEntrance = (targetStallId != null && service.isInitialized)
        ? service.findNearestEntranceByWalkingDistance(targetStallId!)
        : null;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.sheetRadius),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Starting Entrance',
                        style: AppTextStyles.cardTitle,
                      ),
                      Text(
                        targetStallName != null
                            ? 'Where are you entering to reach $targetStallName?'
                            : 'Where are you entering the market from?',
                        style: AppTextStyles.caption,
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
                ),
              ],
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
          else
            Flexible(
              child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              itemCount: entryPoints.length,
              separatorBuilder: (_, __) =>
                  const Divider(color: AppColors.borderLight, height: 1),
              itemBuilder: (context, index) {
                final entrance = entryPoints[index];
                final isSelected = selectedEntrance?.entranceId == entrance.entranceId;

                final isNearest =
                    nearestEntrance?.entranceId == entrance.entranceId;

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                  ),
                  tileColor: isSelected ? AppColors.surfaceDim : Colors.transparent,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFE53935)
                          : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFC62828)
                            : const Color(0xFFEF4444).withValues(alpha: 0.3),
                        width: 1.5,
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
                          size: 18,
                        ),
                        Text(
                          'Gate ${entrance.entranceId}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFFB91C1C),
                          ),
                        ),
                      ],
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          entrance.description,
                          style: AppTextStyles.body.copyWith(
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? AppColors.primary : AppColors.ink,
                          ),
                        ),
                      ),
                      if (isNearest) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFF4CAF50).withValues(alpha: 0.4),
                              width: 1,
                            ),
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
                  trailing: isSelected
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primary,
                          size: 22,
                        )
                      : null,
                  onTap: () {
                    ref.read(selectedEntranceProvider.notifier).state = entrance;

                    // If route is active and we are just changing entrance from the map card
                    final activeRoute = ref.read(activeRouteProvider);
                    if (activeRoute != null && targetStallId == null) {
                      ref.read(activeRouteProvider.notifier).navigateToStall(
                            stallId: activeRoute.destinationStallId,
                            stallName: activeRoute.destinationStallName,
                            entranceOverride: entrance,
                          );
                    }

                    onEntranceSelected?.call(entrance);
                    Navigator.of(context).pop(entrance);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
