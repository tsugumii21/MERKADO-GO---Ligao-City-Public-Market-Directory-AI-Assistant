import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../providers/auth_provider.dart';

class ReportScreen extends ConsumerStatefulWidget {
  final String stallId;
  final String stallName;

  const ReportScreen({
    super.key,
    required this.stallId,
    required this.stallName,
  });

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportIssueType {
  final String id;
  final String title;
  final IconData icon;

  const _ReportIssueType({
    required this.id,
    required this.title,
    required this.icon,
  });
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final FocusNode _descriptionFocusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();

  bool _isSubmitting = false;
  bool _showSuccess = false;
  final List<String> _selectedCategories = [];
  bool _attemptedSubmit = false;

  static const List<_ReportIssueType> _issueTypes = [
    _ReportIssueType(
      id: 'Wrong Operating Hours',
      title: 'Wrong Operating Hours',
      icon: Icons.access_time_rounded,
    ),
    _ReportIssueType(
      id: 'Wrong Location on Map',
      title: 'Wrong Map Location',
      icon: Icons.location_on_rounded,
    ),
    _ReportIssueType(
      id: 'Wrong Stall Information',
      title: 'Incorrect Information',
      icon: Icons.edit_note_rounded,
    ),
    _ReportIssueType(
      id: 'Stall Permanently Closed',
      title: 'Permanently Closed',
      icon: Icons.door_back_door_outlined,
    ),
    _ReportIssueType(
      id: 'Unsanitary Conditions',
      title: 'Sanitation Concerns',
      icon: Icons.cleaning_services_rounded,
    ),
    _ReportIssueType(
      id: 'Overpricing',
      title: 'Overpricing / Price Dispute',
      icon: Icons.sell_outlined,
    ),
    _ReportIssueType(
      id: 'Rude Vendor',
      title: 'Vendor Misconduct',
      icon: Icons.sentiment_dissatisfied_rounded,
    ),
    _ReportIssueType(
      id: 'Others',
      title: 'Other Inquiries / Issues',
      icon: Icons.more_horiz_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    return _selectedCategories.isNotEmpty &&
        _descriptionController.text.trim().length >= 10;
  }

  void _toggleCategory(String category) {
    setState(() {
      if (category == 'Others') {
        if (_selectedCategories.contains('Others')) {
          _selectedCategories.remove('Others');
        } else {
          _selectedCategories.clear();
          _selectedCategories.add('Others');
        }
      } else {
        _selectedCategories.remove('Others');
        if (_selectedCategories.contains(category)) {
          _selectedCategories.remove(category);
        } else {
          if (_selectedCategories.length < 3) {
            _selectedCategories.add(category);
          } else {
            HapticFeedback.heavyImpact();
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'You can select up to 3 issue types',
                  style: GoogleFonts.poppins(fontSize: 12.5),
                ),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        }
      }
    });
  }

  Color _getCharCountColor(int length) {
    if (length >= 480) return const Color(0xFFDC2626);
    if (length >= 400) return const Color(0xFFD97706);
    return const Color(0xFF9CA3AF);
  }

  Future<void> _submitReport() async {
    setState(() {
      _attemptedSubmit = true;
    });

    if (!_isFormValid) {
      HapticFeedback.mediumImpact();
      return;
    }

    final user = ref.read(authStateProvider).value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please log in to submit a report',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'userId': user.uid,
        'userEmail': user.email ?? 'Anonymous User',
        'stallId': widget.stallId,
        'stallName': widget.stallName,
        'categories': _selectedCategories,
        'description': _descriptionController.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _showSuccess = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error submitting report: ${e.toString()}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showSuccess) {
      return _buildSuccessScreen();
    }

    final descLength = _descriptionController.text.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black12,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Material(
            color: const Color(0xFFF3F4F6),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).pop(),
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
          children: [
            Text(
              'Report an Issue',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
                letterSpacing: -0.2,
              ),
            ),
            Text(
              'Ligao Public Market Community Feedback',
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
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Sleek Notice Banner
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFF0FDF4),
                              Color(0xFFDCFCE7),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF86EFAC),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Color(0xFF16A34A),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.shield_outlined,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Help Maintain Market Quality',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF14532D),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Your reports are confidential and help market administrators verify stall operating hours, prices, and accurate locations.',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11.5,
                                      height: 1.45,
                                      color: const Color(0xFF166534),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 2. Reporting For Card
                      Text(
                        'REPORTING FOR STALL',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFE5E7EB),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
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
                                color: const Color(0xFF1B5E20)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.storefront_rounded,
                                color: Color(0xFF1B5E20),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.stallName,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1F2937),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF3F4F6),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'ID: ${widget.stallId}',
                                          style: GoogleFonts.robotoMono(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF4B5563),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Ligao Public Market',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: const Color(0xFF9CA3AF),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 3. Issue Types (Multi-select Grid)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'SELECT TYPE OF ISSUE',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: _selectedCategories.isNotEmpty
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _selectedCategories.isEmpty
                                  ? 'Select 1-3'
                                  : '${_selectedCategories.length}/3 selected',
                              style: GoogleFonts.poppins(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: _selectedCategories.isNotEmpty
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Issue Chips Wrap Grid
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _issueTypes.map((issue) {
                          final isSelected =
                              _selectedCategories.contains(issue.id);
                          final isDisabled = !isSelected &&
                              _selectedCategories.length >= 3 &&
                              issue.id != 'Others';

                          return Opacity(
                            opacity: isDisabled ? 0.45 : 1.0,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: isDisabled
                                    ? null
                                    : () {
                                        HapticFeedback.selectionClick();
                                        _toggleCategory(issue.id);
                                      },
                                borderRadius: BorderRadius.circular(12),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF1B5E20)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF1B5E20)
                                          : const Color(0xFFE5E7EB),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF1B5E20)
                                                  .withValues(alpha: 0.2),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isSelected
                                            ? Icons.check_circle_rounded
                                            : issue.icon,
                                        size: 15,
                                        color: isSelected
                                            ? Colors.white
                                            : const Color(0xFF6B7280),
                                      ),
                                      const SizedBox(width: 7),
                                      Text(
                                        issue.title,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? Colors.white
                                              : const Color(0xFF374151),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      if (_attemptedSubmit && _selectedCategories.isEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 14,
                              color: Color(0xFFDC2626),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Please select at least one issue category',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 24),

                      // 4. Description Field
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'DESCRIBE THE ISSUE',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                          Text(
                            '$descLength/500',
                            style: GoogleFonts.robotoMono(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _getCharCountColor(descLength),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _descriptionFocusNode.hasFocus
                                ? const Color(0xFF1B5E20)
                                : (_attemptedSubmit &&
                                        _descriptionController.text
                                                .trim()
                                                .length <
                                            10
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFFE5E7EB)),
                            width: _descriptionFocusNode.hasFocus ? 1.8 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _descriptionController,
                          focusNode: _descriptionFocusNode,
                          minLines: 4,
                          maxLines: 7,
                          maxLength: 500,
                          style: GoogleFonts.poppins(
                            fontSize: 13.5,
                            color: const Color(0xFF1F2937),
                            height: 1.5,
                          ),
                          cursorColor: const Color(0xFF1B5E20),
                          decoration: InputDecoration(
                            hintText:
                                'Please provide specific details (e.g. stall relocated to Extension II, wrong closing time, incorrect products listed)...',
                            hintStyle: GoogleFonts.poppins(
                              fontSize: 12.5,
                              color: const Color(0xFF9CA3AF),
                              height: 1.5,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(16),
                            counterText: '',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),

                      if (_attemptedSubmit &&
                          _descriptionController.text.trim().length < 10) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 14,
                              color: Color(0xFFDC2626),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Please describe the issue in at least 10 characters',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),

            // 5. Sticky Bottom Action Bar
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: _isFormValid
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFF2E7D32),
                                  Color(0xFF1B5E20),
                                ],
                              )
                            : null,
                        color: _isFormValid ? null : const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: _isFormValid
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF1B5E20)
                                      .withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [],
                      ),
                      child: ElevatedButton(
                        onPressed: (_isSubmitting || !_isFormValid)
                            ? null
                            : _submitReport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.send_rounded,
                                    size: 17,
                                    color: _isFormValid
                                        ? Colors.white
                                        : const Color(0xFF9CA3AF),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Submit Report',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                      color: _isFormValid
                                          ? Colors.white
                                          : const Color(0xFF9CA3AF),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.lock_outline_rounded,
                        size: 13,
                        color: Color(0xFF9CA3AF),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Your report is securely reviewed by Ligao Market administrators',
                        style: GoogleFonts.poppins(
                          fontSize: 10.5,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessScreen() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        final safeOpacity = value.clamp(0.0, 1.0).toDouble();
        return Transform.scale(
          scale: 0.85 + (0.15 * value),
          child: Opacity(
            opacity: safeOpacity,
            child: child,
          ),
        );
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Success Badge
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 48,
                    color: Color(0xFF16A34A),
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'Report Submitted!',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                    letterSpacing: -0.3,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  'Thank you for contributing to a better marketplace. Ligao City Market administrators will verify your report for ${widget.stallName}.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    color: const Color(0xFF6B7280),
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF2E7D32),
                          Color(0xFF1B5E20),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1B5E20).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Done',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
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
    );
  }
}
