import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Clean inline filter drawer for selecting operating day and operating hours.
/// Replaces the bulky bottom sheet modal with an inline collapsible panel.
class InlineFilterDrawer extends StatelessWidget {
  final String? selectedDay;
  final bool showOpenOnDay;
  final TimeOfDay? openTime;
  final TimeOfDay? closeTime;
  final ValueChanged<String?> onDaySelected;
  final ValueChanged<bool> onShowOpenChanged;
  final void Function(TimeOfDay? open, TimeOfDay? close) onTimeRangeChanged;
  final VoidCallback onClear;
  final VoidCallback onClose;

  const InlineFilterDrawer({
    super.key,
    required this.selectedDay,
    required this.showOpenOnDay,
    required this.openTime,
    required this.closeTime,
    required this.onDaySelected,
    required this.onShowOpenChanged,
    required this.onTimeRangeChanged,
    required this.onClear,
    required this.onClose,
  });

  static const List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const List<String> _shortDays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _pickTime(BuildContext context, bool isOpenTime) async {
    final initial = isOpenTime
        ? (openTime ?? const TimeOfDay(hour: 6, minute: 0))
        : (closeTime ?? const TimeOfDay(hour: 18, minute: 0));

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1B5E20),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1F2937),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      if (isOpenTime) {
        onTimeRangeChanged(picked, closeTime ?? const TimeOfDay(hour: 18, minute: 0));
      } else {
        onTimeRangeChanged(openTime ?? const TimeOfDay(hour: 6, minute: 0), picked);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasActive = selectedDay != null || openTime != null || closeTime != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.tune_rounded,
                    size: 16,
                    color: Color(0xFF1B5E20),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Day & Hours Filter',
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (hasActive)
                    GestureDetector(
                      onTap: onClear,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Text(
                          'Clear',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onClose,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 1. Day Selection
          Text(
            'Filter by Day of Week',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_days.length, (index) {
                final day = _days[index];
                final shortDay = _shortDays[index];
                final isSelected = selectedDay == day;

                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => onDaySelected(isSelected ? null : day),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF1B5E20) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF1B5E20)
                              : const Color(0xFFD1D5DB),
                        ),
                      ),
                      child: Text(
                        shortDay,
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : const Color(0xFF374151),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          // Open or Closed on selected day
          if (selectedDay != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Stalls on $selectedDay:',
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(
                    'Open Only',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: showOpenOnDay ? Colors.white : const Color(0xFF374151),
                    ),
                  ),
                  selected: showOpenOnDay,
                  selectedColor: const Color(0xFF1B5E20),
                  backgroundColor: Colors.white,
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  onSelected: (_) => onShowOpenChanged(true),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: Text(
                    'Closed Only',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: !showOpenOnDay ? Colors.white : const Color(0xFF374151),
                    ),
                  ),
                  selected: !showOpenOnDay,
                  selectedColor: const Color(0xFF1B5E20),
                  backgroundColor: Colors.white,
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  onSelected: (_) => onShowOpenChanged(false),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // 2. Operating Hours
          Text(
            'Filter by Operating Hours',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickTime(context, true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: openTime != null
                            ? const Color(0xFF1B5E20)
                            : const Color(0xFFD1D5DB),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.wb_sunny_outlined,
                              size: 14,
                              color: Color(0xFF1B5E20),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              openTime != null
                                  ? _formatTimeOfDay(openTime!)
                                  : 'Opens From',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                fontWeight: openTime != null
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: openTime != null
                                    ? const Color(0xFF1F2937)
                                    : const Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                        if (openTime != null)
                          GestureDetector(
                            onTap: () => onTimeRangeChanged(null, closeTime),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickTime(context, false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: closeTime != null
                            ? const Color(0xFF1B5E20)
                            : const Color(0xFFD1D5DB),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.nights_stay_outlined,
                              size: 14,
                              color: Color(0xFF1B5E20),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              closeTime != null
                                  ? _formatTimeOfDay(closeTime!)
                                  : 'Closes By',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                fontWeight: closeTime != null
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: closeTime != null
                                    ? const Color(0xFF1F2937)
                                    : const Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                        if (closeTime != null)
                          GestureDetector(
                            onTap: () => onTimeRangeChanged(openTime, null),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
