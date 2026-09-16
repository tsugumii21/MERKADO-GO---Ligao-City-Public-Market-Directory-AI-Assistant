import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/market_sections.dart';
import '../../../../core/theme/app_colors.dart';

/// Searchable modal bottom sheet and selector tile for Ligao City Public Market
/// sections and buildings (replaces the 23-button grid).
class AdminMarketSectionPicker extends StatelessWidget {
  final String? selectedSectionId;
  final ValueChanged<String?> onSectionChanged;

  const AdminMarketSectionPicker({
    super.key,
    required this.selectedSectionId,
    required this.onSectionChanged,
  });

  static Future<String?> showSectionSheet(
    BuildContext context, {
    String? currentSectionId,
  }) {
    return showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MarketSectionBottomSheet(currentSectionId: currentSectionId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedItem = MarketSections.findSection(selectedSectionId);
    final hasSelection = selectedItem != null;

    return Container(
      decoration: BoxDecoration(
        color: hasSelection ? AppColors.primaryLight : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasSelection ? AppColors.primary : AppColors.border,
          width: hasSelection ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final result = await showSectionSheet(
              context,
              currentSectionId: selectedSectionId,
            );
            if (result != null) {
              onSectionChanged(result.isEmpty ? null : result);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: hasSelection ? AppColors.primary : AppColors.canvas,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    selectedItem?.icon ?? Icons.domain_rounded,
                    size: 20,
                    color: hasSelection ? Colors.white : AppColors.inkMuted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hasSelection ? selectedItem.label : 'Select Market Section / Building',
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: hasSelection ? FontWeight.w600 : FontWeight.w500,
                          color: hasSelection ? AppColors.ink : AppColors.inkMuted,
                        ),
                      ),
                      if (hasSelection)
                        Text(
                          '${selectedItem.group} • ${selectedItem.description}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppColors.inkMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      else
                        Text(
                          'Tap to choose numbered building, camarin, or wing',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppColors.inkSubtle,
                          ),
                        ),
                    ],
                  ),
                ),
                if (hasSelection)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.inkMuted),
                    tooltip: 'Clear section',
                    splashRadius: 20,
                    onPressed: () => onSectionChanged(null),
                  )
                else
                  const Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 24,
                    color: AppColors.inkMuted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MarketSectionBottomSheet extends StatefulWidget {
  final String? currentSectionId;

  const _MarketSectionBottomSheet({this.currentSectionId});

  @override
  State<_MarketSectionBottomSheet> createState() => _MarketSectionBottomSheetState();
}

class _MarketSectionBottomSheetState extends State<_MarketSectionBottomSheet> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  final List<String> _groups = const [
    'Commodity Sections',
    'Camarin Buildings',
    'Numbered Buildings',
    'Market Extensions',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchQuery.trim().toLowerCase();
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
            child: Row(
              children: [
                const Icon(Icons.domain_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Market Section & Building',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        'Physical architectural structure in Ligao Public Market',
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.inkMuted),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // Search input bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              style: GoogleFonts.poppins(fontSize: 13.5, color: AppColors.ink),
              decoration: InputDecoration(
                hintText: 'Search building e.g. Building II, Camarin, Extension V...',
                hintStyle: GoogleFonts.poppins(fontSize: 13, color: AppColors.inkSubtle),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.inkMuted, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.inkMuted),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.canvas,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // Unassign option tile if a section is currently selected
          if (widget.currentSectionId != null && widget.currentSectionId!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Material(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => Navigator.of(context).pop(''),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.clear_all_rounded, size: 18, color: AppColors.error),
                        const SizedBox(width: 10),
                        Text(
                          'Clear Selection (Unassign Section)',
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Categorized Section List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: _buildGroupedItems(query),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedItems(String query) {
    final widgets = <Widget>[];

    for (final group in _groups) {
      final itemsInGroup = MarketSections.items.where((s) {
        if (s.group != group) return false;
        if (query.isEmpty) return true;
        return s.label.toLowerCase().contains(query) ||
            s.id.toLowerCase().contains(query) ||
            s.description.toLowerCase().contains(query);
      }).toList();

      if (itemsInGroup.isEmpty) continue;

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6, left: 4),
          child: Text(
            group.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.inkMuted,
              letterSpacing: 0.6,
            ),
          ),
        ),
      );

      for (final item in itemsInGroup) {
        final isSelected = widget.currentSectionId != null &&
            (widget.currentSectionId!.toUpperCase() == item.id.toUpperCase() ||
                widget.currentSectionId!.toUpperCase() == item.label.toUpperCase());

        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: isSelected ? AppColors.primaryLight : AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.of(context).pop(item.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        item.icon,
                        size: 20,
                        color: isSelected ? AppColors.primary : AppColors.inkMuted,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.label,
                              style: GoogleFonts.poppins(
                                fontSize: 13.5,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                color: isSelected ? AppColors.primary : AppColors.ink,
                              ),
                            ),
                            Text(
                              item.description,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 20,
                          color: AppColors.primary,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    if (widgets.isEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_rounded, size: 40, color: AppColors.inkSubtle),
              const SizedBox(height: 10),
              Text(
                'No sections matching "$query"',
                style: GoogleFonts.poppins(fontSize: 13, color: AppColors.inkMuted),
              ),
            ],
          ),
        ),
      );
    }

    return widgets;
  }
}
