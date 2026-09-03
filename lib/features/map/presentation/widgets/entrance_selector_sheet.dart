import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/cloudinary_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/navigation_models.dart';
import '../../providers/navigation_provider.dart';

/// Bottom sheet modal for selecting starting market entrance
class EntranceSelectorSheet extends ConsumerWidget {
  final ValueChanged<MarketEntryPoint>? onEntranceSelected;

  const EntranceSelectorSheet({
    super.key,
    this.onEntranceSelected,
  });

  static Future<MarketEntryPoint?> show(BuildContext context) {
    return showModalBottomSheet<MarketEntryPoint>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const EntranceSelectorSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryPoints = ref.watch(entryPointsProvider);
    final selectedEntrance = ref.watch(selectedEntranceProvider);

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
                        'Where are you entering the market from?',
                        style: AppTextStyles.caption,
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
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                    ),
                    clipBehavior: Clip.antiAlias,
                    alignment: Alignment.center,
                    child: Image.network(
                      CloudinaryService.getEntrancePhotoUrl(entrance.entranceId),
                      fit: BoxFit.cover,
                      width: 40,
                      height: 40,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          '#${entrance.entranceId}',
                          style: AppTextStyles.caption.copyWith(
                            color: isSelected ? Colors.white : AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    entrance.description,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? AppColors.primary : AppColors.ink,
                    ),
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

                    // If route is active, re-calculate route from new entrance
                    final activeRoute = ref.read(activeRouteProvider);
                    if (activeRoute != null) {
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
