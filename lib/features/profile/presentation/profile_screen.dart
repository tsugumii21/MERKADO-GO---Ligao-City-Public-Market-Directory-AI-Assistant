// Part 10: User Profile Screen with modern, minimal UI design
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/router/route_names.dart';
import '../../../core/widgets/main_shell.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/favorite_provider.dart';
import '../../../providers/user_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends ConsumerState<ProfileScreen> {
  final ScrollController _scrollController = ScrollController();

  // Reset UI state when user leaves this tab
  void resetUI() {
    if (!mounted) return;

    // Scroll to top with animation
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    // Nothing else to reset on profile page
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSignOut(BuildContext context, WidgetRef ref) async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Log Out',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF424242),
          ),
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: const Color(0xFF757575),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF757575),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE53935),
            ),
            child: Text(
              'Log Out',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFE53935),
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldSignOut == true) {
      try {
        final authRepo = ref.read(authRepositoryProvider);
        await authRepo.signOut();
        
        // Clear favorites on sign out
        ref.read(favoriteProvider.notifier).clearFavorites();
        
        if (context.mounted) {
          context.go(RouteNames.getStarted);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to log out. Please try again.',
                style: GoogleFonts.poppins(fontSize: 13),
              ),
              backgroundColor: const Color(0xFFE53935),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    }
  }

  void _openFavoriteStalls() {
    mainShellKey.currentState?.openFavoriteStalls();
  }

  @override
  Widget build(BuildContext context) {
    final userDataAsync = ref.watch(userDataStreamProvider);
    final favoriteCount = ref.watch(favoriteCountProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 60,
        centerTitle: true,
        title: Text(
          'Profile',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: userDataAsync.when(
        data: (userData) {
          if (userData == null) {
            return Center(
              child: Text(
                'No user data found',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: const Color(0xFF757575),
                ),
              ),
            );
          }

          return SingleChildScrollView(
            controller: _scrollController,
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 24),

                  // SECTION 1: AVATAR CARD
                  _buildAvatarCard(context, userData),

                  const SizedBox(height: 16),

                  // SECTION 2: EDIT PROFILE BUTTON
                  _buildEditProfileButton(context),

                  const SizedBox(height: 20),

                  // SECTION 3: STATS ROW
                  _buildStatsRow(favoriteCount, userData.createdAt.year),

                  const SizedBox(height: 28),

                  // SECTION 4: ACCOUNT INFO LABEL
                  _buildSectionLabel('ACCOUNT INFORMATION'),

                  const SizedBox(height: 10),

                  // SECTION 5: ACCOUNT INFO CARD
                  _buildAccountInfoCard(userData),

                  const SizedBox(height: 12),

                  // SECTION 6: FAVORITE STALLS ROW
                  _buildFavoriteStallsRow(context, favoriteCount),

                  const SizedBox(height: 28),

                  // SECTION 7: LOGOUT BUTTON
                  _buildLogoutButton(context, ref),

                  const SizedBox(height: 48),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF1B5E20),
          ),
        ),
        error: (error, stack) => Center(
          child: Text(
            'Error loading profile',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color(0xFFE53935),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarCard(BuildContext context, dynamic userData) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar with camera badge
          Stack(
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: const Color(0xFFE8F5E9),
                backgroundImage: userData.profilePhotoUrl != null
                    ? CachedNetworkImageProvider(userData.profilePhotoUrl!)
                    : null,
                child: userData.profilePhotoUrl == null
                    ? const Icon(
                        Icons.person_rounded,
                        size: 48,
                        color: Color(0xFF1B5E20),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => context.push(RouteNames.editProfile),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B5E20),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Username
          Text(
            '@${userData.username}',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1B5E20),
            ),
          ),

          const SizedBox(height: 4),

          // Email
          Text(
            userData.email,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF9E9E9E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditProfileButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 52,
      constraints: const BoxConstraints(
        minHeight: 52,
        maxHeight: 52,
      ),
      child: ElevatedButton.icon(
        onPressed: () => context.push(RouteNames.editProfile),
        icon: const Icon(Icons.edit_rounded, size: 16, color: Colors.white),
        label: Text(
          'Edit Profile',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1B5E20),
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          maximumSize: const Size(double.infinity, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(int favoriteCount, int memberYear) {
    return Row(
      children: [
        // Card 1 - Favorite Stalls
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFFE53935),
                  size: 24,
                ),
                const SizedBox(height: 8),
                Text(
                  favoriteCount.toString(),
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Favorite Stalls',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF9E9E9E),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Card 2 - Member Since
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  color: Color(0xFF1B5E20),
                  size: 24,
                ),
                const SizedBox(height: 8),
                Text(
                  memberYear.toString(),
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Member Since',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF9E9E9E),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF9E9E9E),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildAccountInfoCard(dynamic userData) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: userData.email,
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteStallsRow(BuildContext context, int favoriteCount) {
    return GestureDetector(
      onTap: _openFavoriteStalls,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: Color(0xFFE53935),
                size: 18,
              ),
            ),
            const SizedBox(width: 14),
            Text(
              'Favorite Stalls',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF424242),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                favoriteCount.toString(),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1B5E20),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFBDBDBD),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () => _handleSignOut(context, ref),
        icon: const Icon(
          Icons.logout_rounded,
          color: Color(0xFFE53935),
          size: 18,
        ),
        label: Text(
          'Log Out',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFE53935),
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFFFFEBEE),
          side: const BorderSide(color: Color(0xFFFFCDD2), width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F8E9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF1B5E20),
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF424242),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF9E9E9E),
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFFBDBDBD),
            size: 18,
          ),
        ],
      ),
    );
  }
}
