import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

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
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  Future<void> _deleteReport(String reportId) async {
    // Show confirmation dialog first
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Delete Report?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'This report will be permanently deleted. This cannot be undone.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: const Color(0xFF666666)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(color: Colors.white),
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
        backgroundColor: const Color(0xFFE53935),
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
        return const Color(0xFFFFF3E0);
      case 'reviewed':
        return const Color(0xFFE3F2FD);
      case 'resolved':
        return const Color(0xFFE8F5E9);
      default:
        return const Color(0xFFF5F5F5);
    }
  }

  Color _getStatusBorderColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFE65100);
      case 'reviewed':
        return const Color(0xFF1565C0);
      case 'resolved':
        return const Color(0xFF2E7D32);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        elevation: 0,
        toolbarHeight: 60,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Reports',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter chips row
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                        color: const Color(0xFFE53935),
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

                // Filter reports based on selected filter
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
                        const Icon(
                          Icons.inbox_rounded,
                          size: 64,
                          color: Color(0xFFE0E0E0),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No reports found',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF9E9E9E),
                          ),
                        ),
                        Text(
                          'All clear!',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: const Color(0xFF9E9E9E),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  itemCount: filteredReports.length,
                  itemBuilder: (context, index) {
                    final report = filteredReports[index];
                    final reportId = report.id;
                    final data = report.data() as Map<String, dynamic>;

                    final stallName = data['stallName'] as String? ?? 'Unknown Stall';
                    final message = data['message'] as String? ??
                        data['description'] as String? ??
                        'No description';
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
                      getStatusBorderColor: _getStatusBorderColor,
                    );
                  },
                );
              },
            ),
          ),
        ],
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1B5E20) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1B5E20)
                : const Color(0xFFE0E0E0),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF212121),
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
    required this.getStatusBorderColor,
  });

  @override
  Widget build(BuildContext context) {
    final statusBgColor = getStatusBgColor(status);
    final statusBorderColor = getStatusBorderColor(status);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with title and status badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Report',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF212121),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusBorderColor),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: statusBorderColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Stall name
          Row(
            children: [
              const Icon(
                Icons.store_rounded,
                size: 14,
                color: Color(0xFF666666),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  stallName,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF666666),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Report message/description
          Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF212121),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // Date and action buttons row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Timestamp
              Text(
                formatDate(createdAt),
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: const Color(0xFF9E9E9E),
                ),
              ),
              // Action buttons
              Row(
                children: [
                  // Mark as Reviewed button (only show if pending)
                  if (status.toLowerCase() == 'pending') ...[
                    _ActionButton(
                      label: 'Review',
                      color: const Color(0xFF1565C0),
                      onTap: () => onUpdateStatus(reportId, 'reviewed'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Mark as Resolved button (show if not resolved)
                  if (status.toLowerCase() != 'resolved') ...[
                    _ActionButton(
                      label: 'Resolve',
                      color: const Color(0xFF2E7D32),
                      onTap: () => onUpdateStatus(reportId, 'resolved'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Delete button
                  _ActionButton(
                    label: 'Delete',
                    color: const Color(0xFFE53935),
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
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}

