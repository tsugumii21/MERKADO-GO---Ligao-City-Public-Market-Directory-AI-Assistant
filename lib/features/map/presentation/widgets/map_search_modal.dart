import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/market_categories.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/stall_utils.dart';
import '../../../../core/widgets/market_category_icon.dart';
import '../../../stalls/presentation/stall_detail_sheet.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/search_provider.dart';
import 'entrance_selector_sheet.dart';
import 'navigation_loading_dialog.dart';

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

  // Sorting and Filtering State
  String? _sortAlpha; // 'az' or 'za'
  TimeOfDay? _filterOpenTime;
  TimeOfDay? _filterCloseTime;
  String? _selectedDay;
  bool _showOpenOnDay = true;
  bool _filterOpenOnly = false;

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

  int _getActiveFilterCount() {
    int count = 0;
    if (_sortAlpha != null) count++;
    if (_filterOpenTime != null || _filterCloseTime != null) count++;
    if (_selectedDay != null) count++;
    if (_filterOpenOnly) count++;
    return count;
  }

  void _resetAllFilters() {
    setState(() {
      _sortAlpha = null;
      _filterOpenTime = null;
      _filterCloseTime = null;
      _selectedDay = null;
      _showOpenOnDay = true;
      _filterOpenOnly = false;
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

  void _showSortFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SearchFilterBottomSheet(
        currentSortAlpha: _sortAlpha,
        currentFilterOpenTime: _filterOpenTime,
        currentFilterCloseTime: _filterCloseTime,
        currentSelectedDay: _selectedDay,
        currentShowOpenOnDay: _showOpenOnDay,
        currentFilterOpenOnly: _filterOpenOnly,
        onApply: (newSortAlpha, newOpenTime, newCloseTime, newDay, newShowOpen, newOpenOnly) {
          setState(() {
            _sortAlpha = newSortAlpha;
            _filterOpenTime = newOpenTime;
            _filterCloseTime = newCloseTime;
            _selectedDay = newDay;
            _showOpenOnDay = newShowOpen;
            _filterOpenOnly = newOpenOnly;
          });
        },
        onReset: _resetAllFilters,
      ),
    );
  }

  ({IconData icon, Color color}) _getCategoryVisuals(String category) {
    final v = MarketCategories.getVisuals(category);
    return (icon: v.icon, color: v.outline);
  }

  @override
  Widget build(BuildContext context) {
    final rawSearchResults = ref.watch(searchResultsProvider);
    final selectedCategory = ref.watch(selectedCategoryFilterProvider);
    final query = ref.watch(mapSearchQueryProvider);

    // Apply Filter & Sort Logic
    var filteredResults = rawSearchResults.where((item) {
      final stall = item.stall;

      // 1. Open Now Only Filter
      if (_filterOpenOnly) {
        if (!StallUtils.isStallOpenNow(stall)) return false;
      }

      // 2. Time Range Filter
      if (_filterOpenTime != null && _filterCloseTime != null) {
        if (stall.openTime.isEmpty || stall.closeTime.isEmpty) return false;
        final stallOpen = _parseTimeOfDay(stall.openTime);
        final stallClose = _parseTimeOfDay(stall.closeTime);
        if (stallOpen == null || stallClose == null) return false;

        final stallOpenMins = stallOpen.hour * 60 + stallOpen.minute;
        final stallCloseMins = stallClose.hour * 60 + stallClose.minute;
        final filterOpenMins = _filterOpenTime!.hour * 60 + _filterOpenTime!.minute;
        final filterCloseMins = _filterCloseTime!.hour * 60 + _filterCloseTime!.minute;

        if (stallOpenMins > filterOpenMins || stallCloseMins < filterCloseMins) {
          return false;
        }
      }

      // 3. Day of Week Filter
      if (_selectedDay != null) {
        final isOpenOnDay = stall.daysOpen.any((day) {
          final d = day.trim().toLowerCase();
          final target = _selectedDay!.toLowerCase();
          return d == target ||
              d.startsWith(target.substring(0, 3)) ||
              d == 'daily' ||
              d == 'everyday';
        });

        if (_showOpenOnDay) {
          if (!isOpenOnDay) return false;
        } else {
          if (isOpenOnDay) return false;
        }
      }

      return true;
    }).toList();

    // 4. Alphabetical Sorting
    if (_sortAlpha == 'az') {
      filteredResults.sort((a, b) =>
          a.stall.name.toLowerCase().compareTo(b.stall.name.toLowerCase()));
    } else if (_sortAlpha == 'za') {
      filteredResults.sort((a, b) =>
          b.stall.name.toLowerCase().compareTo(a.stall.name.toLowerCase()));
    }

    final activeFilterCount = _getActiveFilterCount();

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // 1. Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // 2. Search Input Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        color: const Color(0xFF0F172A),
                        fontWeight: FontWeight.w500,
                      ),
                      onChanged: (val) {
                        ref.read(mapSearchQueryProvider.notifier).state = val;
                      },
                      decoration: InputDecoration(
                        hintText: 'Search stalls, "sira", "orig", "gulay"...',
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF94A3B8),
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Color(0xFF64748B),
                          size: 20,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear_rounded,
                                  size: 18,
                                  color: Color(0xFF64748B),
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  ref.read(mapSearchQueryProvider.notifier).state = '';
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
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    foregroundColor: const Color(0xFF64748B),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Category Filter Chips (Horizontal Scroll)
          SizedBox(
            height: 36,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: MarketCategories.items.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                if (index == 0) {
                  final isAll = selectedCategory == null;
                  return ChoiceChip(
                    label: Text(
                      'All',
                      style: GoogleFonts.poppins(
                        color: isAll ? Colors.white : const Color(0xFF334155),
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                      ),
                    ),
                    selected: isAll,
                    selectedColor: const Color(0xFF1B5E20),
                    backgroundColor: const Color(0xFFF8FAFC),
                    side: BorderSide(
                      color: isAll ? const Color(0xFF1B5E20) : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    showCheckmark: false,
                    onSelected: (_) {
                      ref.read(selectedCategoryFilterProvider.notifier).state = null;
                    },
                  );
                }

                final catItem = MarketCategories.items[index - 1];
                final isSelected = selectedCategory == catItem.shortName ||
                    selectedCategory == catItem.displayName;
                final catColor = catItem.colorSet.outline;

                return ChoiceChip(
                  avatar: CircleAvatar(
                    backgroundColor: catColor,
                    radius: 4.5,
                  ),
                  label: Text(
                    catItem.shortName,
                    style: GoogleFonts.poppins(
                      color: isSelected ? Colors.white : const Color(0xFF334155),
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: catColor,
                  backgroundColor: const Color(0xFFF8FAFC),
                  side: BorderSide(
                    color: isSelected ? catColor : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  showCheckmark: false,
                  onSelected: (val) {
                    ref.read(selectedCategoryFilterProvider.notifier).state =
                        val ? catItem.shortName : null;
                  },
                );
              },
            ),
          ),

          // 4. Result Count & Sort/Filter Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  query.isEmpty
                      ? (selectedCategory != null
                          ? '$selectedCategory (${filteredResults.length})'
                          : 'All Stalls (${filteredResults.length})')
                      : 'Search Results (${filteredResults.length})',
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF475569),
                  ),
                ),
                Row(
                  children: [
                    if (query.isNotEmpty || selectedCategory != null || activeFilterCount > 0)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          ref.read(mapSearchQueryProvider.notifier).state = '';
                          ref.read(selectedCategoryFilterProvider.notifier).state = null;
                          _resetAllFilters();
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            'Reset',
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ),
                    InkWell(
                      onTap: _showSortFilterModal,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4.5,
                        ),
                        decoration: BoxDecoration(
                          color: activeFilterCount > 0
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: activeFilterCount > 0
                                ? const Color(0xFF1B5E20)
                                : const Color(0xFFCBD5E1),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.tune_rounded,
                              size: 13.5,
                              color: activeFilterCount > 0
                                  ? const Color(0xFF1B5E20)
                                  : const Color(0xFF475569),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              activeFilterCount > 0
                                  ? 'Sort ($activeFilterCount)'
                                  : 'Sort & Filter',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: activeFilterCount > 0
                                    ? const Color(0xFF1B5E20)
                                    : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(color: Color(0xFFF1F5F9), height: 1),

          // 5. Search Results Cards List
          Expanded(
            child: filteredResults.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    itemCount: filteredResults.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = filteredResults[index];
                      final stall = item.stall;
                      final visuals = _getCategoryVisuals(stall.category);
                      final statusInfo = StallUtils.getStallStatusInfo(stall);

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).pop();
                              StallDetailSheet.show(context, stall);
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Category Avatar Icon (46x46)
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: visuals.color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: visuals.color.withValues(alpha: 0.25),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Center(
                                      child: MarketCategoryIcon(
                                        category: stall.category,
                                        fallbackIcon: visuals.icon,
                                        size: 22,
                                        color: visuals.color,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Stall Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          stall.name,
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            // Category Badge
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 7,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: visuals.color.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(5),
                                                border: Border.all(
                                                  color: visuals.color.withValues(alpha: 0.35),
                                                  width: 0.7,
                                                ),
                                              ),
                                              child: Text(
                                                StallUtils.getCategoryLabel(stall.category),
                                                style: GoogleFonts.poppins(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: visuals.color,
                                                ),
                                              ),
                                            ),

                                            // Status Pill
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 7,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: statusInfo['bgColor'] as Color,
                                                borderRadius: BorderRadius.circular(5),
                                                border: Border.all(
                                                  color: (statusInfo['borderColor'] as Color)
                                                      .withValues(alpha: 0.6),
                                                  width: 0.7,
                                                ),
                                              ),
                                              child: Text(
                                                statusInfo['label'] as String,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: statusInfo['color'] as Color,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (item.matchedKeyword != null &&
                                            item.matchedKeyword != stall.name) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.auto_awesome,
                                                size: 11,
                                                color: Color(0xFFF59E0B),
                                              ),
                                              const SizedBox(width: 3),
                                              Expanded(
                                                child: Text(
                                                  'Matched: "${item.matchedKeyword}"',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 10.5,
                                                    color: const Color(0xFF64748B),
                                                    fontStyle: FontStyle.italic,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Route Action Button
                                  Material(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(10),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: () async {
                                        final chosenEntrance =
                                            await EntranceSelectorSheet.show(
                                          context,
                                          targetStallId: stall.stallId,
                                          targetStallName: stall.name,
                                        );
                                        if (chosenEntrance == null ||
                                            !context.mounted) {
                                          return;
                                        }

                                        await NavigationLoadingDialog.show(
                                          context,
                                          stallName: stall.name,
                                          entrance: chosenEntrance,
                                        );
                                        if (!context.mounted) return;

                                        await ref
                                            .read(activeRouteProvider.notifier)
                                            .navigateToStall(
                                              stallId: stall.stallId,
                                              stallName: stall.name,
                                              entranceOverride: chosenEntrance,
                                            );
                                        if (context.mounted) {
                                          Navigator.of(context).pop();
                                        }
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 7,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.near_me_rounded,
                                              size: 14,
                                              color: Color(0xFF1B5E20),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Route',
                                              style: GoogleFonts.poppins(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF1B5E20),
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
                          ),
                        ),
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
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 30,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No stalls found',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try searching with local terms like "sira" (fish), "orig" (pork), "gulay" (vegetables), or "bigas" (rice).',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF64748B),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet modal for sorting and filtering search results
class _SearchFilterBottomSheet extends StatefulWidget {
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
    String? selectedDay,
    bool showOpenOnDay,
    bool filterOpenOnly,
  ) onApply;
  final VoidCallback onReset;

  const _SearchFilterBottomSheet({
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
  State<_SearchFilterBottomSheet> createState() => _SearchFilterBottomSheetState();
}

class _SearchFilterBottomSheetState extends State<_SearchFilterBottomSheet> {
  String? _tempSortAlpha;
  TimeOfDay? _tempFilterOpenTime;
  TimeOfDay? _tempFilterCloseTime;
  String? _tempSelectedDay;
  bool _tempShowOpenOnDay = true;
  bool _tempFilterOpenOnly = false;

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
                        style: GoogleFonts.plusJakartaSans(
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

                    // SECTION 2: Operating Hours / Time Range
                    _buildSectionHeader('02  Operating Hours'),
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
                        ? 'Apply (${getActiveFilterCount()} active)'
                        : 'Apply Filters',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
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
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF9CA3AF),
          letterSpacing: 1.2,
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F5E9) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1B5E20)
                : const Color(0xFFE5E7EB),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? const Color(0xFF1B5E20)
                  : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF1B5E20)
                    : const Color(0xFF374151),
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
    final hasValue = time != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: hasValue ? const Color(0xFFE8F5E9) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasValue
                ? const Color(0xFF1B5E20)
                : const Color(0xFFE5E7EB),
            width: hasValue ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: hasValue
                      ? const Color(0xFF1B5E20)
                      : const Color(0xFF6B7280),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              hasValue ? _formatTimeOfDay(time) : 'Tap to set',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                color: hasValue
                    ? const Color(0xFF1B5E20)
                    : const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1B5E20) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1B5E20)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          day.substring(0, 3),
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusOption(
    String label,
    bool value,
    IconData icon,
    Color activeColor,
  ) {
    final isSelected = _tempShowOpenOnDay == value;
    return GestureDetector(
      onTap: () => setState(() => _tempShowOpenOnDay = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFE5E7EB),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? activeColor : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? activeColor : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

