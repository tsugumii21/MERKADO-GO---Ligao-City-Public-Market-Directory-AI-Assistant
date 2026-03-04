// Part 7: Redesigned Stall Detail Bottom Sheet - Clean, Modern, Minimal Green Theme
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/stall_model.dart';
import '../../../providers/auth_provider.dart';
import '../../report/presentation/report_screen.dart';

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
  bool _isFavorite = false;
  bool _isTogglingFavorite = false;
  late AnimationController _favoriteAnimationController;
  late Animation<double> _favoriteScaleAnimation;

  @override
  void initState() {
    super.initState();
    _checkIfFavorite();
    
    // Favorite button bounce animation
    _favoriteAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _favoriteScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
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

  Future<void> _checkIfFavorite() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .doc(widget.stall.stallId)
          .get();

      if (mounted) {
        setState(() {
          _isFavorite = doc.exists;
        });
      }
    } catch (e) {
      debugPrint('Error checking favorite: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isTogglingFavorite) return;

    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    // Play bounce animation
    _favoriteAnimationController.forward(from: 0);

    setState(() {
      _isTogglingFavorite = true;
    });

    try {
      final favRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .doc(widget.stall.stallId);

      if (_isFavorite) {
        // Remove from favorites
        await favRef.delete();
        if (mounted) {
          setState(() {
            _isFavorite = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Removed from favorites',
                style: GoogleFonts.poppins(),
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Add to favorites
        await favRef.set({
          'stallId': widget.stall.stallId,
          'stallName': widget.stall.name,
          'category': widget.stall.category,
          'addedAt': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          setState(() {
            _isFavorite = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Added to favorites',
                style: GoogleFonts.poppins(),
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString()}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTogglingFavorite = false;
        });
      }
    }
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
      case 'dry goods':
      case 'dry_goods':
        return Icons.shopping_bag_outlined;
      case 'spices':
        return Icons.grass_outlined;
      default:
        return Icons.storefront_outlined;
    }
  }

  Map<String, Color> _getCategoryColors(String category) {
    final categoryLower = category.toLowerCase();
    switch (categoryLower) {
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
      case 'dry goods':
      case 'dry_goods':
        return {
          'bg': const Color(0xFFF3E5F5),
          'text': const Color(0xFF7B1FA2),
        };
      default:
        return {
          'bg': const Color(0xFFE8F5E9),
          'text': const Color(0xFF2E7D32),
        };
    }
  }

  String _formatTime12Hour(String time) {
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
      // If already in 12-hour format or invalid, return as is
      return time;
    }
  }

  bool _isStallOpen() {
    final now = DateTime.now();
    final currentTime = TimeOfDay.now();
    
    // Get current day name
    final daysOfWeek = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final currentDay = daysOfWeek[now.weekday - 1];
    
    // Check if stall is open today
    final isOpenToday = widget.stall.daysOpen.any((day) => 
      day.trim().toLowerCase() == currentDay.toLowerCase()
    );
    
    if (!isOpenToday) {
      return false;
    }
    
    // Check if current time is within operating hours
    final openTime = widget.stall.openTime;
    final closeTime = widget.stall.closeTime;
    
    try {
      final openParts = openTime.split(':');
      final closeParts = closeTime.split(':');
      
      int openHour = int.parse(openParts[0]);
      int openMinute = int.parse(openParts[1].split(' ')[0]);
      
      int closeHour = int.parse(closeParts[0]);
      int closeMinute = int.parse(closeParts[1].split(' ')[0]);
      
      // Handle AM/PM if present
      if (openTime.toUpperCase().contains('PM') && openHour != 12) {
        openHour += 12;
      }
      if (openTime.toUpperCase().contains('AM') && openHour == 12) {
        openHour = 0;
      }
      
      if (closeTime.toUpperCase().contains('PM') && closeHour != 12) {
        closeHour += 12;
      }
      if (closeTime.toUpperCase().contains('AM') && closeHour == 12) {
        closeHour = 0;
      }
      
      final nowMinutes = currentTime.hour * 60 + currentTime.minute;
      final openMinutes = openHour * 60 + openMinute;
      final closeMinutes = closeHour * 60 + closeMinute;
      
      return nowMinutes >= openMinutes && nowMinutes <= closeMinutes;
    } catch (e) {
      debugPrint('Error checking if stall is open: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhotos = widget.stall.photoUrls.isNotEmpty;
    final categoryColors = _getCategoryColors(widget.stall.category);
    final categoryIcon = _getCategoryIcon(widget.stall.category);
    final isOpen = _isStallOpen();

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      snap: true,
      snapSizes: const [0.65, 0.92],
      builder: (context, scrollController) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: CustomScrollView(
              controller: scrollController,
              slivers: [
                // Drag handle
                SliverToBoxAdapter(
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),

                // Photo carousel
                SliverToBoxAdapter(
                  child: hasPhotos
                      ? Stack(
                          children: [
                            SizedBox(
                              height: 220,
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
                                      color: const Color(0xFFF5F5F5),
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          color: Color(0xFF2E7D32),
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        _buildImagePlaceholder(),
                                  );
                                },
                              ),
                            ),
                            // Photo indicators
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
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 3),
                                      width: _currentPhotoIndex == index
                                          ? 8
                                          : 6,
                                      height: _currentPhotoIndex == index
                                          ? 8
                                          : 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _currentPhotoIndex == index
                                            ? const Color(0xFF1B5E20)
                                            : const Color(0x401B5E20),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        )
                      : _buildImagePlaceholder(),
                ),

                // Content area
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),

                        // Category + Favorite row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Category chip
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: categoryColors['bg'],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    categoryIcon,
                                    size: 14,
                                    color: categoryColors['text'],
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    widget.stall.category,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: categoryColors['text'],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Favorite button
                            ScaleTransition(
                              scale: _favoriteScaleAnimation,
                              child: IconButton(
                                onPressed: _isTogglingFavorite
                                    ? null
                                    : _toggleFavorite,
                                icon: Icon(
                                  _isFavorite
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  color: _isFavorite
                                      ? const Color(0xFFE53935)
                                      : const Color(0xFFBDBDBD),
                                  size: 24,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Stall name
                        Text(
                          widget.stall.name,
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1B5E20),
                            height: 1.2,
                          ),
                        ),

                        const SizedBox(height: 6),

                        // Address row
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: Color(0xFF9E9E9E),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.stall.address,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: const Color(0xFF757575),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Operating hours card
                        Stack(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F9FA),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFF0F0F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Icon container
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8F5E9),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.access_time_rounded,
                                      size: 18,
                                      color: Color(0xFF2E7D32),
                                    ),
                                  ),

                                  const SizedBox(width: 12),

                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${_formatTime12Hour(widget.stall.openTime)} - ${_formatTime12Hour(widget.stall.closeTime)}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF212121),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              widget.stall.daysOpen.join(', '),
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: const Color(0xFF9E9E9E),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                ],
                              ),
                            ),

                            // Open/Closed badge
                            Positioned(
                              top: 14,
                              right: 14,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isOpen
                                      ? const Color(0xFFE8F5E9)
                                      : const Color(0xFFFFEBEE),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isOpen ? 'OPEN' : 'CLOSED',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isOpen
                                        ? const Color(0xFF2E7D32)
                                        : const Color(0xFFE53935),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Products section
                        Text(
                          'Products Available',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF212121),
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
                                color: Colors.white,
                                border: Border.all(
                                  color: const Color(0xFFE0E0E0),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                product,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color(0xFF424242),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 16),

                        // Divider
                        Container(
                          height: 1,
                          color: const Color(0xFFF0F0F0),
                        ),

                        const SizedBox(height: 16),

                        // Report button
                        InkWell(
                          onTap: _navigateToReportScreen,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                color: const Color(0xFFFFCDD2),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.flag_outlined,
                                  size: 16,
                                  color: Color(0xFFE53935),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Report a problem',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFFE53935),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      height: 220,
      color: const Color(0xFFF1F8E9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.storefront_outlined,
              size: 48,
              color: Color(0xFF81C784),
            ),
            const SizedBox(height: 8),
            Text(
              'No photo available',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF9E9E9E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
