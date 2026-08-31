import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../stalls/presentation/stall_detail_sheet.dart';
import '../../domain/zone_palette.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/search_provider.dart';

/// Modal search sheet with trilingual keyword matching, category pills, and routing shortcuts
class MapSearchModal extends ConsumerStatefulWidget {
  const MapSearchModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const MapSearchModal(),
    );
  }

  @override
  ConsumerState<MapSearchModal> createState() => _MapSearchModalState();
}

class _MapSearchModalState extends ConsumerState<MapSearchModal> {
  late TextEditingController _searchController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final initialQuery = ref.read(mapSearchQueryProvider);
    _searchController = TextEditingController(text: initialQuery);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(searchResultsProvider);
    final selectedCategory = ref.watch(selectedCategoryFilterProvider);
    final categories = [
      'Produce',
      'Meat',
      'Fish',
      'Dry Goods',
      'Rice & Grains',
      'Eateries',
      'Thrift Apparel',
      'Tailoring & Dress Shop',
      'Sari Sari',
      'Wholesale Snacks',
      'Ingredients',
      'Coconut & Gata',
      'Specialty Repair',
      'Wellness & Spa',
      'Salon & Beauty',
      'Miscellaneous',
    ];

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.sheetRadius),
        ),
      ),
      child: Column(
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

          // Search Bar Input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    onChanged: (val) {
                      ref.read(mapSearchQueryProvider.notifier).state = val;
                    },
                    decoration: InputDecoration(
                      hintText: 'Search stalls, "sira", "orig", "gulay"...',
                      hintStyle: AppTextStyles.caption.copyWith(
                        color: AppColors.inkMuted,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.primary,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                ref.read(mapSearchQueryProvider.notifier).state = '';
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.surfaceDim,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.inkMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xs),

          // Category Filter Chips
          SizedBox(
            height: 38,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (context, index) {
                if (index == 0) {
                  final isAll = selectedCategory == null;
                  return ChoiceChip(
                    label: const Text('All'),
                    selected: isAll,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isAll ? Colors.white : AppColors.ink,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    onSelected: (_) {
                      ref.read(selectedCategoryFilterProvider.notifier).state = null;
                    },
                  );
                }

                final cat = categories[index - 1];
                final isSelected = selectedCategory == cat;
                final colorSet = ZonePalette.getColorSet(cat);

                return ChoiceChip(
                  avatar: CircleAvatar(
                    backgroundColor: colorSet.fill,
                    radius: 5,
                  ),
                  label: Text(cat),
                  selected: isSelected,
                  selectedColor: colorSet.fill,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  onSelected: (val) {
                    ref.read(selectedCategoryFilterProvider.notifier).state =
                        val ? cat : null;
                  },
                );
              },
            ),
          ),

          const Divider(color: AppColors.border, height: AppSpacing.md),

          // Search Results List
          Expanded(
            child: searchResults.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    itemCount: searchResults.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: AppColors.borderLight, height: 1),
                    itemBuilder: (context, index) {
                      final item = searchResults[index];
                      final stall = item.stall;
                      final colorSet = ZonePalette.getColorSet(stall.category);

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: AppSpacing.xs,
                        ),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: colorSet.fill.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(AppSpacing.sm),
                            border: Border.all(
                              color: colorSet.outline,
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            (stall.stallNumber != null &&
                                    stall.stallNumber!.isNotEmpty)
                                ? stall.stallNumber!
                                : stall.stallId.replaceFirst('id_', '#'),
                            style: TextStyle(
                              color: colorSet.outline,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        title: Text(
                          stall.name,
                          style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorSet.fill,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    stall.category,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (item.matchedKeyword != null &&
                                    item.matchedKeyword != stall.name) ...[
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Matched: ${item.matchedKeyword}',
                                      style: AppTextStyles.captionSmall.copyWith(
                                        color: AppColors.inkMuted,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        trailing: ElevatedButton.icon(
                          onPressed: () {
                            ref
                                .read(activeRouteProvider.notifier)
                                .navigateToStall(
                                  stallId: stall.stallId,
                                  stallName: stall.name,
                                );
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(
                            Icons.near_me_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          label: const Text('Route'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B5E20),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          StallDetailSheet.show(context, stall);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: AppColors.inkMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No stalls found',
              style: AppTextStyles.cardTitle,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Try searching with local terms like "sira" (fish), "orig" (pork), "gulay" (vegetables), or "bigas" (rice).',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
