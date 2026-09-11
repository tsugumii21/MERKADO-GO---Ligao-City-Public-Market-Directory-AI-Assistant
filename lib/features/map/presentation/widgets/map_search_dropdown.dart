import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/stall_utils.dart';
import '../../../../models/stall_model.dart';
import '../../../../providers/stall_provider.dart';
import '../../domain/navigation_models.dart';
import '../../domain/zone_palette.dart';
import '../../providers/search_provider.dart';

/// Google Maps-style top search bar with anchored dropdown menu.
/// Displays live query matches with vendor initials avatars, trailing arrow,
/// and clean empty state matching the reference specification.
class MapSearchDropdown extends ConsumerStatefulWidget {
  final Function(StallModel stall) onStallSelected;
  final VoidCallback? onEntranceTap;
  final MarketEntryPoint? selectedEntrance;
  final bool isOpen;
  final ValueChanged<bool>? onOpenChanged;

  const MapSearchDropdown({
    super.key,
    required this.onStallSelected,
    this.onEntranceTap,
    this.selectedEntrance,
    this.isOpen = false,
    this.onOpenChanged,
  });

  @override
  ConsumerState<MapSearchDropdown> createState() => MapSearchDropdownState();
}

class MapSearchDropdownState extends ConsumerState<MapSearchDropdown> {
  late TextEditingController _searchController;
  final FocusNode _focusNode = FocusNode();
  bool _isOpenInternal = false;

  bool get isOpen => widget.isOpen || _isOpenInternal;

  static const List<String> _quickCategories = [
    'All',
    'Meat',
    'Fish',
    'Produce',
    'Dry Goods',
    'Eateries',
    'Rice & Grains',
    'Snacks',
  ];

