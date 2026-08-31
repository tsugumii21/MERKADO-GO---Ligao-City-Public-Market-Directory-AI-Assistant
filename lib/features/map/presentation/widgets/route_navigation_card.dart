import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/navigation_models.dart';
import '../../providers/navigation_provider.dart';

/// Floating turn-by-turn navigation header card displayed over the interactive map
class RouteNavigationCard extends ConsumerWidget {
  final NavigationRoute route;
  final VoidCallback onChangeEntrance;
  final VoidCallback onClose;

  const RouteNavigationCard({
    super.key,
    required this.route,
    required this.onChangeEntrance,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStepIdx = ref.watch(currentStepIndexProvider);
    final safeIdx = currentStepIdx.clamp(0, route.steps.length - 1);
    final currentStep = route.steps.isNotEmpty ? route.steps[safeIdx] : null;

    return Card(
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        side: const BorderSide(color: AppColors.border),
      ),
      color: AppColors.surface,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: Destination + Close Button
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xs + 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                  ),
                  child: const Icon(
                    Icons.navigation_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route.destinationStallName,
                        style: AppTextStyles.cardTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      InkWell(
                        onTap: onChangeEntrance,
                        borderRadius: BorderRadius.circular(AppSpacing.xs),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'From: ${route.entrance.description}',
                              style: AppTextStyles.captionSmall.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Icon(
                              Icons.arrow_drop_down_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, size: 22),
                  color: AppColors.inkMuted,
                  tooltip: 'End Navigation',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),

            if (currentStep != null) ...[
              const Divider(color: AppColors.border, height: AppSpacing.md),

              // Current Step Instruction Box
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                    ),
                    child: Icon(
                      currentStep.direction.icon,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentStep.instruction,
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (currentStep.distanceFormatted.isNotEmpty)
                          Text(
                            currentStep.distanceFormatted,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.sm),

              // Step navigation controls & Walking time summary
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Step Prev / Next Buttons
                  Row(
                    children: [
                      IconButton(
                        onPressed: safeIdx > 0
                            ? () {
                                ref.read(currentStepIndexProvider.notifier).state =
                                    safeIdx - 1;
                              }
                            : null,
                        icon: const Icon(Icons.chevron_left_rounded),
                        visualDensity: VisualDensity.compact,
                      ),
                      Text(
                        'Step ${safeIdx + 1} of ${route.steps.length}',
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        onPressed: safeIdx < route.steps.length - 1
                            ? () {
                                ref.read(currentStepIndexProvider.notifier).state =
                                    safeIdx + 1;
                              }
                            : null,
                        icon: const Icon(Icons.chevron_right_rounded),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),

                  // Total walking time badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDim,
                      borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      route.estimatedWalkingTimeFormatted,
                      style: AppTextStyles.captionSmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
