import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/navigation_models.dart';
import '../../providers/navigation_provider.dart';

/// Floating two-state turn-by-turn navigation card displayed over the interactive map
class RouteNavigationCard extends ConsumerStatefulWidget {
  final NavigationRoute route;
  final VoidCallback? onChangeEntrance;
  final VoidCallback onClose;
  final VoidCallback? onRepeatRoute;
  final VoidCallback? onSkip;

  const RouteNavigationCard({
    super.key,
    required this.route,
    this.onChangeEntrance,
    required this.onClose,
    this.onRepeatRoute,
    this.onSkip,
  });

  @override
  ConsumerState<RouteNavigationCard> createState() =>
      _RouteNavigationCardState();
}

class _RouteNavigationCardState extends ConsumerState<RouteNavigationCard> {
  bool _isMinimized = true;

  @override
  Widget build(BuildContext context) {
    final currentStepIdx = ref.watch(currentStepIndexProvider);
    final safeIdx = widget.route.steps.isNotEmpty
        ? currentStepIdx.clamp(0, widget.route.steps.length - 1)
        : 0;
    final currentStep =
        widget.route.steps.isNotEmpty ? widget.route.steps[safeIdx] : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Material(
        color: Colors.white,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: AppColors.border),
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: _isMinimized ? AppSpacing.sm : AppSpacing.md,
              ),
              child: _isMinimized
                  ? _buildMinimizedBar(safeIdx)
                  : _buildExpandedContent(safeIdx, currentStep),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMinimizedBar(int safeIdx) {
    return Row(
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
            size: 18,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.route.destinationStallName,
                style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              InkWell(
                onTap: widget.onChangeEntrance,
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        widget.route.originType == NavigationOriginType.stall
                            ? '${widget.route.steps.length} Steps • From ${widget.route.originStallName ?? "Stall"}'
                            : '${widget.route.steps.length} Steps • Gate ${widget.route.entrance?.entranceId ?? ""}',
                        style: AppTextStyles.captionSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.onChangeEntrance != null) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.swap_horiz_rounded,
                        size: 13,
                        color: AppColors.primary,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (widget.onSkip != null &&
            !ref.watch(isNavigationCompletedProvider))
          TextButton.icon(
            onPressed: widget.onSkip,
            icon: const Icon(
              Icons.fast_forward_rounded,
              size: 16,
              color: AppColors.primary,
            ),
            label: const Text(
              'Skip',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
          ),
        TextButton.icon(
          onPressed: () => setState(() => _isMinimized = false),
          icon: const Text(
            'Steps',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          label: const Icon(
            Icons.keyboard_arrow_up_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 6),
          ),
        ),
        IconButton(
          onPressed: widget.onClose,
          icon: const Icon(Icons.close_rounded, size: 20),
          color: AppColors.inkMuted,
          tooltip: 'End Navigation',
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }

  Widget _buildExpandedContent(int safeIdx, NavigationStep? currentStep) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header: Destination + Skip + Minimize + Close
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
                    widget.route.destinationStallName,
                    style: AppTextStyles.cardTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  InkWell(
                    onTap: widget.onChangeEntrance,
                    borderRadius: BorderRadius.circular(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            widget.route.originType == NavigationOriginType.stall
                                ? 'From: ${widget.route.originStallName ?? "Starting Stall"}'
                                : 'From Gate ${widget.route.entrance?.entranceId ?? ""}: ${widget.route.entrance?.description ?? ""}',
                            style: AppTextStyles.captionSmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.onChangeEntrance != null) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.swap_horiz_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (widget.onSkip != null &&
                !ref.watch(isNavigationCompletedProvider))
              TextButton.icon(
                onPressed: widget.onSkip,
                icon: const Icon(
                  Icons.fast_forward_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                label: const Text(
                  'Skip',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
              ),
            IconButton(
              onPressed: () => setState(() => _isMinimized = true),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
              color: AppColors.inkMuted,
              tooltip: 'Minimize Guidance',
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            IconButton(
              onPressed: widget.onClose,
              icon: const Icon(Icons.close_rounded, size: 20),
              color: AppColors.inkMuted,
              tooltip: 'End Navigation',
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
                    'Step ${safeIdx + 1} of ${widget.route.steps.length}',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    onPressed: safeIdx < widget.route.steps.length - 1
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
                  widget.route.estimatedWalkingTimeFormatted,
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
    );
  }
}

