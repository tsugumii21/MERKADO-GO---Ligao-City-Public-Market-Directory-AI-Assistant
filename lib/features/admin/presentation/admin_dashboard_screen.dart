import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/stall_utils.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/stall_provider.dart';
import '../../../providers/user_provider.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Update every 60 seconds to recalculate open/closed stalls
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1.0),
        ),
        title: Text(
          'Sign Out',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out of the Admin Portal?',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: AppColors.inkMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.inkMuted,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: Text(
              'Sign Out',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        context.go(RouteNames.login);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userDataAsync = ref.watch(userDataStreamProvider);
    final allStallsAsync = ref.watch(allStallsProvider);
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        shape: const Border(
          bottom: BorderSide(
            color: AppColors.border,
            width: 1.0,
          ),
        ),
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Admin Dashboard',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                'Ligao City Public Market',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.logout_rounded,
              color: AppColors.error,
              size: 20,
            ),
            tooltip: 'Sign Out',
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allStallsProvider);
          ref.invalidate(userDataStreamProvider);
          await Future.delayed(const Duration(milliseconds: 500));
        },
        color: AppColors.primary,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 24 : 16,
                vertical: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // === WELCOME CARD ===
                  userDataAsync.when(
                    data: (userData) {
                      final adminName = userData?.fullName ?? 'Admin';
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.border,
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.admin_panel_settings_rounded,
                                color: AppColors.primary,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome back,',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.inkMuted,
                                    ),
                                  ),
                                  Text(
                                    adminName,
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.ink,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Market Overview & Control Center',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: AppColors.inkSubtle,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    loading: () => Container(
                      height: 88,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border, width: 1.0),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    ),
                    error: (_, __) => Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border, width: 1.0),
                      ),
                      child: Text(
                        'Welcome to Admin Portal',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // === STATISTICS SECTION ===
                  _buildSectionLabel('STATISTICS OVERVIEW'),

                  const SizedBox(height: 12),

                  allStallsAsync.when(
                    data: (stalls) {
                      final openCount = stalls
                          .where((s) => StallUtils.isStallOpenNow(s))
                          .length;
                      final closedCount = stalls.length - openCount;

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('reports')
                            .where('status', isEqualTo: 'pending')
                            .snapshots(),
                        builder: (context, reportsSnapshot) {
                          final pendingReportsCount = reportsSnapshot.data?.docs.length ?? 0;

                          return StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .snapshots(),
                            builder: (context, usersSnapshot) {
                              final totalUsersCount = usersSnapshot.data?.docs.length ?? 0;

                              return Column(
                                children: [
                                  // Row 1: Total Stalls + Total Users
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _StatCard(
                                          icon: Icons.storefront_rounded,
                                          iconColor: AppColors.primary,
                                          bgColor: AppColors.surfaceDim,
                                          count: stalls.length.toString(),
                                          label: 'Total Stalls',
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _StatCard(
                                          icon: Icons.people_alt_rounded,
                                          iconColor: const Color(0xFF5E35B1),
                                          bgColor: const Color(0xFFEDE7F6),
                                          count: totalUsersCount.toString(),
                                          label: 'Total Users',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Row 2: Open Now + Closed Now
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _StatCard(
                                          icon: Icons.check_circle_rounded,
                                          iconColor: AppColors.primary,
                                          bgColor: AppColors.primaryLight,
                                          count: openCount.toString(),
                                          label: 'Open Now',
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _StatCard(
                                          icon: Icons.cancel_rounded,
                                          iconColor: AppColors.error,
                                          bgColor: AppColors.errorLight,
                                          count: closedCount.toString(),
                                          label: 'Closed Now',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Row 3: Pending Reports
                                  _StatCard(
                                    icon: Icons.report_problem_rounded,
                                    iconColor: AppColors.warning,
                                    bgColor: AppColors.warningLight,
                                    count: pendingReportsCount.toString(),
                                    label: 'Pending Reports',
                                    fullWidth: true,
                                    onTap: () => context.push(RouteNames.adminReports),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    ),
                    error: (error, _) => Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: Text(
                          'Error loading statistics',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // === QUICK ACTIONS SECTION ===
                  _buildSectionLabel('QUICK ACTIONS'),

                  const SizedBox(height: 12),

                  // Action 1: Add New Stall
                  _buildActionCard(
                    icon: Icons.add_business_rounded,
                    iconColor: AppColors.primary,
                    iconBgColor: AppColors.surfaceDim,
                    title: 'Add New Stall',
                    subtitle: 'Register a new stall to the market directory',
                    onTap: () => context.push(RouteNames.adminAddStall),
                  ),

                  const SizedBox(height: 10),

                  // Action 2: View Reports
                  _buildActionCard(
                    icon: Icons.report_problem_rounded,
                    iconColor: AppColors.warning,
                    iconBgColor: AppColors.warningLight,
                    title: 'Stall Reports',
                    subtitle: 'Review and resolve user-submitted stall reports',
                    onTap: () => context.push(RouteNames.adminReports),
                  ),

                  const SizedBox(height: 10),

                  // Action 3: Market Map Editor
                  _buildActionCard(
                    icon: Icons.map_rounded,
                    iconColor: AppColors.primary,
                    iconBgColor: AppColors.primaryLight,
                    title: 'Market Map Editor',
                    subtitle: 'Inspect and edit stall marker coordinates',
                    onTap: () => context.go(RouteNames.adminMap),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: AppColors.inkSubtle,
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.border,
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.inkSubtle,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// === REUSABLE FLAT STAT CARD WIDGET ===
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String count;
  final String label;
  final bool fullWidth;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.count,
    required this.label,
    this.fullWidth = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
          width: 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  count,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.inkMuted,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.inkSubtle,
              size: 20,
            ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}
