import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/stall_model.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/stall_utils.dart';
import '../../../core/constants/market_categories.dart';
import '../../../core/widgets/market_category_icon.dart';
import '../../../core/theme/app_theme.dart';
import '../../stalls/presentation/stall_detail_sheet.dart';

/// Modern Admin Stall Management Screen for Merkado Go
class ManageStallsScreen extends ConsumerStatefulWidget {
  const ManageStallsScreen({super.key});

  @override
  ConsumerState<ManageStallsScreen> createState() =>
      _ManageStallsScreenState();
}

class _ManageStallsScreenState extends ConsumerState<ManageStallsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  String _searchQuery = '';
  String _selectedCategory = 'All';
  String? _selectedSubcategory;

  // Sort & Filter state variables (Matching User Stalls Directory)
  String? sortAlpha; // 'az' | 'za' | null
  TimeOfDay? filterOpenTime;
  TimeOfDay? filterCloseTime;
  String? selectedDay; // 'Monday' | 'Tuesday' | ... | null
  bool showOpenOnDay = true;
  bool _filterOpenOnly = false; // Open now only toggle

  List<String> get _categories => MarketCategories.directoryFilterNames.where((c) => c != 'Favorites').toList();

  @override
  void dispose() {
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

  // Visual metadata for stall categories
  ({IconData icon, Color color}) _getCategoryVisuals(String category) {
    final v = MarketCategories.getVisuals(category);
    return (icon: v.icon, color: v.outline);
  }

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

    // Filter by subcategory if selected
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

  List<StallModel> _filterAndSortStalls(List<StallModel> stalls) {
    var result = stalls.where((stall) {
      // 1. Search Query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesName = stall.name.toLowerCase().contains(query);
        final matchesCategory = stall.category.toLowerCase().contains(query);
        final matchesProduct =
            stall.products.any((p) => p.toLowerCase().contains(query));
        final matchesTags =
            stall.tags.any((t) => t.toLowerCase().contains(query));
        if (!matchesName &&
            !matchesCategory &&
            !matchesProduct &&
            !matchesTags) {
          return false;
        }
      }

      // 2. Category & Subcategory Filter
      if (!_matchesCategory(stall, _selectedCategory, _selectedSubcategory)) {
        return false;
      }

      // 3. Open Now Only
      if (_filterOpenOnly) {
        if (!StallUtils.isStallOpenNow(stall)) return false;
      }

      // 4. Day & Status Filter
      if (selectedDay != null) {
        final isOpenOnDay = stall.daysOpen.any((day) {
          final d = day.trim().toLowerCase();
          final target = selectedDay!.toLowerCase();
          return d == target ||
              d.startsWith(target.substring(0, 3)) ||
              d == 'daily' ||
              d == 'everyday';
        });
        if (showOpenOnDay && !isOpenOnDay) return false;
        if (!showOpenOnDay && isOpenOnDay) return false;
      }

      // 5. Time Range Filter
      if (filterOpenTime != null && filterCloseTime != null) {
        if (stall.openTime.isEmpty || stall.closeTime.isEmpty) return false;
        final stallOpen = _parseTimeOfDay(stall.openTime);
        final stallClose = _parseTimeOfDay(stall.closeTime);

        if (stallOpen != null && stallClose != null) {
          final filterOpenMinutes =
              filterOpenTime!.hour * 60 + filterOpenTime!.minute;
          final filterCloseMinutes =
              filterCloseTime!.hour * 60 + filterCloseTime!.minute;
          final stallOpenMinutes = stallOpen.hour * 60 + stallOpen.minute;
          final stallCloseMinutes = stallClose.hour * 60 + stallClose.minute;

          if (stallOpenMinutes > filterOpenMinutes ||
              stallCloseMinutes < filterCloseMinutes) {
            return false;
          }
        }
      }

      return true;
    }).toList();

    // 6. Alphabetical Sorting
    if (sortAlpha == 'az') {
      result.sort((a, b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (sortAlpha == 'za') {
      result.sort((a, b) =>
          b.name.toLowerCase().compareTo(a.name.toLowerCase()));
    }

    return result;
  }

  Future<void> _deleteStall(
    BuildContext context,
    String stallId,
    String stallName,
  ) async {
    unawaited(HapticFeedback.selectionClick());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Delete Stall',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1B5E20),
          ),
        ),
        content: Text(
          'Are you sure you want to delete "$stallName"? This action cannot be undone.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: const Color(0xFF4B5563),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF9CA3AF),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFDC2626),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('stalls')
            .doc(stallId)
            .delete();
        if (mounted) {
          ScaffoldMessenger.of(this.context).showSnackBar(
            SnackBar(
              content: Text('Stall "$stallName" deleted successfully'),
              backgroundColor: const Color(0xFF1B5E20),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(this.context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete stall: $e'),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _openStallDetails(StallModel stall) {
    StallDetailSheet.show(context, stall);
  }

  void _showSortFilterModal() {
    unawaited(HapticFeedback.selectionClick());
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SortFilterModal(
        sortAlpha: sortAlpha,
        filterOpenTime: filterOpenTime,
        filterCloseTime: filterCloseTime,
        selectedDay: selectedDay,
        showOpenOnDay: showOpenOnDay,
        filterOpenOnly: _filterOpenOnly,
        onApply: (newSort, newOpenTime, newCloseTime, newDay, newShowOpen,
            newFilterOpenOnly) {
          setState(() {
            sortAlpha = newSort;
            filterOpenTime = newOpenTime;
            filterCloseTime = newCloseTime;
            selectedDay = newDay;
            showOpenOnDay = newShowOpen;
            _filterOpenOnly = newFilterOpenOnly;
          });
        },
        onReset: () {
          resetAllFilters();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;
    final activeFilters = getActiveFilterCount();

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
                'Stall Management',
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(RouteNames.adminAddStall),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text(
          'Add Stall',
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // 1. Search Bar & Filter Button Container
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 24 : 16,
              12,
              isDesktop ? 24 : 16,
              10,
            ),
            child: Row(
              children: [
                // Search Input Field
                Expanded(
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        color: const Color(0xFF1F2937),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search stalls, products, categories...',
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF9CA3AF),
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Color(0xFF1B5E20),
                          size: 20,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear_rounded,
                                  color: Color(0xFF9CA3AF),
                                  size: 18,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Sort & Filter Button
                Material(
                  color: activeFilters > 0
                      ? const Color(0xFF1B5E20)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: _showSortFilterModal,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 46,
                      width: 46,
                      alignment: Alignment.center,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 20,
                            color: activeFilters > 0
                                ? Colors.white
                                : const Color(0xFF4B5563),
                          ),
                          if (activeFilters > 0)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE53935),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '$activeFilters',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Category Chips Carousel
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 24 : 16,
              0,
              isDesktop ? 24 : 16,
              8,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((category) {
                  final isSelected = _selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Material(
                      color: isSelected
                          ? const Color(0xFF1B5E20)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedCategory = category;
                            _selectedSubcategory = null;
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF1B5E20)
                                  : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (category != 'All') ...[
                                Container(
                                  width: 7,
                                  height: 7,
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
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF4B5563),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // 2.5. Subcategory Chips Bar (shown when selected category has subcategories)
          Builder(
            builder: (context) {
              final activeItem = MarketCategories.findCategory(_selectedCategory);
              if (activeItem == null || activeItem.subcategories.isEmpty) {
                return const SizedBox.shrink();
              }

              final subcategories = activeItem.subcategories;
              return Container(
                color: Colors.white,
                padding: EdgeInsets.fromLTRB(
                  isDesktop ? 24 : 16,
                  0,
                  isDesktop ? 24 : 16,
                  10,
                ),
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: subcategories.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      final isAllSelected = _selectedSubcategory == null;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedSubcategory = null),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isAllSelected
                                ? activeItem.colorSet.fill
                                : activeItem.colorSet.accent.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isAllSelected
                                  ? activeItem.colorSet.fill
                                  : activeItem.colorSet.outline.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'All ${activeItem.shortName}',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: isAllSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: isAllSelected
                                    ? Colors.white
                                    : activeItem.colorSet.outline,
                              ),
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
                              : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSubSelected
                                ? activeItem.colorSet.fill
                                : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            sub,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: isSubSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isSubSelected
                                  ? Colors.white
                                  : const Color(0xFF4B5563),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),

          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // 3. Stalls Stream List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('stalls')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF1B5E20),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 44,
                          color: Color(0xFFDC2626),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Error loading stalls',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final rawStalls = snapshot.data?.docs
                        .map((doc) => StallModel.fromFirestore(doc))
                        .toList() ??
                    [];

                final filteredStalls = _filterAndSortStalls(rawStalls);

                if (filteredStalls.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
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
                          const SizedBox(height: 14),
                          Text(
                            'No stalls found',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Try adjusting your search query or filters'
                                : 'No stalls match this category',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await Future.delayed(const Duration(milliseconds: 400));
                  },
                  color: const Color(0xFF1B5E20),
                  child: ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      isDesktop ? 24 : 16,
                      12,
                      isDesktop ? 24 : 16,
                      80,
                    ),
                    itemCount: filteredStalls.length,
                    itemBuilder: (context, index) {
                      final stall = filteredStalls[index];
                      return _buildModernAdminStallCard(stall);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Modernized Stall Card with Admin Quick Actions & Enhanced Spacing
  Widget _buildModernAdminStallCard(StallModel stall) {
    final statusInfo = StallUtils.getStallStatusInfo(stall);
    final visuals = _getCategoryVisuals(stall.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () => _openStallDetails(stall),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top Row: Category Avatar + Stall Title & Badges + Action Buttons
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Visual Category Avatar (Instant, consistent, never replaced by photos)
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: visuals.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: visuals.color.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: MarketCategoryIcon(
                          category: stall.category,
                          fallbackIcon: visuals.icon,
                          color: visuals.color,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Title & Category / Status Badges
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
                              letterSpacing: -0.2,
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
                                  color: visuals.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: visuals.color.withValues(alpha: 0.35),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  StallUtils.getCategoryLabel(stall.category),
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: visuals.color,
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

                              // Photo indicator badge if photos uploaded
                              if (stall.photoUrls.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFFCBD5E1),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.photo_camera_rounded,
                                        size: 11,
                                        color: Color(0xFF475569),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${stall.photoUrls.length} ${stall.photoUrls.length == 1 ? 'photo' : 'photos'}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF475569),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Admin Action Buttons (Edit & Delete)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Material(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              context.push(
                                '${RouteNames.adminStalls}/${stall.stallId}/edit',
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.edit_rounded,
                                size: 18,
                                color: Color(0xFF1B5E20),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Material(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _deleteStall(
                              context,
                              stall.stallId,
                              stall.name,
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: Color(0xFFDC2626),
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

/// 4-Section Sort & Filter Modal (Matching User Stall Directory)
class _SortFilterModal extends StatefulWidget {
  final String? sortAlpha;
  final TimeOfDay? filterOpenTime;
  final TimeOfDay? filterCloseTime;
  final String? selectedDay;
  final bool showOpenOnDay;
  final bool filterOpenOnly;

  final Function(
    String? sortAlpha,
    TimeOfDay? filterOpenTime,
    TimeOfDay? filterCloseTime,
    String? selectedDay,
    bool showOpenOnDay,
    bool filterOpenOnly,
  ) onApply;
  final VoidCallback onReset;

  const _SortFilterModal({
    required this.sortAlpha,
    required this.filterOpenTime,
    required this.filterCloseTime,
    required this.selectedDay,
    required this.showOpenOnDay,
    required this.filterOpenOnly,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<_SortFilterModal> createState() => _SortFilterModalState();
}

class _SortFilterModalState extends State<_SortFilterModal> {
  late String? _sortAlpha;
  late TimeOfDay? _filterOpenTime;
  late TimeOfDay? _filterCloseTime;
  late String? _selectedDay;
  late bool _showOpenOnDay;
  late bool _filterOpenOnly;

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
    _sortAlpha = widget.sortAlpha;
    _filterOpenTime = widget.filterOpenTime;
    _filterCloseTime = widget.filterCloseTime;
    _selectedDay = widget.selectedDay;
    _showOpenOnDay = widget.showOpenOnDay;
    _filterOpenOnly = widget.filterOpenOnly;
  }

  Future<void> _selectTime(bool isOpenTime) async {
    final initial = isOpenTime
        ? (_filterOpenTime ?? const TimeOfDay(hour: 6, minute: 0))
        : (_filterCloseTime ?? const TimeOfDay(hour: 18, minute: 0));

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: AppTheme.buildTimePickerTheme,
    );

    if (picked != null) {
      setState(() {
        if (isOpenTime) {
          _filterOpenTime = picked;
        } else {
          _filterCloseTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title & Reset Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sort & Filter Stalls',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _sortAlpha = null;
                      _filterOpenTime = null;
                      _filterCloseTime = null;
                      _selectedDay = null;
                      _showOpenOnDay = true;
                      _filterOpenOnly = false;
                    });
                    widget.onReset();
                  },
                  child: Text(
                    'Reset All',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 01. Alphabetical Sorting
            Text(
              '01  SORT ALPHABETICALLY',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF6B7280),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildChoiceChip(
                    label: 'A to Z',
                    selected: _sortAlpha == 'az',
                    onTap: () {
                      setState(() {
                        _sortAlpha = _sortAlpha == 'az' ? null : 'az';
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildChoiceChip(
                    label: 'Z to A',
                    selected: _sortAlpha == 'za',
                    onTap: () {
                      setState(() {
                        _sortAlpha = _sortAlpha == 'za' ? null : 'za';
                      });
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 02. Quick Filter: Open Now Only
            Text(
              '02  STATUS FILTER',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF6B7280),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 18,
                        color: Color(0xFF1B5E20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Open Now Only',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _filterOpenOnly,
                    activeThumbColor: const Color(0xFF1B5E20),
                    activeTrackColor: const Color(0xFF86EFAC),
                    onChanged: (val) {
                      setState(() => _filterOpenOnly = val);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 03. Time Range Picker
            Text(
              '03  OPERATING HOURS RANGE',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF6B7280),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _selectTime(true),
                    icon: const Icon(Icons.wb_sunny_outlined, size: 16),
                    label: Text(
                      _filterOpenTime != null
                          ? 'Opens: ${_filterOpenTime!.format(context)}'
                          : 'Opens From',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _filterOpenTime != null
                          ? const Color(0xFF1B5E20)
                          : const Color(0xFF4B5563),
                      side: BorderSide(
                        color: _filterOpenTime != null
                            ? const Color(0xFF1B5E20)
                            : const Color(0xFFE5E7EB),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _selectTime(false),
                    icon: const Icon(Icons.nightlight_outlined, size: 16),
                    label: Text(
                      _filterCloseTime != null
                          ? 'Closes: ${_filterCloseTime!.format(context)}'
                          : 'Closes By',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _filterCloseTime != null
                          ? const Color(0xFF1B5E20)
                          : const Color(0xFF4B5563),
                      side: BorderSide(
                        color: _filterCloseTime != null
                            ? const Color(0xFF1B5E20)
                            : const Color(0xFFE5E7EB),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 04. Day & Status
            Text(
              '04  DAY OF THE WEEK',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF6B7280),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _days.map((day) {
                  final isSelected = _selectedDay == day;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(day.substring(0, 3)),
                      selected: isSelected,
                      selectedColor: const Color(0xFF1B5E20),
                      labelStyle: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF4B5563),
                      ),
                      onSelected: (selected) {
                        setState(() {
                          _selectedDay = selected ? day : null;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 24),

            // Apply Button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  widget.onApply(
                    _sortAlpha,
                    _filterOpenTime,
                    _filterCloseTime,
                    _selectedDay,
                    _showOpenOnDay,
                    _filterOpenOnly,
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Apply Filters',
                  style: GoogleFonts.poppins(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? const Color(0xFF1B5E20) : const Color(0xFFF9FAFB),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? const Color(0xFF1B5E20)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : const Color(0xFF4B5563),
            ),
          ),
        ),
      ),
    );
  }
}

