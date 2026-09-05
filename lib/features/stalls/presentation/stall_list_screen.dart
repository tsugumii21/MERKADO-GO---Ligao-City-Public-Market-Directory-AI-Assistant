import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/stall_model.dart';
import '../../../providers/stall_provider.dart';
import '../../../providers/favorite_provider.dart';
import '../../../core/utils/stall_utils.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/market_categories.dart';
import '../../../core/widgets/market_category_icon.dart';
import 'stall_detail_sheet.dart';

/// Alias for DirectoryScreen to ensure seamless naming compatibility
typedef DirectoryScreen = StallListScreen;

/// Modern Stalls Directory Screen for Merkado Go
class StallListScreen extends ConsumerStatefulWidget {
  const StallListScreen({super.key});

  @override
  ConsumerState<StallListScreen> createState() => StallListScreenState();
}

class StallListScreenState extends ConsumerState<StallListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _showBackToTop = false;

  String _selectedCategory = 'All';
  String? _selectedSubcategory;
  
  // Sort & Filter state variables
  String? sortAlpha; // 'az' | 'za' | null
  TimeOfDay? filterOpenTime;
  TimeOfDay? filterCloseTime;
  String? selectedDay; // 'Monday' | 'Tuesday' | ... | null
  bool showOpenOnDay = true;
  bool _filterOpenOnly = false; // Open now only toggle

  List<String> get _categories => MarketCategories.directoryFilterNames;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final show = _scrollController.hasClients && _scrollController.offset > 80;
    if (show != _showBackToTop) {
      setState(() => _showBackToTop = show);
    }
  }

  void _scrollToTop() {
    HapticFeedback.lightImpact();
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  int getActiveFilterCount() {
    int count = 0;
    if (sortAlpha != null) count++;
    if (filterOpenTime != null || filterCloseTime != null) count++;
    if (selectedDay != null) count++;
    if (_filterOpenOnly) count++;
    return count;
  }

  void resetUI() {
    if (!mounted) return;
    setState(() {
      _searchController.clear();
      _selectedCategory = 'All';
      _selectedSubcategory = null;
      resetAllFilters();
    });
  }

  void resetAllFilters() {
    setState(() {
      sortAlpha = null;
      filterOpenTime = null;
      filterCloseTime = null;
      selectedDay = null;
      showOpenOnDay = true;
      _filterOpenOnly = false;
      _selectedSubcategory = null;
    });
  }

  void showFavoritesView() {
    if (!mounted) return;
    setState(() {
      _searchController.clear();
      _selectedCategory = 'Favorites';
      resetAllFilters();
    });
  }

  void _openStallDetails(StallModel stall) {
    StallDetailSheet.show(context, stall);
  }

  // Category and subcategory matching helper
  bool _matchesCategory(StallModel stall, String category, [String? subcategory]) {
    if (category == 'All') return true;

    final targetItem = MarketCategories.findCategory(category);
    final stallItem = MarketCategories.findCategory(stall.category);

    bool categoryMatched = false;
    if (targetItem != null && stallItem != null) {
      if (targetItem.id == stallItem.id) {
        categoryMatched = true;
      }
    }

    if (!categoryMatched) {
      final stallCat = stall.category.toLowerCase();
      final targetCat = category.toLowerCase();
      if (stallCat.contains(targetCat) || targetCat.contains(stallCat)) {
        categoryMatched = true;
      }
    }

    if (!categoryMatched && targetItem != null) {
      final stallCat = stall.category.toLowerCase();
      final allWords = [
        ...targetItem.keywords,
        ...targetItem.subcategories,
        targetItem.shortName.toLowerCase(),
        targetItem.displayName.toLowerCase(),
      ];
      categoryMatched = allWords.any((w) =>
          stallCat.contains(w.toLowerCase()) ||
          stall.products.any((p) => p.toLowerCase().contains(w.toLowerCase())));
    }

    if (!categoryMatched) return false;

    // If subcategory is selected, filter strictly by subcategory
    if (subcategory != null && subcategory.isNotEmpty) {
      final subNorm = subcategory.toLowerCase();
      final inProducts = stall.products.any((p) =>
          p.toLowerCase().contains(subNorm) || subNorm.contains(p.toLowerCase()));
      final inTags = stall.tags.any((t) =>
          t.toLowerCase().contains(subNorm) || subNorm.contains(t.toLowerCase()));
      final inName = stall.name.toLowerCase().contains(subNorm);
      return inProducts || inTags || inName;
    }

    return true;
  }

  // Get visual metadata for a stall category
  ({IconData icon, Color color}) _getCategoryVisuals(String category) {
    final v = MarketCategories.getVisuals(category);
    return (icon: v.icon, color: v.outline);
  }

  TimeOfDay? _parseTimeOfDay(String timeStr) {
    try {
      final clean = timeStr.trim().toUpperCase();
      final isPM = clean.contains('PM');
      final isAM = clean.contains('AM');
      final numPart = clean.replaceAll(RegExp(r'[^\d:]'), '');
      final parts = numPart.split(':');
      if (parts.isEmpty) return null;

      var hour = int.parse(parts[0]);
      final minute = parts.length > 1 ? int.parse(parts[1]) : 0;

      if (isPM && hour < 12) hour += 12;
      if (isAM && hour == 12) hour = 0;

      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }

  void _showSortFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FilterBottomSheet(
        currentSortAlpha: sortAlpha,
        currentFilterOpenTime: filterOpenTime,
        currentFilterCloseTime: filterCloseTime,
        currentSelectedDay: selectedDay,
        currentShowOpenOnDay: showOpenOnDay,
        currentFilterOpenOnly: _filterOpenOnly,
        onApply: (newSortAlpha, newOpenTime, newCloseTime, newDay, newShowOpen, newOpenOnly) {
          setState(() {
            sortAlpha = newSortAlpha;
            filterOpenTime = newOpenTime;
            filterCloseTime = newCloseTime;
            selectedDay = newDay;
            showOpenOnDay = newShowOpen;
            _filterOpenOnly = newOpenOnly;
          });
        },
        onReset: resetAllFilters,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stallsAsync = ref.watch(allStallsProvider);
    final favState = ref.watch(favoriteProvider);
    final favNotifier = ref.read(favoriteProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Stalls Directory',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                'Ligao City Public Market',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFE8F5E9),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // 2. Normal Search Bar in Body
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: (val) => setState(() {}),
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFF1F2937),
              ),
              decoration: InputDecoration(
                hintText: 'Search stalls, products...',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade400,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF1B5E20),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          size: 18,
                          color: Color(0xFF6B7280),
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF1B5E20),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),

          // 3. Category Filter Chips
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = category == _selectedCategory;

                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedCategory = category;
                    _selectedSubcategory = null;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isSelected ? const Color(0xFF1B5E20) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF1B5E20)
                            : const Color(0xFFE5E7EB),
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF1B5E20)
                                    .withValues(alpha: 0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      children: [
                        if (category == 'Favorites') ...[
                          Icon(
                            Icons.favorite_rounded,
                            size: 14,
                            color: isSelected ? Colors.white : Colors.redAccent,
                          ),
                          const SizedBox(width: 4),
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
                            fontSize: 13,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF374151),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 3.5. Subcategory Chips (shown when selected category has subcategories)
          Builder(
            builder: (context) {
              final activeItem =
                  MarketCategories.findCategory(_selectedCategory);
              if (activeItem == null || activeItem.subcategories.isEmpty) {
                return const SizedBox.shrink();
              }

              final subcategories = activeItem.subcategories;
              return Container(
                margin: const EdgeInsets.only(top: 8),
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: subcategories.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      final isAllSelected = _selectedSubcategory == null;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedSubcategory = null),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isAllSelected
                                ? activeItem.colorSet.fill
                                : activeItem.colorSet.accent
                                    .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isAllSelected
                                  ? activeItem.colorSet.fill
                                  : activeItem.colorSet.outline
                                      .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            'All ${activeItem.shortName}',
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: isAllSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isAllSelected
                                  ? Colors.white
                                  : activeItem.colorSet.outline,
                            ),
                          ),
                        ),
                      );
                    }

                    final sub = subcategories[index - 1];
                    final isSubSelected = _selectedSubcategory == sub;

                    return GestureDetector(
                      onTap: () => setState(() {
                        _selectedSubcategory = isSubSelected ? null : sub;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
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
                            fontSize: 11.5,
                            fontWeight: isSubSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isSubSelected
                                ? Colors.white
                                : const Color(0xFF4B5563),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // 4. Stalls List Section Header & Filter Button
          stallsAsync.when(
            data: (allStalls) {
              // Filter logic
              var filtered = allStalls.where((stall) {
                // Search query matching
                final query = _searchController.text.trim().toLowerCase();
                if (query.isNotEmpty) {
                  final matchesName = stall.name.toLowerCase().contains(query);
                  final matchesCat =
                      stall.category.toLowerCase().contains(query);
                  final matchesProducts = stall.products
                      .any((p) => p.toLowerCase().contains(query));
                  final matchesAddress =
                      stall.address.toLowerCase().contains(query);

                  if (!matchesName &&
                      !matchesCat &&
                      !matchesProducts &&
                      !matchesAddress) {
                    return false;
                  }
                }

                // Category and subcategory matching
                if (_selectedCategory == 'Favorites') {
                  if (!favState.isFavorite(stall.stallId)) return false;
                } else if (!_matchesCategory(
                    stall, _selectedCategory, _selectedSubcategory)) {
                  return false;
                }

                // Open only quick filter
                if (_filterOpenOnly) {
                  if (!StallUtils.isStallOpenNow(stall)) return false;
                }

                // Time range filter
                if (filterOpenTime != null && filterCloseTime != null) {
                  if (stall.openTime.isEmpty || stall.closeTime.isEmpty) return false;
                  final stallOpen = _parseTimeOfDay(stall.openTime);
                  final stallClose = _parseTimeOfDay(stall.closeTime);
                  if (stallOpen == null || stallClose == null) return false;

                  final stallOpenMins = stallOpen.hour * 60 + stallOpen.minute;
                  final stallCloseMins = stallClose.hour * 60 + stallClose.minute;
                  final filterOpenMins =
                      filterOpenTime!.hour * 60 + filterOpenTime!.minute;
                  final filterCloseMins =
                      filterCloseTime!.hour * 60 + filterCloseTime!.minute;

                  if (stallOpenMins > filterOpenMins || stallCloseMins < filterCloseMins) {
                    return false;
                  }
                }

                // Day + Status filter
                if (selectedDay != null) {
                  final isOpenOnDay = stall.daysOpen.any((day) {
                    final d = day.trim().toLowerCase();
                    final target = selectedDay!.toLowerCase();
                    return d == target ||
                        d.startsWith(target.substring(0, 3)) ||
                        d == 'daily' ||
                        d == 'everyday';
                  });

                  if (showOpenOnDay) {
                    if (!isOpenOnDay) return false;
                  } else {
                    if (isOpenOnDay) return false;
                  }
                }

                return true;
              }).toList();

              // Sort Alphabetically
              if (sortAlpha == 'az') {
                filtered.sort((a, b) =>
                    a.name.toLowerCase().compareTo(b.name.toLowerCase()));
              } else if (sortAlpha == 'za') {
                filtered.sort((a, b) =>
                    b.name.toLowerCase().compareTo(a.name.toLowerCase()));
              }

              final activeFilters = getActiveFilterCount();

              return Expanded(
                child: Column(
                  children: [
                    // Section Title & Filter Trigger
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'All Stalls (${filtered.length})',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                          InkWell(
                            onTap: _showSortFilterModal,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.tune_rounded,
                                    size: 16,
                                    color: activeFilters > 0
                                        ? const Color(0xFF1B5E20)
                                        : const Color(0xFF4B5563),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    activeFilters > 0
                                        ? 'Filter ($activeFilters)'
                                        : 'Filter',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: activeFilters > 0
                                          ? const Color(0xFF1B5E20)
                                          : const Color(0xFF4B5563),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Stalls List
                    Expanded(
                      child: Stack(
                        children: [
                          filtered.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 64,
                                          height: 64,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFF3F4F6),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.storefront_outlined,
                                            size: 32,
                                            color: Color(0xFF9CA3AF),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No Stalls Found',
                                          style: GoogleFonts.outfit(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF374151),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Try adjusting your search query or clearing active filters.',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            color: const Color(0xFF6B7280),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 8,
                                  ),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final stall = filtered[index];
                                    final isFav =
                                        favState.isFavorite(stall.stallId);
                                    final isOpen =
                                        StallUtils.isStallOpenNow(stall);
                                    final visuals =
                                        _getCategoryVisuals(stall.category);

                                    return _buildStallCard(
                                      stall: stall,
                                      isFavorite: isFav,
                                      isOpen: isOpen,
                                      categoryIcon: visuals.icon,
                                      categoryColor: visuals.color,
                                      onToggleFavorite: () =>
                                          favNotifier.toggleFavorite(stall.stallId),
                                      onTap: () => _openStallDetails(stall),
                                    );
                                  },
                                ),
                          // Floating Scroll-to-Top Button
                          Positioned(
                            right: 20,
                            bottom: 20,
                            child: AnimatedScale(
                              scale: _showBackToTop ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutBack,
                              child: AnimatedOpacity(
                                opacity: _showBackToTop ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 200),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _scrollToTop,
                                    borderRadius: BorderRadius.circular(24),
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1B5E20),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF1B5E20)
                                                .withValues(alpha: 0.35),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.arrow_upward_rounded,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                  ),
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
            },
            loading: () => const Expanded(
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF1B5E20),
                ),
              ),
            ),
            error: (err, _) => Expanded(
              child: Center(
                child: Text(
                  'Failed to load stalls. Please check your connection.',
                  style: GoogleFonts.poppins(color: AppColors.error),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStallCard({
    required StallModel stall,
    required bool isFavorite,
    required bool isOpen,
    required IconData categoryIcon,
    required Color categoryColor,
    required VoidCallback onToggleFavorite,
    required VoidCallback onTap,
  }) {
    final statusInfo = StallUtils.getStallStatusInfo(stall);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B5E20).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header: Avatar + Title + Status Badges + Action Buttons
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stall Category Avatar Icon (Instant, consistent, never replaced by photos)
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: categoryColor.withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: MarketCategoryIcon(
                          category: stall.category,
                          fallbackIcon: categoryIcon,
                          size: 26,
                          color: categoryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Stall Name, Category & Status Pill
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stall.name,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // Category Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: categoryColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: categoryColor.withValues(alpha: 0.35),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  StallUtils.getCategoryLabel(stall.category),
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: categoryColor,
                                  ),
                                ),
                              ),

                              // Status Pill with exact operational status
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: statusInfo['bgColor'] as Color,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: (statusInfo['borderColor'] as Color)
                                        .withValues(alpha: 0.6),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  statusInfo['label'] as String,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: statusInfo['color'] as Color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // User Action Buttons (Favorite & Navigate)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Material(
                          color: isFavorite ? const Color(0xFFFEE2E2) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: onToggleFavorite,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                size: 18,
                                color: isFavorite ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Material(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: onTap,
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.near_me_rounded,
                                size: 18,
                                color: Color(0xFF1B5E20),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // 2. Physical Section / Address Row (if available)
                if ((stall.section?.isNotEmpty ?? false) || stall.address.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            (stall.section?.isNotEmpty ?? false)
                                ? (stall.address.isNotEmpty && stall.address != stall.section
                                    ? '${stall.section} • ${stall.address}'
                                    : (stall.section ?? ''))
                                : stall.address,
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF475569),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),

                // 3. Operating Schedule Container (Hours & Days)
                if (stall.openTime.isNotEmpty || stall.daysOpen.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 13.5,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          stall.openTime.isNotEmpty && stall.closeTime.isNotEmpty
                              ? '${stall.openTime} – ${stall.closeTime}'
                              : (stall.openTime.isNotEmpty ? stall.openTime : 'Hours not set'),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                        ),
                        if (stall.daysOpen.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              color: Color(0xFF94A3B8),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.event_available_rounded,
                            size: 13.5,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              StallUtils.formatOperatingDays(
                                  stall.daysOpen.join(', ')),
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                // 4. Products & Inventory Chips
                if (stall.products.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: [
                      ...stall.products.take(5).map(
                            (product) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.shopping_bag_outlined,
                                    size: 11,
                                    color: Color(0xFF1B5E20),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    product,
                                    style: GoogleFonts.poppins(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      if (stall.products.length > 5)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '+${stall.products.length - 5} more',
                            style: GoogleFonts.poppins(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                    ],
                  ),
                ] else if (stall.tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: [
                      ...stall.tags.take(4).map(
                            (tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                StallUtils.getTagLabel(tag),
                                style: GoogleFonts.poppins(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                      if (stall.tags.length > 4)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '+${stall.tags.length - 4} more',
                            style: GoogleFonts.poppins(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

}

/// The 4-Section Sort & Filter Bottom Sheet
class _FilterBottomSheet extends StatefulWidget {
  final String? currentSortAlpha;
  final TimeOfDay? currentFilterOpenTime;
  final TimeOfDay? currentFilterCloseTime;
  final String? currentSelectedDay;
  final bool currentShowOpenOnDay;
  final bool currentFilterOpenOnly;
  final Function(
    String? sortAlpha,
    TimeOfDay? openTime,
    TimeOfDay? closeTime,
    String? day,
    bool showOpenOnDay,
    bool openOnly,
  ) onApply;
  final VoidCallback onReset;

  const _FilterBottomSheet({
    required this.currentSortAlpha,
    required this.currentFilterOpenTime,
    required this.currentFilterCloseTime,
    required this.currentSelectedDay,
    required this.currentShowOpenOnDay,
    required this.currentFilterOpenOnly,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late String? _tempSortAlpha;
  late TimeOfDay? _tempFilterOpenTime;
  late TimeOfDay? _tempFilterCloseTime;
  late String? _tempSelectedDay;
  late bool _tempShowOpenOnDay;
  late bool _tempFilterOpenOnly;

  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    _tempSortAlpha = widget.currentSortAlpha;
    _tempFilterOpenTime = widget.currentFilterOpenTime;
    _tempFilterCloseTime = widget.currentFilterCloseTime;
    _tempSelectedDay = widget.currentSelectedDay;
    _tempShowOpenOnDay = widget.currentShowOpenOnDay;
    _tempFilterOpenOnly = widget.currentFilterOpenOnly;
  }

  int getActiveFilterCount() {
    int count = 0;
    if (_tempSortAlpha != null) count++;
    if (_tempFilterOpenTime != null || _tempFilterCloseTime != null) count++;
    if (_tempSelectedDay != null) count++;
    if (_tempFilterOpenOnly) count++;
    return count;
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _pickTime(bool isOpenTime) async {
    final initial = isOpenTime
        ? (_tempFilterOpenTime ?? const TimeOfDay(hour: 6, minute: 0))
        : (_tempFilterCloseTime ?? const TimeOfDay(hour: 18, minute: 0));

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: AppTheme.buildTimePickerTheme,
    );

    if (picked != null) {
      setState(() {
        if (isOpenTime) {
          _tempFilterOpenTime = picked;
          _tempFilterCloseTime ??= const TimeOfDay(hour: 18, minute: 0);
        } else {
          _tempFilterCloseTime = picked;
          _tempFilterOpenTime ??= const TimeOfDay(hour: 6, minute: 0);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Drag Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Sort & Filter',
                        style: GoogleFonts.outfit(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                      if (getActiveFilterCount() > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B5E20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${getActiveFilterCount()}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _tempSortAlpha = null;
                        _tempFilterOpenTime = null;
                        _tempFilterCloseTime = null;
                        _tempSelectedDay = null;
                        _tempShowOpenOnDay = true;
                        _tempFilterOpenOnly = false;
                      });
                    },
                    child: Text(
                      'Reset All',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFFEF4444),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFE5E7EB)),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SECTION 1: Alphabetical
                    _buildSectionHeader('01  Alphabetical'),
                    Row(
                      children: [
                        Expanded(
                          child: _buildAlphaOption(
                            'A to Z',
                            'az',
                            Icons.sort_by_alpha_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildAlphaOption(
                            'Z to A',
                            'za',
                            Icons.sort_by_alpha_rounded,
                          ),
                        ),
                      ],
                    ),

                    // SECTION 2: Time Range
                    _buildSectionHeader('02  Time Range'),
                    Text(
                      'Filter by Operating Hours',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Show stalls open during this time range',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTimePicker(
                            'Opens From',
                            _tempFilterOpenTime,
                            Icons.wb_sunny_outlined,
                            () => _pickTime(true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTimePicker(
                            'Closes By',
                            _tempFilterCloseTime,
                            Icons.nights_stay_outlined,
                            () => _pickTime(false),
                          ),
                        ),
                      ],
                    ),
                    if (_tempFilterOpenTime != null &&
                        _tempFilterCloseTime != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: Color(0xFF1B5E20),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Open: ${_formatTimeOfDay(_tempFilterOpenTime!)} – ${_formatTimeOfDay(_tempFilterCloseTime!)}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF1B5E20),
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _tempFilterOpenTime = null;
                                  _tempFilterCloseTime = null;
                                });
                              },
                              child: const Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // SECTION 3: Quick Filter
                    _buildSectionHeader('03  Quick Filter'),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Open Now Only',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                      subtitle: Text(
                        'Show only currently open stalls',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      value: _tempFilterOpenOnly,
                      activeTrackColor: const Color(0xFFA5D6A7),
                      activeThumbColor: const Color(0xFF1B5E20),
                      onChanged: (val) =>
                          setState(() => _tempFilterOpenOnly = val),
                    ),

                    // SECTION 4: Day & Status
                    _buildSectionHeader('04  Day & Status'),
                    Text(
                      'Filter by Day & Status',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Find stalls open or closed on a specific day',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Select Day',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _days.map((day) => _buildDayChip(day)).toList(),
                    ),
                    if (_tempSelectedDay != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Show stalls that are:',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatusOption(
                              'Open on this day',
                              true,
                              Icons.check_circle_outline_rounded,
                              const Color(0xFF1B5E20),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatusOption(
                              'Closed on this day',
                              false,
                              Icons.cancel_outlined,
                              const Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // FIXED BOTTOM BUTTON
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: Color(0xFFE5E7EB),
                    width: 1,
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(
                      _tempSortAlpha,
                      _tempFilterOpenTime,
                      _tempFilterCloseTime,
                      _tempSelectedDay,
                      _tempShowOpenOnDay,
                      _tempFilterOpenOnly,
                    );
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    getActiveFilterCount() > 0
                        ? 'Apply Filters (${getActiveFilterCount()})'
                        : 'Apply Filters',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 12),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFF1B5E20),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B7280),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlphaOption(String label, String value, IconData icon) {
    final isSelected = _tempSortAlpha == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _tempSortAlpha = isSelected ? null : value;
        });
      },
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F5E9) : Colors.white,
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1B5E20)
                : const Color(0xFFE5E7EB),
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: isSelected
                        ? const Color(0xFF1B5E20)
                        : const Color(0xFF6B7280),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF1B5E20)
                          : const Color(0xFF4B5563),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Positioned(
                top: 6,
                right: 6,
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: Color(0xFF1B5E20),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker(
    String label,
    TimeOfDay? time,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: time != null
                    ? const Color(0xFF1B5E20)
                    : const Color(0xFFE5E7EB),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: const Color(0xFF1B5E20),
                ),
                const SizedBox(width: 6),
                Text(
                  time != null ? _formatTimeOfDay(time) : '--:-- --',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDayChip(String day) {
    final isSelected = _tempSelectedDay == day;

    return GestureDetector(
      onTap: () {
        setState(() {
          _tempSelectedDay = isSelected ? null : day;
        });
      },
      child: Container(
        width: 54,
        height: 38,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1B5E20) : Colors.white,
          border: isSelected
              ? null
              : Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            day.substring(0, 3),
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF4B5563),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusOption(
    String label,
    bool value,
    IconData icon,
    Color color,
  ) {
    final isSelected = _tempShowOpenOnDay == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _tempShowOpenOnDay = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? (value
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFFEE2E2))
              : Colors.white,
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE5E7EB),
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? color : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? color : const Color(0xFF4B5563),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
