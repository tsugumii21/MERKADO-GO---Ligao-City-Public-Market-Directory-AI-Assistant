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
import '../../../providers/stall_provider.dart';
import '../../../providers/user_provider.dart';

/// Refactored Modern Admin Dashboard Screen for Merkado Go
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Update every 60 seconds to recalculate open/closed stalls based on time
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
    unawaited(HapticFeedback.selectionClick());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Sign Out',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1B5E20),
          ),
        ),
        content: Text(
          'Are you sure you want to sign out of the Admin Portal?',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: const Color(0xFF4B5563),
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
                color: const Color(0xFF9CA3AF),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Sign Out',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFDC2626),
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
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
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
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                'Ligao City Public Market',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFE8F5E9),
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.logout_rounded,
              color: Colors.white,
              size: 20,
            ),
            tooltip: 'Sign Out',
            onPressed: () => _handleLogout(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(allStallsProvider);
                ref.invalidate(userDataStreamProvider);
                await Future.delayed(const Duration(milliseconds: 500));
              },
              color: const Color(0xFF1B5E20),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 24 : 16,
                      vertical: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 2. Welcome Admin Hero Banner
                        userDataAsync.when(
                          data: (userData) {
                            final adminName =
                                userData?.fullName.isNotEmpty == true
                                    ? userData!.fullName
                                    : 'System Admin';
                            return _buildWelcomeBanner(adminName);
                          },
                          loading: () => _buildWelcomeBanner('System Admin'),
                          error: (_, __) =>
                              _buildWelcomeBanner('System Admin'),
                        ),

                        const SizedBox(height: 24),

                        // 3. Statistics Overview (2x2 KPI Grid)
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
                                  .collection('users')
                                  .snapshots(),
                              builder: (context, usersSnapshot) {
                                final totalUsersCount =
                                    usersSnapshot.data?.docs.length ?? 0;

                                return StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('reports')
                                      .where('status', isEqualTo: 'pending')
                                      .snapshots(),
                                  builder: (context, reportsSnapshot) {
                                    final pendingReportsCount =
                                        reportsSnapshot.data?.docs.length ?? 0;

                                    return Column(
                                      children: [
                                        // 2x2 KPI Grid
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _KpiCard(
                                                icon:
                                                    Icons.storefront_rounded,
                                                iconColor:
                                                    const Color(0xFF1B5E20),
                                                bgColor:
                                                    const Color(0xFFE8F5E9),
                                                count:
                                                    stalls.length.toString(),
                                                label: 'Total Stalls',
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: _KpiCard(
                                                icon:
                                                    Icons.people_alt_rounded,
                                                iconColor:
                                                    const Color(0xFF7C3AED),
                                                bgColor:
                                                    const Color(0xFFEDE9FE),
                                                count: totalUsersCount
                                                    .toString(),
                                                label: 'Active Users',
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _KpiCard(
                                                icon: Icons
                                                    .check_circle_rounded,
                                                iconColor:
                                                    const Color(0xFF16A34A),
                                                bgColor:
                                                    const Color(0xFFDCFCE7),
                                                count: openCount.toString(),
                                                label: 'Open Now',
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: _KpiCard(
                                                icon: Icons.cancel_rounded,
                                                iconColor:
                                                    const Color(0xFFDC2626),
                                                bgColor:
                                                    const Color(0xFFFEE2E2),
                                                count: closedCount
                                                    .toString(),
                                                label: 'Closed Now',
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 28),

                                        // 4. Quick Actions Section
                                        _buildSectionLabel('QUICK ACTIONS'),
                                        const SizedBox(height: 12),

                                        // Action 1: Add New Stall
                                        _buildActionCard(
                                          icon: Icons.add_business_rounded,
                                          iconColor:
                                              const Color(0xFF1B5E20),
                                          iconBgColor:
                                              const Color(0xFFE8F5E9),
                                          title: 'Add New Stall',
                                          subtitle:
                                              'Register a new stall to the market directory',
                                          onTap: () => context.push(
                                              RouteNames.adminAddStall),
                                        ),

                                        const SizedBox(height: 12),

                                        // Action 2: Stall Reports (With Pending Badge)
                                        _buildActionCard(
                                          icon:
                                              Icons.report_problem_rounded,
                                          iconColor:
                                              const Color(0xFFF59E0B),
                                          iconBgColor:
                                              const Color(0xFFFEF3C7),
                                          title: 'Stall Reports',
                                          subtitle:
                                              'Review and resolve user-submitted stall reports',
                                          badgeText:
                                              '$pendingReportsCount Pending',
                                          badgeColor: pendingReportsCount > 0
                                              ? const Color(0xFFDC2626)
                                              : const Color(0xFF6B7280),
                                          badgeBg: pendingReportsCount > 0
                                              ? const Color(0xFFFEE2E2)
                                              : const Color(0xFFF3F4F6),
                                          onTap: () => context.push(
                                              RouteNames.adminReports),
                                        ),

                                        const SizedBox(height: 12),

                                        // Action 3: Market Map Editor
                                        _buildActionCard(
                                          icon: Icons.map_rounded,
                                          iconColor:
                                              const Color(0xFF2563EB),
                                          iconBgColor:
                                              const Color(0xFFDBEAFE),
                                          title: 'Market Map Editor',
                                          subtitle:
                                              'Inspect and edit stall marker coordinates',
                                          onTap: () => context.go(
                                              RouteNames.adminMap),
                                        ),

                                        const SizedBox(height: 28),
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
                              child: CircularProgressIndicator(
                                  color: Color(0xFF1B5E20)),
                            ),
                          ),
                          error: (_, __) => Padding(
                            padding: const EdgeInsets.all(40),
                            child: Center(
                              child: Text(
                                'Error loading statistics',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: const Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  // Welcome Hero Banner
  Widget _buildWelcomeBanner(String adminName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF86EFAC),
                width: 1,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.admin_panel_settings_rounded,
                color: Color(0xFF1B5E20),
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Welcome back,',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF86EFAC),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        'Control Center',
                        style: GoogleFonts.poppins(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF16A34A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  adminName,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F2937),
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Ligao Public Market Management',
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF6B7280),
        letterSpacing: 0.8,
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
    String? badgeText,
    Color? badgeColor,
    Color? badgeBg,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE5E7EB),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: badgeBg ?? const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              badgeText,
                              style: GoogleFonts.poppins(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: badgeColor ?? const Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF9CA3AF),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Symmetrical KPI Card for the 2x2 Grid
class _KpiCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String count;
  final String label;

  const _KpiCard({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.count,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 20,
                ),
              ),
              Text(
                count,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1F2937),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}
