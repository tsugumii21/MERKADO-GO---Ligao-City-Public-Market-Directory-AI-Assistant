// Part 8: Rebuilt Sort & Filter System - 3 Options (Alphabetical, Time Range, Day+Status)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/stall_model.dart';
import '../../../providers/stall_provider.dart';
import '../../../providers/favorite_provider.dart';
import 'stall_detail_sheet.dart';

class StallListScreen extends ConsumerStatefulWidget {
  const StallListScreen({super.key});

  @override
  ConsumerState<StallListScreen> createState() => _StallListScreenState();
}

class _StallListScreenState extends ConsumerState<StallListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _searchQuery = '';
  List<String> _recentlyViewedIds = [];

  // Sort/Filter state variables
  String? sortAlpha; // 'az' | 'za' | null
  TimeOfDay? filterOpenTime;
  TimeOfDay? filterCloseTime;
  String? selectedDay; // 'Mon'|'Tue'|...|null
  bool showOpenOnDay = true;

  final List<String> _categories = [
    'All',
    'Favorites',
    'Pork',
    'Poultry',
    'Beef',
    'Vegetables',
    'Seafood',
    'Dry Goods',
    'Fruits',
    'Spices',
  ];

  final Map<String, List<String>> dayMapping = {
    'Mon': ['monday', 'mon'],
    'Tue': ['tuesday', 'tue'],
    'Wed': ['wednesday', 'wed'],
    'Thu': ['thursday', 'thu'],
    'Fri': ['friday', 'fri'],
    'Sat': ['saturday', 'sat'],
    'Sun': ['sunday', 'sun'],
  };

  @override
  void initState() {
    super.initState();
    _loadRecentlyViewed();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(favoriteProvider.notifier).loadFavorites();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentlyViewed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentIds = prefs.getStringList('recently_viewed_stalls') ?? [];
      if (mounted) {
        setState(() {
          _recentlyViewedIds = recentIds.take(5).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading recently viewed: $e');
    }
  }

  Future<void> _saveRecentlyViewed(String stallId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> recentIds =
          prefs.getStringList('recently_viewed_stalls') ?? [];

      recentIds.remove(stallId);
      recentIds.insert(0, stallId);

      if (recentIds.length > 5) {
        recentIds = recentIds.sublist(0, 5);
      }

      await prefs.setStringList('recently_viewed_stalls', recentIds);

      if (mounted) {
        setState(() {
          _recentlyViewedIds = recentIds;
        });
      }
    } catch (e) {
      debugPrint('Error saving recently viewed: $e');
    }
  }

  Future<void> _clearRecentlyViewed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('recently_viewed_stalls');
      if (mounted) {
        setState(() {
          _recentlyViewedIds = [];
        });
      }
    } catch (e) {
      debugPrint('Error clearing recently viewed: $e');
    }
  }

  TimeOfDay parseTime(String timeStr) {
    timeStr = timeStr.trim().toUpperCase();
    bool isPM = timeStr.contains('PM');
    bool isAM = timeStr.contains('AM');
    timeStr = timeStr.replaceAll('AM', '').replaceAll('PM', '').trim();
    final parts = timeStr.split(':');
    int hour = int.parse(parts[0]);
    int minute = int.parse(parts[1]);
    if (isPM && hour != 12) hour += 12;
    if (isAM && hour == 12) hour = 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  bool stallOpenOnDay(StallModel stall, String day) {
    final dayVariants = dayMapping[day] ?? [day];
    return stall.daysOpen.any((d) =>
        dayVariants.any((v) => d.toLowerCase().contains(v.toLowerCase())));
  }

  List<StallModel> applyFilters(List<StallModel> stalls) {
    var result = List<StallModel>.from(stalls);

    // 1. Apply search query
    if (_searchQuery.isNotEmpty) {
      final queryLower = _searchQuery.toLowerCase();
      result = result.where((s) {
        final nameMatch = s.name.toLowerCase().contains(queryLower);
        final productMatch =
            s.products.any((p) => p.toLowerCase().contains(queryLower));
        return nameMatch || productMatch;
      }).toList();
    }

    // 2. Apply category filter
    if (_selectedCategory == 'Favorites') {
      final favState = ref.watch(favoriteProvider);
      result = result.where((s) => favState.isFavorite(s.stallId)).toList();
    } else if (_selectedCategory != 'All') {
      result = result.where((s) {
        final stallCategory = s.category.toLowerCase();
        final selectedCategory = _selectedCategory.toLowerCase();

        if (selectedCategory == 'seafood') {
          return stallCategory == 'seafood' || stallCategory == 'fish';
        }

        return stallCategory == selectedCategory;
      }).toList();
    }

    // 3. Apply time range filter
    // Logic: Include stall if stallOpenTime <= selectedOpenTime AND stallCloseTime >= selectedCloseTime
    // Example: User picks 6:00 AM → 12:00 PM
    // - Stall opens 5:30 AM closes 6:00 PM → INCLUDED (opens before 6AM ✓, closes after 12PM ✓)
    // - Stall opens 8:00 AM closes 5:00 PM → EXCLUDED (opens after 6AM ✗)
    // - Stall opens 4:00 AM closes 10:00 AM → EXCLUDED (closes before 12PM ✗)
    if (filterOpenTime != null && filterCloseTime != null) {
      result = result.where((s) {
        try {
          final stallOpen = parseTime(s.openTime);
          final stallClose = parseTime(s.closeTime);
          final toMinutes = (TimeOfDay t) => t.hour * 60 + t.minute;
          
          final stallOpenMinutes = toMinutes(stallOpen);
          final stallCloseMinutes = toMinutes(stallClose);
          final selectedOpenMinutes = toMinutes(filterOpenTime!);
          final selectedCloseMinutes = toMinutes(filterCloseTime!);
          
          // Stall must open at or before selected open time
          // AND close at or after selected close time
          return stallOpenMinutes <= selectedOpenMinutes &&
                 stallCloseMinutes >= selectedCloseMinutes;
        } catch (e) {
          return false;
        }
      }).toList();
    }

    // 4. Apply day filter
    if (selectedDay != null) {
      result = result.where((s) {
        final isOpen = stallOpenOnDay(s, selectedDay!);
        return showOpenOnDay ? isOpen : !isOpen;
      }).toList();
    }

    // 5. Apply alphabetical sort
    if (sortAlpha == 'az') {
      result.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (sortAlpha == 'za') {
      result.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
    }

    return result;
  }

  int getActiveFilterCount() {
    int count = 0;
    if (sortAlpha != null) count++;
    if (filterOpenTime != null && filterCloseTime != null) count++;
    if (selectedDay != null) count++;
    return count;
  }

  void resetAllFilters() {
    setState(() {
      sortAlpha = null;
      filterOpenTime = null;
      filterCloseTime = null;
      selectedDay = null;
      showOpenOnDay = true;
    });
  }

  void removeFilter(String filterType) {
    setState(() {
      switch (filterType) {
        case 'alpha':
          sortAlpha = null;
          break;
        case 'time':
          filterOpenTime = null;
          filterCloseTime = null;
          break;
        case 'day':
          selectedDay = null;
          break;
      }
    });
  }

  List<StallModel> _getRecentlyViewedStalls(List<StallModel> allStalls) {
    return _recentlyViewedIds
        .map((id) {
          try {
            return allStalls.firstWhere((stall) => stall.stallId == id);
          } catch (e) {
            return null;
          }
        })
        .whereType<StallModel>()
        .take(5)
        .toList();
  }

  void _openStallDetail(StallModel stall) {
    _saveRecentlyViewed(stall.stallId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StallDetailSheet(
        stall: stall,
        onClose: () {
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: false,
      builder: (context) => _FilterBottomSheet(
        currentSortAlpha: sortAlpha,
        currentFilterOpenTime: filterOpenTime,
        currentFilterCloseTime: filterCloseTime,
        currentSelectedDay: selectedDay,
        currentShowOpenOnDay: showOpenOnDay,
        onApply: (newSortAlpha, newOpenTime, newCloseTime, newDay, newShowOpen) {
          setState(() {
            sortAlpha = newSortAlpha;
            filterOpenTime = newOpenTime;
            filterCloseTime = newCloseTime;
            selectedDay = newDay;
            showOpenOnDay = newShowOpen;
          });
        },
        onReset: resetAllFilters,
        parseTime: parseTime,
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'all':
        return Icons.grid_view_rounded;
      case 'favorites':
        return Icons.favorite_rounded;
      case 'pork':
        return Icons.set_meal_outlined;
      case 'poultry':
        return Icons.egg_outlined;
      case 'beef':
        return Icons.set_meal_outlined;
      case 'fish':
      case 'seafood':
        return Icons.water_outlined;
      case 'vegetables':
        return Icons.eco_outlined;
      case 'fruits':
        return Icons.energy_savings_leaf_outlined;
      case 'dry goods':
        return Icons.shopping_bag_outlined;
      case 'spices':
        return Icons.grass_outlined;
      default:
        return Icons.storefront_outlined;
    }
  }

  String _getCategoryDisplayName(String category) {
    if (category.toLowerCase() == 'fish') {
      return 'Seafood';
    }
    return category;
  }

  String formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final stallsAsync = ref.watch(allStallsProvider);
    final activeFilterCount = getActiveFilterCount();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Text(
          'Stalls Directory',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: stallsAsync.when(
        data: (allStalls) {
          final filteredStalls = applyFilters(allStalls);
          final recentlyViewed = _getRecentlyViewedStalls(allStalls);

          return Column(
            children: [
              // Search bar
              Container(
                height: 46,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE0E0E0),
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    
                    // Search icon — plain, no container, no circle
                    const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF9E9E9E),
                      size: 18,
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // Text field
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF212121),
                          fontWeight: FontWeight.w400,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search stalls or products...',
                          hintStyle: GoogleFonts.poppins(
                            fontSize: 13,
                            color: const Color(0xFFBDBDBD),
                            fontWeight: FontWeight.w400,
                          ),
                          // Remove ALL borders
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          // Remove ALL default decorations
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          // NO prefixIcon here — icon is outside
                          prefixIcon: null,
                          suffixIcon: null,
                          filled: false,
                          // Remove counter and helper
                          counterText: '',
                          helperText: null,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                    ),
                    
                    // Clear button — only when typing
                    if (_searchController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(
                            Icons.close_rounded,
                            color: Color(0xFF9E9E9E),
                            size: 16,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 12),
                  ],
                ),
              ),

              Expanded(
                child: CustomScrollView(
                  slivers: [
                    // Category chips
                    SliverToBoxAdapter(
                      child: Container(
                        height: 50,
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _categories.length,
                          itemBuilder: (context, index) {
                            final category = _categories[index];
                            final isSelected = _selectedCategory == category;
                            final isFavoritesChip = category == 'Favorites';

                            if (isFavoritesChip) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedCategory = category;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFFFFEBEE)
                                          : const Color(0xFFF5F5F5),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFFE53935)
                                            : const Color(0xFFE0E0E0),
                                        width: isSelected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isSelected
                                              ? Icons.favorite_rounded
                                              : Icons.favorite_border_rounded,
                                          size: 14,
                                          color: isSelected
                                              ? const Color(0xFFE53935)
                                              : const Color(0xFF9E9E9E),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Favorites',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: isSelected
                                                ? const Color(0xFFE53935)
                                                : const Color(0xFF757575),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }

                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedCategory = category;
                                  });
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF1B5E20)
                                        : const Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF1B5E20)
                                          : const Color(0xFFEEEEEE),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _getCategoryIcon(category),
                                        size: 14,
                                        color: isSelected
                                            ? Colors.white
                                            : const Color(0xFF757575),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _getCategoryDisplayName(category),
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: isSelected
                                              ? Colors.white
                                              : const Color(0xFF757575),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // Active filter chips
                    if (activeFilterCount > 0)
                      SliverToBoxAdapter(
                        child: Container(
                          height: 40,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              if (sortAlpha != null)
                                _buildActiveFilterChip(
                                  sortAlpha == 'az' ? 'A → Z' : 'Z → A',
                                  () => removeFilter('alpha'),
                                ),
                              if (filterOpenTime != null &&
                                  filterCloseTime != null)
                                _buildActiveFilterChip(
                                  '${formatTimeOfDay(filterOpenTime!)} - ${formatTimeOfDay(filterCloseTime!)}',
                                  () => removeFilter('time'),
                                ),
                              if (selectedDay != null)
                                _buildActiveFilterChip(
                                  '${showOpenOnDay ? "Open" : "Closed"} on $selectedDay',
                                  () => removeFilter('day'),
                                ),
                            ],
                          ),
                        ),
                      ),

                    // Recently Viewed
                    if (recentlyViewed.isNotEmpty && _searchQuery.isEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.history_rounded,
                                    size: 16,
                                    color: Color(0xFF9E9E9E),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Recently Viewed',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF424242),
                                    ),
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: _clearRecentlyViewed,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Clear',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: const Color(0xFF9E9E9E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 140,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: recentlyViewed.length,
                            itemBuilder: (context, index) {
                              return _buildRecentStallCard(
                                  recentlyViewed[index]);
                            },
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    ],

                    // Section header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedCategory == 'Favorites'
                                  ? 'My Favorites (${filteredStalls.length})'
                                  : _searchQuery.isNotEmpty
                                      ? 'Search Results (${filteredStalls.length})'
                                      : _selectedCategory == 'All'
                                          ? 'All Stalls (${filteredStalls.length})'
                                          : '${_getCategoryDisplayName(_selectedCategory)} (${filteredStalls.length})',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF424242),
                              ),
                            ),
                            InkWell(
                              onTap: _showFilterBottomSheet,
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      activeFilterCount > 0
                                          ? Icons.filter_list_rounded
                                          : Icons.filter_list_outlined,
                                      size: 18,
                                      color: activeFilterCount > 0
                                          ? const Color(0xFF1B5E20)
                                          : const Color(0xFF757575),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      activeFilterCount > 0
                                          ? 'Filter ($activeFilterCount)'
                                          : 'Filter',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: activeFilterCount > 0
                                            ? const Color(0xFF1B5E20)
                                            : const Color(0xFF757575),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Stall list or empty state
                    if (filteredStalls.isEmpty)
                      SliverFillRemaining(
                        child: _buildEmptyState(),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final stall = filteredStalls[index];
                              return _buildStallCard(stall);
                            },
                            childCount: filteredStalls.length,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF1B5E20),
          ),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 64,
                  color: Color(0xFFE53935),
                ),
                const SizedBox(height: 16),
                Text(
                  'Error Loading Stalls',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF212121),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFF757575),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveFilterChip(String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        border: Border.all(color: const Color(0xFF1B5E20)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: const Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close_rounded,
              size: 12,
              color: Color(0xFF1B5E20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentStallCard(StallModel stall) {
    return GestureDetector(
      onTap: () => _openStallDetail(stall),
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFF0F0F0),
          ),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 64,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8E9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: stall.photoUrls.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: stall.photoUrls.first,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                        errorWidget: (context, url, error) => const Center(
                          child: Icon(
                            Icons.storefront_outlined,
                            size: 28,
                            color: Color(0xFF81C784),
                          ),
                        ),
                      ),
                    )
                  : const Center(
                      child: Icon(
                        Icons.storefront_outlined,
                        size: 28,
                        color: Color(0xFF81C784),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              stall.name,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF212121),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _getCategoryDisplayName(stall.category),
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  color: const Color(0xFF2E7D32),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStallCard(StallModel stall) {
    return GestureDetector(
      onTap: () => _openStallDetail(stall),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFF0F0F0),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 80,
                height: 80,
                color: const Color(0xFFF1F8E9),
                child: stall.photoUrls.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: stall.photoUrls.first,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.storefront_outlined,
                          size: 32,
                          color: Color(0xFF81C784),
                        ),
                      )
                    : const Icon(
                        Icons.storefront_outlined,
                        size: 32,
                        color: Color(0xFF81C784),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          stall.name,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1B5E20),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Consumer(
                        builder: (context, ref, child) {
                          final favState = ref.watch(favoriteProvider);
                          final isFav = favState.isFavorite(stall.stallId);

                          return GestureDetector(
                            onTap: () async {
                              await ref
                                  .read(favoriteProvider.notifier)
                                  .toggleFavorite(stall.stallId);
                            },
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              transitionBuilder: (child, animation) {
                                return ScaleTransition(
                                  scale: Tween<double>(
                                    begin: 0.7,
                                    end: 1.0,
                                  ).animate(
                                    CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.elasticOut,
                                    ),
                                  ),
                                  child: child,
                                );
                              },
                              child: Icon(
                                isFav
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                key: ValueKey(isFav),
                                color: isFav
                                    ? const Color(0xFFE53935)
                                    : const Color(0xFFBDBDBD),
                                size: 22,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getCategoryDisplayName(stall.category),
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_outlined,
                        size: 12,
                        color: Color(0xFF9E9E9E),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${stall.openTime} - ${stall.closeTime}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFF757575),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 12,
                        color: Color(0xFF9E9E9E),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          stall.address,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: const Color(0xFF9E9E9E),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isFavoritesEmpty = _selectedCategory == 'Favorites';
    final isSearchEmpty = _searchQuery.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFF5F5F5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFavoritesEmpty
                    ? Icons.favorite_border_rounded
                    : Icons.search_off_rounded,
                size: 56,
                color: const Color(0xFFBDBDBD),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isFavoritesEmpty
                  ? 'No favorites yet'
                  : isSearchEmpty
                      ? 'No stalls found'
                      : 'No stalls available',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF424242),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isFavoritesEmpty
                  ? 'Tap the heart icon on any stall to save it here'
                  : isSearchEmpty
                      ? 'Try searching with different keywords'
                      : 'No stalls available in this category',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF9E9E9E),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Filter Bottom Sheet Widget
class _FilterBottomSheet extends StatefulWidget {
  final String? currentSortAlpha;
  final TimeOfDay? currentFilterOpenTime;
  final TimeOfDay? currentFilterCloseTime;
  final String? currentSelectedDay;
  final bool currentShowOpenOnDay;
  final Function(String?, TimeOfDay?, TimeOfDay?, String?, bool) onApply;
  final VoidCallback onReset;
  final TimeOfDay Function(String) parseTime;

  const _FilterBottomSheet({
    required this.currentSortAlpha,
    required this.currentFilterOpenTime,
    required this.currentFilterCloseTime,
    required this.currentSelectedDay,
    required this.currentShowOpenOnDay,
    required this.onApply,
    required this.onReset,
    required this.parseTime,
  });

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  String? _tempSortAlpha;
  TimeOfDay? _tempFilterOpenTime;
  TimeOfDay? _tempFilterCloseTime;
  String? _tempSelectedDay;
  bool _tempShowOpenOnDay = true;

  final List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _tempSortAlpha = widget.currentSortAlpha;
    _tempFilterOpenTime = widget.currentFilterOpenTime;
    _tempFilterCloseTime = widget.currentFilterCloseTime;
    _tempSelectedDay = widget.currentSelectedDay;
    _tempShowOpenOnDay = widget.currentShowOpenOnDay;
  }

  Future<void> _pickTime(bool isOpenTime) async {
    final initialTime = isOpenTime
        ? (_tempFilterOpenTime ?? const TimeOfDay(hour: 6, minute: 0))
        : (_tempFilterCloseTime ?? const TimeOfDay(hour: 18, minute: 0));

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      initialEntryMode: TimePickerEntryMode.input,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: false,
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        if (isOpenTime) {
          _tempFilterOpenTime = picked;
        } else {
          _tempFilterCloseTime = picked;
        }
      });
    }
  }

  String formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  int getActiveFilterCount() {
    int count = 0;
    if (_tempSortAlpha != null) count++;
    if (_tempFilterOpenTime != null && _tempFilterCloseTime != null) count++;
    if (_tempSelectedDay != null) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.80,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sort & Filter',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF212121),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _tempSortAlpha = null;
                      _tempFilterOpenTime = null;
                      _tempFilterCloseTime = null;
                      _tempSelectedDay = null;
                      _tempShowOpenOnDay = true;
                    });
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Reset All',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF9E9E9E),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF0F0F0)),

          // SCROLLABLE CONTENT
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
                        child: _buildAlphaOption('A to Z', 'az', Icons.sort_by_alpha_rounded),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildAlphaOption('Z to A', 'za', Icons.sort_by_alpha_rounded),
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
                      color: const Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Show stalls open during this time range',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF9E9E9E),
                    ),
                  ),
                  const SizedBox(height: 16),
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
                  if (_tempFilterOpenTime != null && _tempFilterCloseTime != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                            color: Color(0xFF2E7D32),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Showing stalls open: ${formatTimeOfDay(_tempFilterOpenTime!)} - ${formatTimeOfDay(_tempFilterCloseTime!)}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF2E7D32),
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
                              color: Color(0xFF9E9E9E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // SECTION 3: Day & Status
                  _buildSectionHeader('03  Day & Status'),
                  Text(
                    'Filter by Day & Status',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Find stalls open or closed on a specific day',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF9E9E9E),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Select Day',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF9E9E9E),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: days.map((day) => _buildDayChip(day)).toList(),
                  ),
                  if (_tempSelectedDay != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Show stalls that are:',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF9E9E9E),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatusOption(
                            'Open on this day',
                            true,
                            Icons.check_circle_outline_rounded,
                            const Color(0xFF2E7D32),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatusOption(
                            'Closed on this day',
                            false,
                            Icons.cancel_outlined,
                            const Color(0xFFE53935),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // FIXED BOTTOM BUTTON - Always visible
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              border: Border(
                top: BorderSide(
                  color: Color(0xFFF0F0F0),
                  width: 1,
                ),
              ),
            ),
            child: Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x401B5E20),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  widget.onApply(
                    _tempSortAlpha,
                    _tempFilterOpenTime,
                    _tempFilterCloseTime,
                    _tempSelectedDay,
                    _tempShowOpenOnDay,
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  getActiveFilterCount() > 0
                      ? 'Apply Filters (${getActiveFilterCount()})'
                      : 'Apply Filters',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
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
      padding: const EdgeInsets.only(top: 20, bottom: 12),
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
              color: const Color(0xFF9E9E9E),
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
        height: 70,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F5E9) : const Color(0xFFF5F5F5),
          border: Border.all(
            color: isSelected ? const Color(0xFF1B5E20) : const Color(0xFFE0E0E0),
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
                    color: isSelected ? const Color(0xFF1B5E20) : const Color(0xFF757575),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? const Color(0xFF1B5E20) : const Color(0xFF757575),
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
                  size: 18,
                  color: Color(0xFF1B5E20),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker(String label, TimeOfDay? time, IconData icon, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: const Color(0xFF9E9E9E),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: time != null ? const Color(0xFF1B5E20) : const Color(0xFFE0E0E0),
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
                  time != null ? formatTimeOfDay(time) : '--:-- --',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF212121),
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
        width: 56,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1B5E20) : const Color(0xFFF5F5F5),
          border: isSelected ? null : Border.all(color: const Color(0xFFE0E0E0)),
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  const BoxShadow(
                    color: Color(0x301B5E20),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            day,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF757575),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusOption(String label, bool value, IconData icon, Color color) {
    final isSelected = _tempShowOpenOnDay == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _tempShowOpenOnDay = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? (value ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE))
              : const Color(0xFFF5F5F5),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE0E0E0),
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? color : const Color(0xFF757575),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? color : const Color(0xFF757575),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
