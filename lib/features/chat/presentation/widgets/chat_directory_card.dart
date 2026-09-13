import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/market_categories.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/main_shell.dart' show mainShellKey;
import '../../../../providers/stall_provider.dart';
import '../../domain/chat_directory_action.dart';

/// Clean, responsive in-chat directory redirection card providing 1-tap category exploration
class ChatDirectoryCard extends ConsumerWidget {
  final ChatDirectoryAction action;
  final VoidCallback? onClose;

  const ChatDirectoryCard({
    super.key,
    required this.action,
    this.onClose,
  });

  void _handleRedirect(
    BuildContext context,
    WidgetRef ref,
    String targetCategory,
  ) {
    unawaited(HapticFeedback.mediumImpact());

    final matched = MarketCategories.findCategory(targetCategory);
    final target = matched?.primaryCategoryName ??
        (targetCategory == 'Favorites' ? 'Favorites' : targetCategory);

    // 1. Immediately set provider state synchronously
    try {
      ref.read(selectedDirectoryCategoryProvider.notifier).state = target;
      ref.read(selectedDirectorySubcategoryProvider.notifier).state = null;
    } catch (_) {}

    // 2. Close chat modal if open
    if (onClose != null) {
      onClose!();
    } else {
      Navigator.of(context).maybePop();
    }

    // 3. Instruct MainShell to jump to Tab 1 (Stall Directory) and activate category chip
    mainShellKey.currentState?.openCategoryInDirectory(target);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchedCategory = MarketCategories.findCategory(action.category);
    final categoryVisuals = MarketCategories.getVisuals(action.category);

    final targetCategoryName = matchedCategory?.primaryCategoryName ?? action.category;
    final displayName = matchedCategory?.displayName ??
        (action.category.isNotEmpty ? action.category : 'Market Stalls');
    final totalCount = action.totalCount;

    final countBadgeText = totalCount > 0
        ? '$totalCount stalls'
        : 'Directory';

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs + 2,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5E9),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppSpacing.cardRadius - 1),
                topRight: Radius.circular(AppSpacing.cardRadius - 1),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  categoryVisuals.icon,
                  size: 15,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    'STALL DIRECTORY',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AppColors.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    countBadgeText,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Body Content
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: categoryVisuals.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: categoryVisuals.outline.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        categoryVisuals.icon,
                        color: categoryVisuals.color,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm + 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF111827),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            totalCount > 0
                                ? 'Browse all $totalCount vendors, real-time operating hours, and search specific products in this category.'
                                : 'Browse all vendors, real-time operating hours, and search specific products in this category.',
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              color: const Color(0xFF4B5563),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Primary Action Button (Custom elevated, haptic, non-plain)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _handleRedirect(context, ref, targetCategoryName),
                    borderRadius: BorderRadius.circular(12),
                    splashColor: Colors.white.withValues(alpha: 0.2),
                    highlightColor: Colors.white.withValues(alpha: 0.1),
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.28),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.explore_outlined,
                            size: 17,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'View in Stall Directory',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 15,
                            color: Colors.white70,
                          ),
                        ],
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
}
