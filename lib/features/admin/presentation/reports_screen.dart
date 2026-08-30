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
    await FirebaseFirestore.instance
        .collection('reports')
        .doc(reportId)
        .update({
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Report marked as $newStatus',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  Future<void> _deleteReport(String reportId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1.0),
        ),
        title: Text(
          'Delete Report?',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        content: Text(
          'This report will be permanently deleted. This action cannot be undone.',
          style: GoogleFonts.poppins(
            fontSize: 13,
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
              'Delete',
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

    if (confirm != true) return;

    await FirebaseFirestore.instance
        .collection('reports')
        .doc(reportId)
        .delete();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Report deleted',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
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
        return AppColors.warningLight;
      case 'reviewed':
        return AppColors.surfaceDim;
      case 'resolved':
        return AppColors.primaryLight;
      default:
        return AppColors.canvas;
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.warning;
      case 'reviewed':
        return AppColors.primary;
      case 'resolved':
        return AppColors.primary;
      default:
        return AppColors.inkMuted;
    }
  }

  Color _getStatusBorderColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.warningBorder;
      case 'reviewed':
        return AppColors.border;
      case 'resolved':
        return AppColors.primary.withValues(alpha: 0.3);
      default:
        return AppColors.border;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        shape: const Border(
          bottom: BorderSide(
            color: AppColors.border,
            width: 1.0,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.ink,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Stall Reports',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
                letterSpacing: -0.2,
              ),
            ),
            Text(
              'User feedback & problem reports',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.inkMuted,
              ),
            ),
          ],
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
                color: AppColors.surface,
                padding: EdgeInsets.fromLTRB(
                  isDesktop ? 24 : 16,
                  12,
                  isDesktop ? 24 : 16,
                  12,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.border,
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
                          color: AppColors.primary,
                        ),
                      );
                    }

                    final allReports = snapshot.data?.docs ?? [];

                    final filteredReports = _selectedFilter == 'All'
                        ? allReports
                        : allReports.where((doc) {
                            final status = doc['status'] as String? ?? 'pending';
                            return status.toLowerCase() ==
                                _selectedFilter.toLowerCase();
                          }).toList();

                    if (filteredReports.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_rounded,
                              size: 56,
                              color: AppColors.inkSubtle,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'No reports found',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'All reports under this filter are cleared',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppColors.inkMuted,
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
                        final message = data['message'] as String? ??
                            data['description'] as String? ??
                            'No description provided';
                        final status = data['status'] as String? ?? 'pending';
                        final createdAt = data['createdAt'] as Timestamp?;

                        return _ReportCard(
                          reportId: reportId,
                          stallName: stallName,
                          message: message,
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
      color: isSelected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: 1.0,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? Colors.white : AppColors.ink,
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
  final String message;
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
    required this.message,
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with stall name and status badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDim,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        stallName,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusBorderColor),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusTextColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Report message
          Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.ink,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),

          // Date and action buttons row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Timestamp
              Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 12,
                    color: AppColors.inkMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    formatDate(createdAt),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
              // Action buttons
              Row(
                children: [
                  // Mark as Reviewed button (only show if pending)
                  if (status.toLowerCase() == 'pending') ...[
                    _ActionButton(
                      label: 'Review',
                      textColor: AppColors.primary,
                      bgColor: AppColors.surfaceDim,
                      borderColor: AppColors.border,
                      onTap: () => onUpdateStatus(reportId, 'reviewed'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Mark as Resolved button (show if not resolved)
                  if (status.toLowerCase() != 'resolved') ...[
                    _ActionButton(
                      label: 'Resolve',
                      textColor: AppColors.primary,
                      bgColor: AppColors.primaryLight,
                      borderColor: AppColors.primary.withValues(alpha: 0.3),
                      onTap: () => onUpdateStatus(reportId, 'resolved'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Delete button
                  _ActionButton(
                    label: 'Delete',
                    textColor: AppColors.error,
                    bgColor: AppColors.errorLight,
                    borderColor: AppColors.errorBorder,
                    onTap: () => onDelete(reportId),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color bgColor;
  final Color borderColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.textColor,
    required this.bgColor,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}


