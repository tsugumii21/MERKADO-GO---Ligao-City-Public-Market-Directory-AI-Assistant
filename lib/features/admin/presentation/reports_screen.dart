import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _selectedFilter = 'All';

  Future<void> _updateStatus(String reportId, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Report marked as ${newStatus.toUpperCase()}',
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
          ),
          backgroundColor: newStatus == 'resolved'
              ? const Color(0xFF1B5E20)
              : const Color(0xFF1565C0),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Error updating report status: $e',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  Future<void> _deleteReport(String reportId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFDC2626),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Delete Report?',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
          ],
        ),
        content: Text(
          'This user report will be permanently removed from the system. This action cannot be undone.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: const Color(0xFF4B5563),
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7280),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Report deleted successfully',
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Error deleting report: $e',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFFEF3C7);
      case 'reviewed':
        return const Color(0xFFDBEAFE);
      case 'resolved':
        return const Color(0xFFDCFCE7);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFB45309);
      case 'reviewed':
        return const Color(0xFF1D4ED8);
      case 'resolved':
        return const Color(0xFF15803D);
      default:
        return const Color(0xFF4B5563);
    }
  }

  Color _getStatusBorderColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFFDE68A);
      case 'reviewed':
        return const Color(0xFFBFDBFE);
      case 'resolved':
        return const Color(0xFF86EFAC);
      default:
        return const Color(0xFFE5E7EB);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black12,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Material(
            color: const Color(0xFFF3F4F6),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => context.pop(),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFF1F2937),
                size: 20,
              ),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Stall Reports',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
                letterSpacing: -0.2,
              ),
            ),
            Text(
              'User community reports & stall issue tracking',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: const Color(0xFFE5E7EB),
            height: 1,
          ),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              // Filter chips row
              Container(
                padding: EdgeInsets.fromLTRB(
                  isDesktop ? 24 : 16,
                  12,
                  isDesktop ? 24 : 16,
                  12,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: Color(0xFFE5E7EB),
                      width: 1.0,
                    ),
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        isSelected: _selectedFilter == 'All',
                        onTap: () => setState(() => _selectedFilter = 'All'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Pending',
                        isSelected: _selectedFilter == 'Pending',
                        onTap: () => setState(() => _selectedFilter = 'Pending'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Reviewed',
                        isSelected: _selectedFilter == 'Reviewed',
                        onTap: () => setState(() => _selectedFilter = 'Reviewed'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Resolved',
                        isSelected: _selectedFilter == 'Resolved',
                        onTap: () => setState(() => _selectedFilter = 'Resolved'),
                      ),
                    ],
                  ),
                ),
              ),

              // Reports list
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('reports')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading reports',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppColors.error,
                          ),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF1B5E20),
                        ),
                      );
                    }

                    final allReports = snapshot.data?.docs ?? [];

                    final filteredReports = _selectedFilter == 'All'
                        ? allReports
                        : allReports.where((doc) {
                            final status = (doc.data() as Map<String, dynamic>)['status'] as String? ?? 'pending';
                            return status.toLowerCase() == _selectedFilter.toLowerCase();
                          }).toList();

                    if (filteredReports.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF3F4F6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.inbox_outlined,
                                size: 32,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'No reports found',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedFilter == 'All'
                                  ? 'No user reports submitted yet'
                                  : 'No $_selectedFilter reports found',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        isDesktop ? 24 : 16,
                        16,
                        isDesktop ? 24 : 16,
                        32,
                      ),
                      itemCount: filteredReports.length,
                      itemBuilder: (context, index) {
                        final report = filteredReports[index];
                        final reportId = report.id;
                        final data = report.data() as Map<String, dynamic>;

                        final stallName = data['stallName'] as String? ?? 'Unknown Stall';
                        final stallId = data['stallId'] as String? ?? '';
                        final message = data['description'] as String? ??
                            data['message'] as String? ??
                            'No description provided';
                        final categories = data['categories'] is List
                            ? (data['categories'] as List).map((e) => e.toString()).toList()
                            : <String>[];
                        final userEmail = data['userEmail'] as String? ?? 'Anonymous User';
                        final status = data['status'] as String? ?? 'pending';
                        final createdAt = data['createdAt'] as Timestamp?;

                        return _ReportCard(
                          reportId: reportId,
                          stallName: stallName,
                          stallId: stallId,
                          categories: categories,
                          message: message,
                          userEmail: userEmail,
                          status: status,
                          createdAt: createdAt,
                          onUpdateStatus: _updateStatus,
                          onDelete: _deleteReport,
                          formatDate: _formatDate,
                          getStatusBgColor: _getStatusBgColor,
                          getStatusTextColor: _getStatusTextColor,
                          getStatusBorderColor: _getStatusBorderColor,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1B5E20) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? const Color(0xFF1B5E20) : const Color(0xFFE5E7EB),
              width: 1.0,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF4B5563),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String reportId;
  final String stallName;
  final String stallId;
  final List<String> categories;
  final String message;
  final String userEmail;
  final String status;
  final Timestamp? createdAt;
  final Function(String, String) onUpdateStatus;
  final Function(String) onDelete;
  final String Function(Timestamp?) formatDate;
  final Color Function(String) getStatusBgColor;
  final Color Function(String) getStatusTextColor;
  final Color Function(String) getStatusBorderColor;

  const _ReportCard({
    required this.reportId,
    required this.stallName,
    required this.stallId,
    required this.categories,
    required this.message,
    required this.userEmail,
    required this.status,
    required this.createdAt,
    required this.onUpdateStatus,
    required this.onDelete,
    required this.formatDate,
    required this.getStatusBgColor,
    required this.getStatusTextColor,
    required this.getStatusBorderColor,
  });

  @override
  Widget build(BuildContext context) {
    final statusBgColor = getStatusBgColor(status);
    final statusTextColor = getStatusTextColor(status);
    final statusBorderColor = getStatusBorderColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with stall name and status badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B5E20).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        size: 18,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stallName,
                            style: GoogleFonts.poppins(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1F2937),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (stallId.isNotEmpty)
                            Text(
                              'Stall ID: $stallId',
                              style: GoogleFonts.robotoMono(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusBorderColor),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: statusTextColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),

          // Issue categories chips
          if (categories.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: categories.map((cat) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFFFECACA),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 12,
                        color: Color(0xFFDC2626),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        cat,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF991B1B),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 10),

          // Report message description box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFE5E7EB),
              ),
            ),
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF374151),
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Reporter email & timestamp
          Row(
            children: [
              const Icon(
                Icons.person_outline_rounded,
                size: 13,
                color: Color(0xFF9CA3AF),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  userEmail,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF6B7280),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.access_time_rounded,
                size: 13,
                color: Color(0xFF9CA3AF),
              ),
              const SizedBox(width: 4),
              Text(
                formatDate(createdAt),
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),

          // Action buttons row (Wrap to prevent RenderFlex overflow on small screens)
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Mark as Reviewed button (only show if pending)
                if (status.toLowerCase() == 'pending') ...[
                  _ActionButton(
                    label: 'Review',
                    icon: Icons.visibility_outlined,
                    textColor: const Color(0xFF1D4ED8),
                    bgColor: const Color(0xFFEFF6FF),
                    borderColor: const Color(0xFFBFDBFE),
                    onTap: () => onUpdateStatus(reportId, 'reviewed'),
                  ),
                ],
                // Mark as Resolved button (show if not resolved)
                if (status.toLowerCase() != 'resolved') ...[
                  _ActionButton(
                    label: 'Resolve',
                    icon: Icons.check_circle_outline_rounded,
                    textColor: const Color(0xFF15803D),
                    bgColor: const Color(0xFFF0FDF4),
                    borderColor: const Color(0xFF86EFAC),
                    onTap: () => onUpdateStatus(reportId, 'resolved'),
                  ),
                ],
                // Delete button
                _ActionButton(
                  label: 'Delete',
                  icon: Icons.delete_outline_rounded,
                  textColor: const Color(0xFFDC2626),
                  bgColor: const Color(0xFFFEF2F2),
                  borderColor: const Color(0xFFFECACA),
                  onTap: () => onDelete(reportId),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color textColor;
  final Color bgColor;
  final Color borderColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.textColor,
    required this.bgColor,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: textColor,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
