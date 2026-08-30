import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/stall_model.dart';
import '../../../providers/favorite_provider.dart';
import '../../report/presentation/report_screen.dart';
import '../../../core/utils/stall_utils.dart';
import '../../../core/widgets/main_shell.dart';

/// Alias for naming compatibility
typedef StallDetailsModal = StallDetailSheet;

/// Clean, modern, navigation-focused Stall Details Bottom Sheet
class StallDetailSheet extends ConsumerStatefulWidget {
  final StallModel stall;
  final VoidCallback onClose;

  const StallDetailSheet({
    super.key,
    required this.stall,
    required this.onClose,
  });

  static Future<void> show(BuildContext context, StallModel stall) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StallDetailSheet(
        stall: stall,
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  ConsumerState<StallDetailSheet> createState() => _StallDetailSheetState();
}

class _StallDetailSheetState extends ConsumerState<StallDetailSheet> {
  int _currentPhotoIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToReportScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ReportScreen(
          stallId: widget.stall.stallId,
          stallName: widget.stall.name,
        ),
      ),
    );
  }

  void _navigateToStallOnMap() {
    HapticFeedback.mediumImpact();
    widget.onClose();
    mainShellKey.currentState?.goToTab(0);
  }

  String _formatSchedule(List<String> daysOpen) {
    if (daysOpen.isEmpty) return 'Open Daily (Mon – Sun)';

    final joined = daysOpen.join(', ').toLowerCase();
    if (joined.contains('daily') ||
        joined.contains('everyday') ||
        daysOpen.length == 7) {
      return 'Mon – Sun (Open Daily)';
    }

    if (daysOpen.length == 6 && !joined.contains('sun')) {
      return 'Mon – Sat';
    }

    if (daysOpen.length == 5 &&
        !joined.contains('sat') &&
        !joined.contains('sun')) {
      return 'Mon – Fri (Weekdays)';
    }

    // Convert days to short names
    return daysOpen.map((d) {
      final clean = d.trim();
      if (clean.length > 3) return clean.substring(0, 3);
      return clean;
    }).join(', ');
  }

  ({IconData icon, Color color, Color bg}) _getCategoryVisuals(String category) {
    final cat = category.toLowerCase();

    if (cat.contains('meat') ||
        cat.contains('pork') ||
        cat.contains('beef') ||
        cat.contains('karne')) {
      return (
        icon: Icons.set_meal_rounded,
        color: const Color(0xFFEF4444),
        bg: const Color(0xFFFEE2E2),
      );
    }
    if (cat.contains('poultry') ||
        cat.contains('chicken') ||
        cat.contains('manok') ||
        cat.contains('egg')) {
      return (
        icon: Icons.egg_outlined,
        color: const Color(0xFFF97316),
        bg: const Color(0xFFFFEDD5),
      );
    }
    if (cat.contains('seafood') ||
        cat.contains('fish') ||
        cat.contains('isda')) {
      return (
        icon: Icons.water_rounded,
        color: const Color(0xFF3B82F6),
        bg: const Color(0xFFDBEAFE),
      );
    }
    if (cat.contains('rice') ||
        cat.contains('bigas') ||
        cat.contains('grain') ||
        cat.contains('dry')) {
      return (
        icon: Icons.grain_rounded,
        color: const Color(0xFFF59E0B),
        bg: const Color(0xFFFEF3C7),
      );
    }
    if (cat.contains('agrivet') ||
        cat.contains('feed') ||
        cat.contains('pet')) {
      return (
        icon: Icons.pets_rounded,
        color: const Color(0xFF8B5CF6),
        bg: const Color(0xFFEDE9FE),
      );
    }
    if (cat.contains('fruit') ||
        cat.contains('vegetable') ||
        cat.contains('gulay') ||
        cat.contains('fresh')) {
      return (
        icon: Icons.eco_rounded,
        color: const Color(0xFF10B981),
        bg: const Color(0xFFDCFCE7),
      );
    }

    return (
      icon: Icons.storefront_rounded,
      color: const Color(0xFF1B5E20),
      bg: const Color(0xFFE8F5E9),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stall = widget.stall;
    final isFav = ref.watch(favoriteProvider).isFavorite(stall.stallId);
    final favNotifier = ref.read(favoriteProvider.notifier);
    final isOpen = StallUtils.isStallOpenNow(stall);
    final categoryVisuals = _getCategoryVisuals(stall.category);
    final hasPhotos = stall.photoUrls.isNotEmpty;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Top Bar: Title & Close Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Stall Details',
                    style: GoogleFonts.outfit(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF4B5563),
                      size: 22,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 2. Compact Photo / Category Banner (140px Height)
                    Stack(
                      children: [
                        Container(
                          height: 140,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: categoryVisuals.bg.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: hasPhotos
                                ? PageView.builder(
                                    controller: _pageController,
                                    itemCount: stall.photoUrls.length,
                                    onPageChanged: (idx) {
                                      setState(() => _currentPhotoIndex = idx);
                                    },
                                    itemBuilder: (context, index) {
                                      return CachedNetworkImage(
                                        imageUrl: stall.photoUrls[index],
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => Center(
                                          child: CircularProgressIndicator(
                                            color: categoryVisuals.color,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        errorWidget: (_, __, ___) => Center(
                                          child: Icon(
                                            categoryVisuals.icon,
                                            size: 48,
                                            color: categoryVisuals.color,
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          categoryVisuals.icon,
                                          size: 40,
                                          color: categoryVisuals.color,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'No photo available',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: const Color(0xFF6B7280),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),

                        // Floating Favorite Button (Top-Right)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Material(
                            color: Colors.white,
                            shape: const CircleBorder(),
                            elevation: 3,
                            shadowColor: Colors.black26,
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                favNotifier.toggleFavorite(stall.stallId);
                              },
                              customBorder: const CircleBorder(),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Icon(
                                  isFav
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  color: isFav
                                      ? Colors.redAccent
                                      : const Color(0xFF6B7280),
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Photo Indicator Dots (if multiple photos)
                        if (hasPhotos && stall.photoUrls.length > 1)
                          Positioned(
                            bottom: 8,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                stall.photoUrls.length,
                                (idx) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  width: _currentPhotoIndex == idx ? 16 : 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: _currentPhotoIndex == idx
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 3. Stall Name & Location
                    Text(
                      stall.name,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1F2937),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Category Pill & Location Subtitle
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: categoryVisuals.bg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                categoryVisuals.icon,
                                size: 13,
                                color: categoryVisuals.color,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                stall.category.isNotEmpty
                                    ? stall.category
                                    : 'General',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: categoryVisuals.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: Color(0xFF6B7280),
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  stall.address.isNotEmpty
                                      ? stall.address
                                      : (stall.section != null
                                          ? 'Section ${stall.section}, Ligao Public Market'
                                          : 'Ligao City Public Market'),
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: const Color(0xFF4B5563),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 4. Schedule & Status Card (#F9FAFB)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        children: [
                          // Row 1: Status Pill + Operating Hours
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isOpen
                                      ? const Color(0xFFDCFCE7)
                                      : const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isOpen
                                            ? const Color(0xFF16A34A)
                                            : const Color(0xFFDC2626),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      isOpen ? 'Open Now' : 'Closed',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isOpen
                                            ? const Color(0xFF15803D)
                                            : const Color(0xFFB91C1C),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Icon(
                                Icons.access_time_rounded,
                                size: 14,
                                color: Color(0xFF6B7280),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  stall.openTime.isNotEmpty &&
                                          stall.closeTime.isNotEmpty
                                      ? '${stall.openTime} – ${stall.closeTime}'
                                      : 'Hours not specified',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF374151),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: Color(0xFFE5E7EB),
                          ),
                          const SizedBox(height: 10),
                          // Row 2: Schedule Days
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 14,
                                color: Color(0xFF6B7280),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Schedule: ${_formatSchedule(stall.daysOpen)}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: const Color(0xFF4B5563),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 5. Products Available
                    Text(
                      'Products Available',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (stall.products.isEmpty)
                      Text(
                        'No specific products listed.',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF6B7280),
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: stall.products.map((product) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              product,
                              style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                color: const Color(0xFF374151),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                    const SizedBox(height: 24),

                    // 6. Primary Action: Navigate to Stall
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _navigateToStallOnMap,
                        icon: const Icon(
                          Icons.near_me_rounded,
                          size: 19,
                          color: Colors.white,
                        ),
                        label: Text(
                          'Navigate to Stall',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B5E20),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 7. Secondary Action: Report Link
                    Center(
                      child: TextButton.icon(
                        onPressed: _navigateToReportScreen,
                        icon: const Icon(
                          Icons.flag_outlined,
                          size: 15,
                          color: Color(0xFFEF4444),
                        ),
                        label: Text(
                          'Report an issue with this stall',
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            color: const Color(0xFFEF4444),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
