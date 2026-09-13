import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/market_categories.dart';

/// Reusable category filter and subcategory chips strip.
/// Shared identically across MapSearchModal and StallListScreen.
class CategoryFilterChipsBar extends StatefulWidget {
  final String selectedCategory;
  final String? selectedSubcategory;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<String?> onSubcategorySelected;
  final EdgeInsetsGeometry padding;

  const CategoryFilterChipsBar({
    super.key,
    required this.selectedCategory,
    required this.selectedSubcategory,
    required this.onCategorySelected,
    required this.onSubcategorySelected,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  State<CategoryFilterChipsBar> createState() => _CategoryFilterChipsBarState();
}

class _CategoryFilterChipsBarState extends State<CategoryFilterChipsBar> {
  final ScrollController _scrollController = ScrollController();

  static List<String> get _categories => MarketCategories.directoryFilterNames;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected(animate: false));
  }

  @override
  void didUpdateWidget(covariant CategoryFilterChipsBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedCategory != oldWidget.selectedCategory) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected(animate: true));
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSelected({bool animate = true}) {
    if (!mounted || !_scrollController.hasClients) return;
    final index = _categories.indexOf(widget.selectedCategory);
    if (index <= 0) {
      if (animate) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(0);
      }
      return;
    }

    final targetOffset = (index * 88.0 - 40.0).clamp(0.0, _scrollController.position.maxScrollExtent);
    if (animate) {
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(targetOffset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeItem = MarketCategories.findCategory(widget.selectedCategory);
    final hasSubcategories = activeItem != null && activeItem.subcategories.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Primary Category Chips (Horizontal Scroll)
        SizedBox(
          height: 38,
          child: ListView.separated(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: widget.padding,
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final category = _categories[index];
              final isSelected = category == widget.selectedCategory;

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  widget.onCategorySelected(isSelected ? 'All' : category);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF1B5E20) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF1B5E20)
                          : const Color(0xFFE5E7EB),
                      width: 1.2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF1B5E20).withValues(alpha: 0.22),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (category == 'Favorites') ...[
                        Icon(
                          Icons.favorite_rounded,
                          size: 13,
                          color: isSelected ? Colors.white : Colors.redAccent,
                        ),
                        const SizedBox(width: 5),
                      ] else if (category != 'All') ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white
                                : MarketCategories.getVisuals(category).color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        category,
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : const Color(0xFF374151),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // 2. Subcategory Chips (Smoothly shown when selected category has subcategories)
        if (hasSubcategories) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: widget.padding,
              itemCount: activeItem.subcategories.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                if (index == 0) {
                  final isAllSelected = widget.selectedSubcategory == null;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      widget.onSubcategorySelected(null);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isAllSelected
                            ? activeItem.colorSet.fill
                            : activeItem.colorSet.accent.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isAllSelected
                              ? activeItem.colorSet.fill
                              : activeItem.colorSet.outline.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'All ${activeItem.shortName}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: isAllSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isAllSelected
                              ? Colors.white
                              : activeItem.colorSet.outline,
                        ),
                      ),
                    ),
                  );
                }

                final sub = activeItem.subcategories[index - 1];
                final isSubSelected = widget.selectedSubcategory == sub;

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onSubcategorySelected(isSubSelected ? null : sub);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isSubSelected
                          ? activeItem.colorSet.fill
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSubSelected
                            ? activeItem.colorSet.fill
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Text(
                      sub,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: isSubSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSubSelected
                            ? Colors.white
                            : const Color(0xFF4B5563),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