  @override
  void initState() {
    super.initState();
    final initialQuery = ref.read(mapSearchQueryProvider);
    _searchController = TextEditingController(text: initialQuery);

    _focusNode.addListener(() {
      if (_focusNode.hasFocus && !_isOpenInternal) {
        _setOpen(true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant MapSearchDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen != oldWidget.isOpen) {
      _isOpenInternal = widget.isOpen;
      if (!widget.isOpen && _focusNode.hasFocus) {
        _focusNode.unfocus();
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _setOpen(bool open) {
    setState(() => _isOpenInternal = open);
    widget.onOpenChanged?.call(open);
  }

  /// Programmatically close dropdown and unfocus
  void close() {
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
    }
    _setOpen(false);
  }

  /// Programmatically open dropdown
  void open() {
    _setOpen(true);
    _focusNode.requestFocus();
  }

  String _getInitials(String name) {
    final clean = name.trim().replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '');
    if (clean.isEmpty) return 'ST';
    final parts = clean.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length.clamp(1, 2)).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(searchResultsProvider);
    final allStallsAsync = ref.watch(allStallsProvider);
    final allStalls = allStallsAsync.value ?? <StallModel>[];
    final activeCategory = ref.watch(selectedCategoryFilterProvider);

    // If query is empty and no category filter, show top stalls
    final List<StallModel> displayStalls;
    final bool isSearching = _searchController.text.trim().isNotEmpty ||
        (activeCategory != null && activeCategory.isNotEmpty && activeCategory != 'All');

    if (isSearching) {
      displayStalls = searchResults.map((r) => r.stall).toList();
    } else {
      displayStalls = allStalls.take(15).toList();
    }

    final double screenHeight = MediaQuery.of(context).size.height;
    final double maxDropdownHeight = (screenHeight * 0.46).clamp(240.0, 420.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Top Search Input Bar
        Material(
          elevation: 4,
          shadowColor: Colors.black.withValues(alpha: 0.12),
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isOpen ? AppColors.primary : AppColors.border,
                width: isOpen ? 1.5 : 1.0,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Search Icon
                Icon(
                  Icons.search_rounded,
                  color: isOpen ? AppColors.primary : AppColors.inkMuted,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.sm),

                // Text Input
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    onTap: () {
                      if (!isOpen) _setOpen(true);
                    },
                    onChanged: (val) {
                      ref.read(mapSearchQueryProvider.notifier).state = val;
                      if (!isOpen) _setOpen(true);
                      setState(() {});
                    },
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.ink,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search stalls, fish, meat...',
                      hintStyle: AppTextStyles.caption.copyWith(
                        color: AppColors.inkMuted,
                        fontSize: 13.5,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),

                // Clear button (when query text exists)
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      ref.read(mapSearchQueryProvider.notifier).state = '';
                      setState(() {});
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppColors.inkMuted.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ),

                // Vertical Divider
                Container(
                  height: 24,
                  width: 1,
                  color: AppColors.border,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),

                // Entrance Gate Shortcut Button
                InkWell(
                  onTap: () {
                    close();
                    widget.onEntranceTap?.call();
                  },
                  borderRadius: BorderRadius.circular(AppSpacing.xs),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          color: widget.selectedEntrance != null
                              ? AppColors.primary
                              : const Color(0xFFE53935),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.selectedEntrance != null
                              ? 'Gate ${widget.selectedEntrance!.entranceId}'
                              : 'Entrance',
                          style: AppTextStyles.captionSmall.copyWith(
                            color: widget.selectedEntrance != null
                                ? AppColors.primary
                                : AppColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Icon(
                          Icons.arrow_drop_down_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 2. Anchored Floating Dropdown Card
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                axisAlignment: -1.0,
                child: child,
              ),
            );
          },
          child: isOpen
              ? Container(
                  key: const ValueKey('search_dropdown_card'),
                  margin: const EdgeInsets.only(top: 8),
                  constraints: BoxConstraints(maxHeight: maxDropdownHeight),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 22,
                        spreadRadius: 1,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Quick Category Chips Bar
                        _buildCategoryFilterBar(activeCategory),

                        const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

                        // Content: Matches List OR Empty State
                        Flexible(
                          child: displayStalls.isEmpty
                              ? _buildEmptyState()
                              : _buildStallsList(displayStalls),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('search_dropdown_closed')),
        ),
      ],
    );
  }

  /// Horizontal category chip filter bar inside dropdown
  Widget _buildCategoryFilterBar(String? activeCategory) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: const Color(0xFFFAFAFA),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _quickCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final cat = _quickCategories[index];
          final isSelected = (cat == 'All' && (activeCategory == null || activeCategory.isEmpty || activeCategory == 'All')) ||
              activeCategory == cat;

          return InkWell(
            onTap: () {
              if (cat == 'All') {
                ref.read(selectedCategoryFilterProvider.notifier).state = null;
              } else {
                ref.read(selectedCategoryFilterProvider.notifier).state = cat;
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                ),
              ),
              child: Center(
                child: Text(
                  cat,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// List of matching stalls matching reference design
  Widget _buildStallsList(List<StallModel> stalls) {
    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: stalls.length,
      itemBuilder: (context, index) {
        final stall = stalls[index];
        final colorSet = ZonePalette.getColorSet(stall.category);
        final locationSummary =
            StallUtils.formatLocation(stall.section, stall.address);
        final hasStallNumber =
            stall.stallNumber != null && stall.stallNumber!.trim().isNotEmpty;
        final subtitle = hasStallNumber
            ? '${stall.category} • Stall #${stall.stallNumber}'
            : '${stall.category} • $locationSummary';

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              close();
              widget.onStallSelected(stall);
            },
            hoverColor: const Color(0xFFF8FAFC),
            splashColor: AppColors.primaryLight.withValues(alpha: 0.18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                children: [
                  // Circular initials avatar matching screenshot
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: colorSet.accent.withValues(alpha: 0.40),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _getInitials(stall.name),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colorSet.outline,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Stall Name & Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          stall.name,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            color: const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Trailing Action Arrow
                  const SizedBox(width: 8),
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Empty state matching the reference screenshot exactly
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Faded Skeleton Illustration Card
          Container(
            width: 76,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 5,
                  width: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Container(
                  height: 5,
                  width: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Container(
                  height: 5,
                  width: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Title: "Oops.. No Results Found"
          Text(
            'Oops.. No Results Found',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),

          // Subtitle
          Text(
            "Don't worry, it happens sometimes.\nPerhaps you could try entering a different search term",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF64748B),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
