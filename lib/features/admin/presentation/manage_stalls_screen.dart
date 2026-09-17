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

  // Sort & Filter state variables (Admin Optimized)
  String? _sortOption; // 'az' | 'za' | 'section' | 'updated' | null
  String _mapFilter = 'all'; // 'all' | 'assigned' | 'unassigned'
  String _statusFilter = 'all'; // 'all' | 'open' | 'closed'
  String _photoFilter = 'all'; // 'all' | 'has_photo' | 'needs_photo'
  String? _selectedDay; // 'Mon' | 'Tue' | ... | null

  List<String> get _categories => MarketCategories.directoryFilterNames.where((c) => c != 'Favorites').toList();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  int getActiveFilterCount() {
    int count = 0;
    if (_sortOption != null) count++;
    if (_mapFilter != 'all') count++;
    if (_statusFilter != 'all') count++;
    if (_photoFilter != 'all') count++;
    if (_selectedDay != null) count++;
    return count;
  }

  void resetAllFilters() {
    setState(() {
      _sortOption = null;
      _mapFilter = 'all';
      _statusFilter = 'all';
      _photoFilter = 'all';
      _selectedDay = null;
      _selectedSubcategory = null;
    });
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

    // Filter by subcategory if selected (products are not subcategories)
    if (subcategory != null && subcategory.isNotEmpty) {
      final subNorm = subcategory.toLowerCase();
      final inSubcategories = stall.subcategories.any((s) =>
          s.toLowerCase().contains(subNorm) || subNorm.contains(s.toLowerCase()));
      final inTags = stall.tags.any((t) =>
          t.toLowerCase().contains(subNorm) || subNorm.contains(t.toLowerCase()));
      final inCategories = stall.categories.any((c) =>
          c.toLowerCase().contains(subNorm) || subNorm.contains(c.toLowerCase()));
      final inName = stall.name.toLowerCase().contains(subNorm);
      return inSubcategories || inTags || inCategories || inName;
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
        final matchesAddress = stall.address.toLowerCase().contains(query);
        final matchesSection = (stall.section ?? '').toLowerCase().contains(query);
        final matchesSlot = (stall.physicalStallId ?? '').toLowerCase().contains(query);
        if (!matchesName &&
            !matchesCategory &&
            !matchesProduct &&
            !matchesTags &&
            !matchesAddress &&
            !matchesSection &&
            !matchesSlot) {
          return false;
        }
      }

      // 2. Category & Subcategory Filter
      if (!_matchesCategory(stall, _selectedCategory, _selectedSubcategory)) {
        return false;
      }

      // 3. Map Location Filter (Admin)
      if (_mapFilter == 'assigned' && !stall.hasMapLocation) {
        return false;
      }
      if (_mapFilter == 'unassigned' && stall.hasMapLocation) {
        return false;
      }

      // 4. Operating Status Filter
      if (_statusFilter == 'open') {
        if (!StallUtils.isStallOpenNow(stall)) return false;
      } else if (_statusFilter == 'closed') {
        if (StallUtils.isStallOpenNow(stall)) return false;
      }

      // 5. Photo Filter (Admin)
      if (_photoFilter == 'has_photo' && stall.photoUrls.isEmpty) {
        return false;
      }
      if (_photoFilter == 'needs_photo' && stall.photoUrls.isNotEmpty) {
        return false;
      }

      // 6. Day of Week Filter
      if (_selectedDay != null) {
        final isOpenOnDay = stall.daysOpen.any((day) {
          final d = day.trim().toLowerCase();
          final target = _selectedDay!.toLowerCase();
          return d == target ||
              d.startsWith(target.substring(0, 3)) ||
              d == 'daily' ||
              d == 'everyday';
        });
        if (!isOpenOnDay) return false;
      }

      return true;
    }).toList();

    // 7. Sorting
    if (_sortOption == 'az') {
      result.sort((a, b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (_sortOption == 'za') {
      result.sort((a, b) =>
          b.name.toLowerCase().compareTo(a.name.toLowerCase()));
    } else if (_sortOption == 'section') {
      result.sort((a, b) {
        final aSec = (a.section ?? a.address).toLowerCase();
        final bSec = (b.section ?? b.address).toLowerCase();
        final cmp = aSec.compareTo(bSec);
        if (cmp != 0) return cmp;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    } else if (_sortOption == 'updated') {
      result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }

    return result;
  }

  Future<void> _deleteStall(
    BuildContext context,
    StallModel stall,
  ) async {
    final stallName = stall.name;
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
        final collection = FirebaseFirestore.instance.collection('stalls');

        // 1. Delete by document ID directly (guaranteed Firestore document key)
        if (stall.documentId != null && stall.documentId!.isNotEmpty) {
          await collection.doc(stall.documentId).delete();
        }

        // 2. Also delete by stallId if different
        if (stall.stallId.isNotEmpty && stall.stallId != stall.documentId) {
          await collection.doc(stall.stallId).delete();
        }

        // 3. Also delete by physicalStallId if different
        if (stall.physicalStallId != null &&
            stall.physicalStallId!.isNotEmpty &&
            stall.physicalStallId != stall.documentId &&
            stall.physicalStallId != stall.stallId) {
          await collection.doc(stall.physicalStallId).delete();
        }

        // 4. Query and delete any matching documents in Firestore by name or slot
        final querySnapshots = await Future.wait([
          collection.where('name', isEqualTo: stall.name).get(),
          if (stall.physicalStallId != null &&
              stall.physicalStallId!.isNotEmpty)
            collection
                .where('stall_id', isEqualTo: stall.physicalStallId)
                .get(),
          if (stall.physicalStallId != null &&
              stall.physicalStallId!.isNotEmpty)
            collection
                .where('physical_stall_id', isEqualTo: stall.physicalStallId)
                .get(),
        ]);

        for (final snap in querySnapshots) {
          for (final d in snap.docs) {
            await d.reference.delete();
          }
        }

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
    StallDetailSheet.show(context, stall, isAdmin: true);
  }

  void _showSortFilterModal() {
    unawaited(HapticFeedback.selectionClick());
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AdminSortFilterModal(
        sortOption: _sortOption,
        mapFilter: _mapFilter,
        statusFilter: _statusFilter,
        photoFilter: _photoFilter,
        selectedDay: _selectedDay,
        onApply: (newSort, newMap, newStatus, newPhoto, newDay) {
          setState(() {
            _sortOption = newSort;
            _mapFilter = newMap;
            _statusFilter = newStatus;
            _photoFilter = newPhoto;
            _selectedDay = newDay;
          });
        },
        onReset: resetAllFilters,
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
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        filled: false,
                        fillColor: Colors.transparent,
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
                        .where((stall) => stall.isActive != false)
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
                                '${RouteNames.adminStalls}/${stall.documentId ?? stall.stallId}/edit',
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
                              stall,
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

                // 2. Physical Section / Address Row (Full multi-line view)
                if ((stall.section?.isNotEmpty ?? false) || stall.address.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            StallUtils.formatLocation(stall.section, stall.address),
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF475569),
                              height: 1.35,
                            ),
                            maxLines: 3,
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
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (stall.openTime.isNotEmpty || stall.closeTime.isNotEmpty) ...[
                          Row(
                            children: [
                              const Icon(
                                Icons.schedule_rounded,
                                size: 13.5,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  stall.openTime.isNotEmpty && stall.closeTime.isNotEmpty
                                      ? '${stall.openTime} – ${stall.closeTime}'
                                      : (stall.openTime.isNotEmpty ? stall.openTime : 'Hours not set'),
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF334155),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if ((stall.openTime.isNotEmpty || stall.closeTime.isNotEmpty) &&
                            stall.daysOpen.isNotEmpty)
                          const SizedBox(height: 5),
                        if (stall.daysOpen.isNotEmpty) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.event_available_rounded,
                                size: 13.5,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  StallUtils.formatOperatingDays(
                                      stall.daysOpen.join(', ')),
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF64748B),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                // 4. Products / Tags 1-Line Summary Badge (Tap card for full details)
                if (stall.products.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          size: 13,
                          color: Color(0xFF1B5E20),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            StallUtils.formatProductsSummary(stall.products),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF334155),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 14,
                          color: Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                ] else if (stall.tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.local_offer_outlined,
                          size: 12.5,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            StallUtils.formatTagsSummary(stall.tags),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF475569),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 14,
                          color: Color(0xFF94A3B8),
                        ),
                      ],
                    ),
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

/// Admin-Optimized Sort & Filter Modal
class AdminSortFilterModal extends StatefulWidget {
  final String? sortOption;
  final String mapFilter;
  final String statusFilter;
  final String photoFilter;
  final String? selectedDay;

  final Function(
    String? sortOption,
    String mapFilter,
    String statusFilter,
    String photoFilter,
    String? selectedDay,
  ) onApply;
  final VoidCallback onReset;

  const AdminSortFilterModal({
    super.key,
    required this.sortOption,
    required this.mapFilter,
    required this.statusFilter,
    required this.photoFilter,
    required this.selectedDay,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<AdminSortFilterModal> createState() => _AdminSortFilterModalState();
}

class _AdminSortFilterModalState extends State<AdminSortFilterModal> {
  late String? _sortOption;
  late String _mapFilter;
  late String _statusFilter;
  late String _photoFilter;
  late String? _selectedDay;

  final List<String> _days = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  void initState() {
    super.initState();
    _sortOption = widget.sortOption;
    _mapFilter = widget.mapFilter;
    _statusFilter = widget.statusFilter;
    _photoFilter = widget.photoFilter;
    _selectedDay = widget.selectedDay;
  }

  int get _activeCount {
    int count = 0;
    if (_sortOption != null) count++;
    if (_mapFilter != 'all') count++;
    if (_statusFilter != 'all') count++;
    if (_photoFilter != 'all') count++;
    if (_selectedDay != null) count++;
    return count;
  }

  void _handleReset() {
    setState(() {
      _sortOption = null;
      _mapFilter = 'all';
      _statusFilter = 'all';
      _photoFilter = 'all';
      _selectedDay = null;
    });
    widget.onReset();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Handle Bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Title & Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 10),
              child: Row(
                children: [
                  Text(
                    'Sort & Filter Stalls',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _handleReset,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      'Reset All',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),

            // Filter Options Body
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 01. Sort By
                    _buildSectionHeader(
                      icon: Icons.sort_rounded,
                      title: 'SORT BY',
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFilterChip(
                          label: 'Name (A to Z)',
                          selected: _sortOption == 'az',
                          onTap: () {
                            setState(() {
                              _sortOption = _sortOption == 'az' ? null : 'az';
                            });
                          },
                        ),
                        _buildFilterChip(
                          label: 'Name (Z to A)',
                          selected: _sortOption == 'za',
                          onTap: () {
                            setState(() {
                              _sortOption = _sortOption == 'za' ? null : 'za';
                            });
                          },
                        ),
                        _buildFilterChip(
                          label: 'Section / Slot',
                          selected: _sortOption == 'section',
                          onTap: () {
                            setState(() {
                              _sortOption = _sortOption == 'section' ? null : 'section';
                            });
                          },
                        ),
                        _buildFilterChip(
                          label: 'Recently Updated',
                          selected: _sortOption == 'updated',
                          onTap: () {
                            setState(() {
                              _sortOption = _sortOption == 'updated' ? null : 'updated';
                            });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // 02. Map Location Assignment
                    _buildSectionHeader(
                      icon: Icons.map_outlined,
                      title: 'MAP ASSIGNMENT',
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFilterChip(
                          label: 'All Stalls',
                          selected: _mapFilter == 'all',
                          onTap: () => setState(() => _mapFilter = 'all'),
                        ),
                        _buildFilterChip(
                          label: 'Assigned on Map',
                          icon: Icons.pin_drop_rounded,
                          selected: _mapFilter == 'assigned',
                          onTap: () => setState(() => _mapFilter = 'assigned'),
                        ),
                        _buildFilterChip(
                          label: 'Missing Map Pin',
                          icon: Icons.location_off_outlined,
                          selected: _mapFilter == 'unassigned',
                          onTap: () => setState(() => _mapFilter = 'unassigned'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // 03. Operating Status
                    _buildSectionHeader(
                      icon: Icons.storefront_outlined,
                      title: 'OPERATING STATUS',
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFilterChip(
                          label: 'All Statuses',
                          selected: _statusFilter == 'all',
                          onTap: () => setState(() => _statusFilter = 'all'),
                        ),
                        _buildFilterChip(
                          label: 'Open Now',
                          icon: Icons.check_circle_outline_rounded,
                          selected: _statusFilter == 'open',
                          onTap: () => setState(() => _statusFilter = 'open'),
                        ),
                        _buildFilterChip(
                          label: 'Closed',
                          icon: Icons.schedule_rounded,
                          selected: _statusFilter == 'closed',
                          onTap: () => setState(() => _statusFilter = 'closed'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // 04. Stall Photo
                    _buildSectionHeader(
                      icon: Icons.photo_camera_outlined,
                      title: 'STALL PHOTO',
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFilterChip(
                          label: 'All Stalls',
                          selected: _photoFilter == 'all',
                          onTap: () => setState(() => _photoFilter = 'all'),
                        ),
                        _buildFilterChip(
                          label: 'Has Photo',
                          icon: Icons.image_rounded,
                          selected: _photoFilter == 'has_photo',
                          onTap: () => setState(() => _photoFilter = 'has_photo'),
                        ),
                        _buildFilterChip(
                          label: 'Missing Photo',
                          icon: Icons.hide_image_outlined,
                          selected: _photoFilter == 'needs_photo',
                          onTap: () => setState(() => _photoFilter = 'needs_photo'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // 05. Operating Days
                    _buildSectionHeader(
                      icon: Icons.calendar_today_outlined,
                      title: 'OPERATING DAY',
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _days.map((day) {
                        final isSelected = _selectedDay == day;
                        return _buildFilterChip(
                          label: day,
                          selected: isSelected,
                          onTap: () {
                            setState(() {
                              _selectedDay = isSelected ? null : day;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1, color: Color(0xFFF1F5F9)),

            // Apply Button
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.of(context).viewInsets.bottom + 14,
              ),
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    unawaited(HapticFeedback.lightImpact());
                    widget.onApply(
                      _sortOption,
                      _mapFilter,
                      _statusFilter,
                      _photoFilter,
                      _selectedDay,
                    );
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _activeCount > 0
                          ? 'Apply Filters ($_activeCount)'
                          : 'Apply Filters',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
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

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 15,
          color: const Color(0xFF1B5E20),
        ),
        const SizedBox(width: 7),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF475569),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return Material(
      color: selected ? const Color(0xFF1B5E20) : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () {
          unawaited(HapticFeedback.selectionClick());
          onTap();
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? const Color(0xFF1B5E20)
                  : const Color(0xFFE2E8F0),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 13.5,
                  color: selected ? Colors.white : const Color(0xFF64748B),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? Colors.white : const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

