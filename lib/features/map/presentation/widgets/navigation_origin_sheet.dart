import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../models/stall_model.dart';
import '../../domain/navigation_models.dart';
import 'entrance_selector_sheet.dart';

/// Result returned from NavigationOriginSheet
sealed class NavigationOriginResult {
  const NavigationOriginResult();
}

class EntranceOriginResult extends NavigationOriginResult {
  final MarketEntryPoint entrance;
  const EntranceOriginResult(this.entrance);
}

class StallOriginResult extends NavigationOriginResult {
  final StallModel stall;
  const StallOriginResult(this.stall);
}

class PickStallOnMapOriginResult extends NavigationOriginResult {
  const PickStallOnMapOriginResult();
}

class PickEntranceOnMapOriginResult extends NavigationOriginResult {
  const PickEntranceOnMapOriginResult();
}

/// Bottom sheet modal prompting the user to select either an entrance gate or a starting stall
class NavigationOriginSheet extends StatelessWidget {
  final String? targetStallId;
  final String? targetStallName;

  const NavigationOriginSheet({
    super.key,
    this.targetStallId,
    this.targetStallName,
  });

  /// Displays the modal sheet and returns the chosen [NavigationOriginResult], or null if dismissed
  static Future<NavigationOriginResult?> show(
    BuildContext context, {
    String? targetStallId,
    String? targetStallName,
  }) {
    return showModalBottomSheet<NavigationOriginResult>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.40),
      sheetAnimationStyle: AnimationStyle(
        duration: const Duration(milliseconds: 360),
        curve: const Cubic(0.16, 1.0, 0.3, 1.0),
        reverseDuration: const Duration(milliseconds: 260),
        reverseCurve: Curves.easeInCubic,
      ),
      builder: (ctx) => NavigationOriginSheet(
        targetStallId: targetStallId,
        targetStallName: targetStallName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.only(
        top: 10,
        bottom: 24,
        left: AppSpacing.md,
        right: AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose Starting Point',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Where are you starting your walk from?',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, size: 22),
                color: AppColors.inkMuted,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),

          if (targetStallName != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceDim,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.flag_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Navigating to: $targetStallName',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Option 1: Walk from a stall (Pick on Map / Search)
          _buildOptionCard(
            context: context,
            icon: Icons.storefront_rounded,
            title: 'Walk from another stall',
            subtitle: 'Pick on the map or search stall name',
            onTap: (ctx) async {
              await HapticFeedback.selectionClick();
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop(const PickStallOnMapOriginResult());
            },
          ),

          const SizedBox(height: 12),

          // Option 2: Enter from an entrance gate
          _buildOptionCard(
            context: context,
            icon: Icons.location_on_rounded,
            title: 'Enter from a gate',
            subtitle: "I'm arriving from outside the market",
            onTap: (ctx) async {
              await HapticFeedback.selectionClick();
              if (!ctx.mounted) return;
              final result = await EntranceSelectorSheet.show(
                ctx,
                targetStallId: targetStallId,
                targetStallName: targetStallName,
              );
              if (!ctx.mounted || result == null) return;
              if (result == 'pick_on_map') {
                Navigator.of(ctx).pop(const PickEntranceOnMapOriginResult());
              } else if (result is MarketEntryPoint) {
                Navigator.of(ctx).pop(EntranceOriginResult(result));
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required void Function(BuildContext) onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => onTap(context),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surfaceDim,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
