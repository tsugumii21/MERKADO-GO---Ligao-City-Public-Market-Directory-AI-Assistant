import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/market_category_icon.dart';
import '../../../../models/stall_model.dart';
import '../../../../providers/stall_provider.dart';

/// Bottom sheet modal for selecting starting origin stall
class StallOriginPickerSheet extends ConsumerStatefulWidget {
  final String? targetStallId;
  final String? targetStallName;

  const StallOriginPickerSheet({
    super.key,
    this.targetStallId,
    this.targetStallName,
  });

  /// Displays the modal sheet and returns the chosen origin [StallModel], or null if dismissed
  static Future<StallModel?> show(
    BuildContext context, {
    String? targetStallId,
    String? targetStallName,
  }) {
    return showModalBottomSheet<StallModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.40),
      sheetAnimationStyle: AnimationStyle(
        duration: const Duration(milliseconds: 360),
        curve: const Cubic(0.16, 1.0, 0.3, 1.0),
        reverseDuration: const Duration(milliseconds: 260),
        reverseCurve: Curves.easeInCubic,
      ),
      builder: (context) => StallOriginPickerSheet(
        targetStallId: targetStallId,
        targetStallName: targetStallName,
      ),
    );
  }

  @override
  ConsumerState<StallOriginPickerSheet> createState() =>
      _StallOriginPickerSheetState();
}

class _StallOriginPickerSheetState
    extends ConsumerState<StallOriginPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final stallsAsync = ref.watch(allStallsProvider);

    return Container(
      height: screenHeight * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 10),
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
          const SizedBox(height: 12),

          // Header: Title, Subtitle, Close Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Starting Stall',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Choose where you are currently standing',
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
          ),

          // Destination badge if target is known
          if (widget.targetStallName != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Container(
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
                        'Heading to: ${widget.targetStallName}',
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
            ),
          ],

          const SizedBox(height: 12),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Container(
              height: 46,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFCBD5E1),
                  width: 1.2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  color: AppColors.ink,
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search stall name, number, or category...',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.inkMuted,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF64748B),
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear_rounded,
                            size: 18,
                            color: Color(0xFF64748B),
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),
          const Divider(color: AppColors.border, height: 1),

          // List of Stalls
          Expanded(
            child: stallsAsync.when(
              data: (stalls) {
                // Filter out target stall so user can't navigate to the same stall
                final availableStalls = stalls.where((s) {
                  if (widget.targetStallId != null &&
                      s.stallId == widget.targetStallId) {
                    return false;
                  }
                  if (_searchQuery.isEmpty) return true;
                  final nameMatch = s.name.toLowerCase().contains(_searchQuery);
                  final catMatch =
                      s.category.toLowerCase().contains(_searchQuery);
                  final numMatch = (s.stallNumber ?? '')
                      .toLowerCase()
                      .contains(_searchQuery);
                  final idMatch = s.stallId.toLowerCase().contains(_searchQuery);
                  final tagMatch = s.products.any(
                        (c) => c.toLowerCase().contains(_searchQuery),
                      ) ||
                      s.tags.any(
                        (t) => t.toLowerCase().contains(_searchQuery),
                      );
                  return nameMatch || catMatch || numMatch || idMatch || tagMatch;
                }).toList();

                if (availableStalls.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.storefront_outlined,
                            size: 44,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No stalls found',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Try a different stall name, vendor, or category.'
                                : 'No market stalls are available.',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.inkMuted,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  itemCount: availableStalls.length,
                  separatorBuilder: (_, __) => const Divider(
                    color: Color(0xFFF1F5F9),
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final stall = availableStalls[index];
                    final stallNum = stall.stallNumber ??
                        stall.stallId.replaceAll('id_', '');

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.of(context).pop(stall);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              // Category Avatar
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceDim,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Center(
                                  child: MarketCategoryIcon(
                                    category: stall.category,
                                    size: 22,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Name & Category details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      stall.name,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.ink,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Stall #$stallNum • ${stall.category}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11.5,
                                        color: AppColors.inkMuted,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),

                              // Select indicator arrow
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                                color: Color(0xFF94A3B8),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (_, __) => Center(
                child: Text(
                  'Failed to load stalls',
                  style: GoogleFonts.poppins(color: AppColors.error),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
