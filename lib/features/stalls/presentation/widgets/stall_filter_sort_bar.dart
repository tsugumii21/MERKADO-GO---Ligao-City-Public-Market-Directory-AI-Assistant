import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Clean inline bar with direct 1-tap controls for Sort, Open Now, and Expandable Filters.
/// Replaces the old "Sort & Filter" button that opened a full modal bottom sheet.
class StallFilterSortBar extends StatelessWidget {
  final String title;
  final int count;
  final String? sortAlpha; // null, 'az', 'za'
  final bool filterOpenOnly;
  final bool isDrawerOpen;
  final bool hasAdvancedFilters;
  final bool hasAnyActiveFilter;
  final ValueChanged<String?> onSortAlphaChanged;
  final ValueChanged<bool> onFilterOpenOnlyChanged;
  final VoidCallback onToggleDrawer;
  final VoidCallback onResetAll;

  const StallFilterSortBar({
    super.key,
    required this.title,
    required this.count,
    required this.sortAlpha,
    required this.filterOpenOnly,
    required this.isDrawerOpen,
    required this.hasAdvancedFilters,
    required this.hasAnyActiveFilter,
    required this.onSortAlphaChanged,
    required this.onFilterOpenOnlyChanged,
    required this.onToggleDrawer,
    required this.onResetAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // Left: Result Count & Reset
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    '$title ($count)',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                ),
                if (hasAnyActiveFilter) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onResetAll();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        '• Reset',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Right: 1-Tap Quick Action Pills
          // 1. Open Now Pill
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onFilterOpenOnlyChanged(!filterOpenOnly);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: filterOpenOnly ? const Color(0xFF1B5E20) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: filterOpenOnly ? const Color(0xFF1B5E20) : const Color(0xFFD1D5DB),
                  width: 1.2,
                ),
                boxShadow: filterOpenOnly
                    ? [
                        BoxShadow(
                          color: const Color(0xFF1B5E20).withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (filterOpenOnly)
                    const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                  else
                    const Text('🟢', style: TextStyle(fontSize: 8)),
                  const SizedBox(width: 4),
                  Text(
                    'Open',
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      fontWeight: filterOpenOnly ? FontWeight.w700 : FontWeight.w500,
                      color: filterOpenOnly ? Colors.white : const Color(0xFF374151),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),

          // 2. Sort Pill (1-Tap Cycle: Default -> A–Z -> Z–A)
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              if (sortAlpha == null) {
                onSortAlphaChanged('az');
              } else if (sortAlpha == 'az') {
                onSortAlphaChanged('za');
              } else {
                onSortAlphaChanged(null);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: sortAlpha != null ? const Color(0xFF1B5E20) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: sortAlpha != null ? const Color(0xFF1B5E20) : const Color(0xFFD1D5DB),
                  width: 1.2,
                ),
                boxShadow: sortAlpha != null
                    ? [
                        BoxShadow(
                          color: const Color(0xFF1B5E20).withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    sortAlpha == 'az'
                        ? Icons.arrow_upward_rounded
                        : (sortAlpha == 'za'
                            ? Icons.arrow_downward_rounded
                            : Icons.sort_by_alpha_rounded),
                    size: 13,
                    color: sortAlpha != null ? Colors.white : const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    sortAlpha == 'az'
                        ? 'A–Z'
                        : (sortAlpha == 'za' ? 'Z–A' : 'Sort'),
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      fontWeight: sortAlpha != null ? FontWeight.w700 : FontWeight.w500,
                      color: sortAlpha != null ? Colors.white : const Color(0xFF374151),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),

          // 3. Expandable Filter Drawer Toggle Pill
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onToggleDrawer();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: (isDrawerOpen || hasAdvancedFilters)
                    ? (hasAdvancedFilters ? const Color(0xFF1B5E20) : const Color(0xFFE8F5E9))
                    : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasAdvancedFilters
                      ? const Color(0xFF1B5E20)
                      : (isDrawerOpen ? const Color(0xFF1B5E20) : const Color(0xFFD1D5DB)),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 13,
                    color: hasAdvancedFilters
                        ? Colors.white
                        : (isDrawerOpen ? const Color(0xFF1B5E20) : const Color(0xFF6B7280)),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    isDrawerOpen
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 14,
                    color: hasAdvancedFilters
                        ? Colors.white
                        : (isDrawerOpen ? const Color(0xFF1B5E20) : const Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
