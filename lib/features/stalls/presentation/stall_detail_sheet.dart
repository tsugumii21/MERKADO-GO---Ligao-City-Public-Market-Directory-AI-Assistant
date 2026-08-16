// Part 7: Redesigned Stall Detail Bottom Sheet - Clean, Modern, Minimal Green Theme
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/stall_model.dart';
import '../../../providers/favorite_provider.dart';
import '../../report/presentation/report_screen.dart';
import '../../../core/utils/stall_utils.dart';
import '../../../core/theme/app_colors.dart';

class StallDetailSheet extends ConsumerStatefulWidget {
  final StallModel stall;
  final VoidCallback onClose;

  const StallDetailSheet({
    super.key,
    required this.stall,
    required this.onClose,
  });

  @override
  ConsumerState<StallDetailSheet> createState() => _StallDetailSheetState();
}

class _StallDetailSheetState extends ConsumerState<StallDetailSheet>
    with SingleTickerProviderStateMixin {
  int _currentPhotoIndex = 0;
  late AnimationController _favoriteAnimationController;
  late Animation<double> _favoriteScaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Favorite button bounce animation
    _favoriteAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _favoriteScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _favoriteAnimationController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _favoriteAnimationController.dispose();
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

  IconData _getCategoryIcon(String category) {
    final categoryLower = category.toLowerCase();
    switch (categoryLower) {
      case 'eatery':
        return Icons.restaurant_rounded;
      case 'pork':
        return Icons.set_meal_outlined;
      case 'poultry':
        return Icons.egg_outlined;
      case 'beef':
        return Icons.set_meal_outlined;
      case 'fish':
      case 'seafood':
        return Icons.set_meal_outlined;
      case 'vegetables':
        return Icons.eco_outlined;
      case 'fruits':
        return Icons.energy_savings_leaf_outlined;
      case 'rice':
        return Icons.grain_rounded;
      case 'sari-sari':
      case 'sari_sari':
        return Icons.store_rounded;
      case 'dry goods':
      case 'dry_goods':
        return Icons.shopping_bag_outlined;
      case 'spices':
        return Icons.grass_outlined;
      case 'ukay-ukay':
      case 'ukay_ukay':
        return Icons.checkroom_rounded;
      default:
        return Icons.storefront_outlined;
    }
  }

  Map<String, Color> _getCategoryColors(String category) {
    final categoryLower = category.toLowerCase();
    switch (categoryLower) {
      case 'eatery':
        return {
          'bg': const Color(0xFFFFE0B2),
          'text': const Color(0xFFFF7043),
        };
      case 'pork':
        return {
          'bg': const Color(0xFFFFEBEE),
          'text': const Color(0xFFE57373),
        };
      case 'poultry':
        return {
          'bg': const Color(0xFFFFF8E1),
          'text': const Color(0xFFFFB300),
        };
      case 'beef':
        return {
          'bg': const Color(0xFFFBE9E7),
          'text': const Color(0xFF8D6E63),
        };
      case 'fish':
      case 'seafood':
        return {
          'bg': const Color(0xFFE3F2FD),
          'text': const Color(0xFF1E88E5),
        };
      case 'vegetables':
        return {
          'bg': const Color(0xFFE8F5E9),
          'text': const Color(0xFF2E7D32),
        };
      case 'fruits':
        return {
          'bg': const Color(0xFFFFF3E0),
          'text': const Color(0xFFEF6C00),
        };
      case 'rice':
        return {
          'bg': const Color(0xFFFFFDE7),
          'text': const Color(0xFFFDD835),
        };
      case 'sari-sari':
      case 'sari_sari':
        return {
          'bg': const Color(0xFFE0F7FA),
          'text': const Color(0xFF26C6DA),
        };
      case 'dry goods':
      case 'dry_goods':
        return {
          'bg': const Color(0xFFF3E5F5),
          'text': const Color(0xFF7B1FA2),
        };
      case 'ukay-ukay':
      case 'ukay_ukay':
        return {
          'bg': const Color(0xFFEFEBE9),
          'text': const Color(0xFF8D6E63),
        };
      default:
        return {
          'bg': const Color(0xFFE8F5E9),
          'text': const Color(0xFF2E7D32),
        };
    }
  }

  String _formatTime12Hour(String time) {
    // If already in 12-hour format with AM/PM, return as is
    if (time.toUpperCase().contains('AM') || time.toUpperCase().contains('PM')) {
      return time;
    }
    
    // Convert 24-hour format to 12-hour format with AM/PM
    try {
      final parts = time.split(':');
      int hour = int.parse(parts[0]);
      final minute = parts[1];
      
      String period = 'AM';
      
      if (hour >= 12) {
        period = 'PM';
        if (hour > 12) {
          hour -= 12;
        }
      }
      
      if (hour == 0) {
        hour = 12;
      }
      
      return '$hour:$minute $period';
    } catch (e) {
      // If invalid, return as is
      return time;
    }
  }

  String _getSectionLabel(String value) {
    const labels = {
      'dry_goods_section': 'Dry Goods Section',
      'fruit_section': 'Fruit Section',
      'vegetable_section': 'Vegetable Section',
      'rice_section': 'Rice Section',
      'fish_chicken_section': 'Fish & Chicken Section',
      'meat_section': 'Meat Section',
      'cooked_food_section': 'Food Section',
    };
    return labels[value] ??
        value
            .replaceAll('_', ' ')
            .split(' ')
            .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
            .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;
    final hasPhotos = widget.stall.photoUrls.isNotEmpty;
    final categoryColors = _getCategoryColors(widget.stall.category);
    final categoryIcon = _getCategoryIcon(widget.stall.category);

    if (isDesktop) {
      return Container(
        color: AppColors.surface,
        child: Column(
          children: [
            // Top sticky header for Desktop Slide-over
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.border,
                    width: 1.0,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Stall Details',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.inkMuted,
                      size: 22,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildPhotoArea(hasPhotos),
                  ),
                  SliverToBoxAdapter(
                    child: _buildBodyContent(categoryColors, categoryIcon),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Mobile Bottom Sheet
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.55, 0.85, 0.95],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              // Mobile drag handle & header
              SliverToBoxAdapter(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Stall Details',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          IconButton(
                            onPressed: widget.onClose,
                            icon: const Icon(
                              Icons.close_rounded,
                              color: AppColors.inkMuted,
                              size: 22,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.border),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: _buildPhotoArea(hasPhotos),
              ),
              SliverToBoxAdapter(
                child: _buildBodyContent(categoryColors, categoryIcon),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPhotoArea(bool hasPhotos) {
    if (!hasPhotos) {
      return _buildImagePlaceholder();
    }

    return Stack(
      children: [
        SizedBox(
          height: 200,
          child: PageView.builder(
            itemCount: widget.stall.photoUrls.length,
            onPageChanged: (index) {
              setState(() {
                _currentPhotoIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return CachedNetworkImage(
                imageUrl: widget.stall.photoUrls[index],
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: AppColors.surfaceDim,
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => _buildImagePlaceholder(),
              );
            },
          ),
        ),
        if (widget.stall.photoUrls.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.stall.photoUrls.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentPhotoIndex == index ? 8 : 6,
                  height: _currentPhotoIndex == index ? 8 : 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPhotoIndex == index
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBodyContent(
      Map<String, Color> categoryColors, IconData categoryIcon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // Category Badge + Favorite Button Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: categoryColors['bg'] ?? AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      categoryIcon,
                      size: 14,
                      color: categoryColors['text'] ?? AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      StallUtils.getCategoryLabel(widget.stall.category),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: categoryColors['text'] ?? AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),

              // Favorite Heart Button (48×48 Touch Target)
              Consumer(
                builder: (context, ref, child) {
                  final favState = ref.watch(favoriteProvider);
                  final isFav = favState.isFavorite(widget.stall.stallId);

                  return SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: ScaleTransition(
                        scale: _favoriteScaleAnimation,
                        child: IconButton(
                          onPressed: () async {
                            unawaited(
                              _favoriteAnimationController.forward(from: 0),
                            );
                            await ref
                                .read(favoriteProvider.notifier)
                                .toggleFavorite(widget.stall.stallId);
                          },
                          icon: Icon(
                            isFav
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: isFav
                                ? AppColors.error
                                : AppColors.inkSubtle,
                            size: 24,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: isFav
                              ? 'Remove from Favorites'
                              : 'Add to Favorites',
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Stall Name
          Text(
            widget.stall.name,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              height: 1.25,
            ),
          ),

          const SizedBox(height: 6),

          // Address Row
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 14,
                color: AppColors.inkSubtle,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.stall.address,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Operating Details & Schedule Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.border,
                width: 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StallUtils.buildStatusBadge(widget.stall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: AppColors.inkMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.stall.openTime.isNotEmpty &&
                                widget.stall.closeTime.isNotEmpty
                            ? '${_formatTime12Hour(widget.stall.openTime)} - ${_formatTime12Hour(widget.stall.closeTime)}'
                            : 'Hours not specified',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: AppColors.inkMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.stall.daysOpen.isNotEmpty
                            ? widget.stall.daysOpen.join(', ')
                            : 'Days not specified',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          if (widget.stall.section != null &&
              widget.stall.section!.isNotEmpty) ...[
            Row(
              children: [
                const Icon(
                  Icons.store_mall_directory_rounded,
                  size: 14,
                  color: AppColors.inkSubtle,
                ),
                const SizedBox(width: 4),
                Text(
                  _getSectionLabel(widget.stall.section!),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Products Available
          if (widget.stall.products.isNotEmpty) ...[
            Text(
              'Products Available',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.stall.products.map((product) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(
                      color: AppColors.border,
                      width: 1.0,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    product,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.ink,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          const Divider(height: 1, color: AppColors.border),

          const SizedBox(height: 16),

          // Report a Problem Outline Button
          InkWell(
            onTap: _navigateToReportScreen,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(
                  color: AppColors.errorBorder,
                  width: 1.0,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.flag_outlined,
                    size: 16,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Report a problem',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      height: 200,
      color: AppColors.surfaceDim,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.storefront_outlined,
              size: 40,
              color: AppColors.primary,
            ),
            const SizedBox(height: 8),
            Text(
              'No photo available',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.inkSubtle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
