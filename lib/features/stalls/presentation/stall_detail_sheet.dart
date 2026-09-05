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
import '../../../core/constants/market_categories.dart';
import '../../../core/widgets/market_category_icon.dart';

import '../../map/providers/navigation_provider.dart';
import '../../map/presentation/widgets/entrance_selector_sheet.dart';
import '../../map/presentation/widgets/navigation_loading_dialog.dart';

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
      barrierColor: Colors.black.withValues(alpha: 0.40),
      sheetAnimationStyle: AnimationStyle(
        duration: const Duration(milliseconds: 360),
        curve: const Cubic(0.16, 1.0, 0.3, 1.0),
        reverseDuration: const Duration(milliseconds: 260),
        reverseCurve: Curves.easeInCubic,
      ),
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

  Future<void> _navigateToStallOnMap() async {
    // ignore: unawaited_futures
    HapticFeedback.mediumImpact();
    // 1. Prompt user to choose starting entry point before directing them to map
    final chosenEntrance = await EntranceSelectorSheet.show(
      context,
      targetStallId: widget.stall.stallId,
      targetStallName: widget.stall.name,
    );
    if (chosenEntrance == null || !mounted) return;

    // 2. Display 3-second animated road trip loading screen with dynamic wayfinding phrases
    await NavigationLoadingDialog.show(
      context,
      stallName: widget.stall.name,
      entrance: chosenEntrance,
    );
    if (!mounted) return;

    // 3. Compute route starting at chosen entrance
    await ref.read(activeRouteProvider.notifier).navigateToStall(
          stallId: widget.stall.stallId,
          stallName: widget.stall.name,
          entranceOverride: chosenEntrance,
        );

    // 4. Close stall details modal and switch to Map tab
    widget.onClose();
    mainShellKey.currentState?.goToTab(0);
  }

  ({
    IconData icon,
    Color color,
    Color bg,
    Color outline,
    String displayName,
    List<String> subcategories,
  }) _getCategoryVisuals(String category) {
    final v = MarketCategories.getVisuals(category);
    return (
      icon: v.icon,
      color: v.outline,
      bg: v.outline.withValues(alpha: 0.12),
      outline: v.outline,
      displayName: v.displayName,
      subcategories: v.subcategories,
    );
  }

  @override
  Widget build(BuildContext context) {
    final stall = widget.stall;
    final isFav = ref.watch(favoriteProvider).isFavorite(stall.stallId);
    final favNotifier = ref.read(favoriteProvider.notifier);
    final statusInfo = StallUtils.getStallStatusInfo(stall);
    final categoryVisuals = _getCategoryVisuals(stall.category);
    final photoList = stall.photoUrls.isNotEmpty
        ? stall.photoUrls
        : (stall.primaryPhotoUrl.isNotEmpty ? [stall.primaryPhotoUrl] : <String>[]);
    final hasPhotos = photoList.isNotEmpty;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
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
                    style: GoogleFonts.plusJakartaSans(
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
                            color: categoryVisuals.bg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: categoryVisuals.color.withValues(alpha: 0.2),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: hasPhotos
                                ? PageView.builder(
                                    controller: _pageController,
                                    itemCount: photoList.length,
                                    onPageChanged: (idx) {
                                      setState(() => _currentPhotoIndex = idx);
                                    },
                                    itemBuilder: (context, index) {
                                      return CachedNetworkImage(
                                        imageUrl: photoList[index],
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => Center(
                                          child: CircularProgressIndicator(
                                            color: categoryVisuals.color,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        errorWidget: (_, __, ___) => Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              MarketCategoryIcon(
                                                category: stall.category,
                                                fallbackIcon: categoryVisuals.icon,
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
                                      );
                                    },
                                  )
                                : Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        MarketCategoryIcon(
                                          category: stall.category,
                                          fallbackIcon: categoryVisuals.icon,
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
                        if (hasPhotos && photoList.length > 1)
                          Positioned(
                            bottom: 8,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                photoList.length,
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
                            border: Border.all(
                              color: categoryVisuals.color.withValues(alpha: 0.35),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              MarketCategoryIcon(
                                category: stall.category,
                                fallbackIcon: categoryVisuals.icon,
                                size: 13,
                                color: categoryVisuals.color,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                StallUtils.getCategoryLabel(stall.category),
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

                    // 4. Schedule & Status Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      child: Column(
                        children: [
                          // Row 1: Status Pill + Operating Hours
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3.5,
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
                              const SizedBox(width: 10),
                              const Icon(
                                Icons.schedule_rounded,
                                size: 14,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  stall.openTime.isNotEmpty && stall.closeTime.isNotEmpty
                                      ? '${stall.openTime} – ${stall.closeTime}'
                                      : (stall.openTime.isNotEmpty ? stall.openTime : 'Hours not specified'),
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF334155),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (stall.daysOpen.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            const Divider(
                              height: 1,
                              thickness: 1,
                              color: Color(0xFFE2E8F0),
                            ),
                            const SizedBox(height: 10),
                            // Row 2: Schedule Days
                            Row(
                              children: [
                                const Icon(
                                  Icons.event_available_rounded,
                                  size: 14,
                                  color: Color(0xFF64748B),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Schedule: ${StallUtils.formatOperatingDays(stall.daysOpen.join(', '))}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: const Color(0xFF475569),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
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
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
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
                                  size: 12,
                                  color: Color(0xFF1B5E20),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  product,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: const Color(0xFF334155),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),

                    // Subcategories & Tags section
                    Builder(
                      builder: (context) {
                        final stallSubcategories = <String>{
                          ...stall.tags,
                          ...stall.categories.where(
                            (c) => c.trim().toLowerCase() != stall.category.trim().toLowerCase(),
                          ),
                        }.where((s) => s.trim().isNotEmpty).toList();

                        if (stallSubcategories.isEmpty) return const SizedBox.shrink();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 18),
                            Text(
                              'Subcategories & Tags',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: stallSubcategories.map((sub) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: categoryVisuals.color.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: categoryVisuals.color.withValues(alpha: 0.25),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    StallUtils.getTagLabel(sub),
                                    style: GoogleFonts.poppins(
                                      fontSize: 11.5,
                                      color: categoryVisuals.color,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        );
                      },
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
