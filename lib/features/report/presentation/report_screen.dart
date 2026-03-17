// Part 7: Redesigned Report Screen - Clean, Modern, Minimal Green Theme
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

class _ReportScreenState extends ConsumerState<ReportScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _showSuccess = false;
  List<String> _selectedCategories = [];
  bool _attemptedSubmit = false;

  final List<String> _categories = [
    'Wrong Operating Hours',
    'Wrong Location on Map',
    'Wrong Stall Information',
    'Stall Permanently Closed',
    'Unsanitary Conditions',
    'Overpricing',
    'Rude Vendor',
    'Others',
  ];

  @override
  void initState() {
    super.initState();
    // Set status bar to light
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  bool _isFormValid() {
    return _selectedCategories.isNotEmpty &&
      _descriptionController.text.trim().length >= 10;
  }

  void _toggleCategory(String category) {
    setState(() {
      if (category == 'Others') {
        // If "Others" is selected, clear all other selections and only select "Others"
        if (_selectedCategories.contains('Others')) {
          _selectedCategories.remove('Others');
        } else {
          _selectedCategories.clear();
          _selectedCategories.add('Others');
        }
      } else {
        // If selecting a non-"Others" category
        // First, remove "Others" if it was selected
        _selectedCategories.remove('Others');
        
        // Then toggle the selected category
        if (_selectedCategories.contains(category)) {
          _selectedCategories.remove(category);
        } else {
          // Only add if less than 3 categories selected
          if (_selectedCategories.length < 3) {
            _selectedCategories.add(category);
          }
        }
      }
    });
  }

  Color _getCharCountColor(int length) {
    if (length > 480) return const Color(0xFFE53935);
    if (length > 400) return const Color(0xFFFF8F00);
    return const Color(0xFF9E9E9E);
  }

  Future<void> _submitReport() async {
    setState(() {
      _attemptedSubmit = true;
    });

    if (!_isFormValid()) return;

    final user = ref.read(authStateProvider).value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please log in to submit a report',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
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
            backgroundColor: Colors.red,
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

    final descriptionLength = _descriptionController.text.length;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Report Stall',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFA5D6A7),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: Color(0xFF2E7D32),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'We appreciate your help in keeping our marketplace information accurate and reliable.',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Reporting for section
              Text(
                'Reporting for:',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF9E9E9E),
                ),
              ),

              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFF0F0F0),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.storefront_rounded,
                      size: 18,
                      color: Color(0xFF2E7D32),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.stallName,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF212121),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Type of Issue section
              Text(
                'Type of Issue * (Select 1-3)',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF424242),
                ),
              ),

              const SizedBox(height: 10),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((category) {
                  final isSelected = _selectedCategories.contains(category);
                  final isDisabled = !isSelected && 
                      _selectedCategories.length >= 3 && 
                      category != 'Others';
                  
                  return Opacity(
                    opacity: isDisabled ? 0.5 : 1.0,
                    child: InkWell(
                      onTap: isDisabled ? null : () => _toggleCategory(category),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF1B5E20)
                                : const Color(0xFFE0E0E0),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 14,
                              child: isSelected
                                  ? const Icon(
                                      Icons.check_circle_rounded,
                                      size: 14,
                                      color: Color(0xFF1B5E20),
                                    )
                                  : null,
                            ),
                            SizedBox(width: isSelected ? 6 : 0),
                            Text(
                              category,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                                color: isSelected
                                    ? const Color(0xFF1B5E20)
                                    : const Color(0xFF757575),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              // Validation error for category
              if (_attemptedSubmit && _selectedCategories.isEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Please select at least one type of issue',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFFE53935),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Description text field
              Text(
                'Describe the issue *',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF424242),
                ),
              ),

              const SizedBox(height: 8),

              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE0E0E0),
                    width: 1.5,
                  ),
                ),
                child: TextField(
                  controller: _descriptionController,
                  minLines: 5,
                  maxLines: 8,
                  maxLength: 500,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFF212121),
                  ),
                  cursorColor: const Color(0xFF1B5E20),
                  decoration: InputDecoration(
                    hintText: 'Please describe the issue in detail...',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFFBDBDBD),
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF1B5E20),
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.all(14),
                    counterText: '',
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
              ),

              const SizedBox(height: 6),

              // Custom character counter
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '$descriptionLength/500',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: _getCharCountColor(descriptionLength),
                  ),
                ),
              ),

              // Validation error for description
              if (_attemptedSubmit &&
                  _descriptionController.text.trim().length < 10) ...[
                const SizedBox(height: 8),
                Text(
                  'Please describe the issue (min. 10 characters)',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFFE53935),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: _isFormValid()
                    ? Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF2E7D32),
                              Color(0xFF1B5E20),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x401B5E20),
                              blurRadius: 12,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitReport,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
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
                                    const Icon(
                                      Icons.send_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Submit Report',
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      )
                    : ElevatedButton(
                        onPressed: null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE0E0E0),
                          disabledBackgroundColor: const Color(0xFFE0E0E0),
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Submit Report',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF9E9E9E),
                          ),
                        ),
                      ),
              ),

              const SizedBox(height: 16),

              // Disclaimer
              Center(
                child: Text(
                  'Note: False reports may result in account suspension.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF9E9E9E),
                  ),
                ),
              ),
            ],
          ),
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
          scale: 0.8 + (0.2 * value),
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
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Success icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F5E9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 52,
                    color: Color(0xFF2E7D32),
                  ),
                ),

                const SizedBox(height: 24),

                // Title
                Text(
                  'Report Submitted!',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1B5E20),
                  ),
                ),

                const SizedBox(height: 12),

                // Subtitle
                Text(
                  'Thank you for helping us improve Merkado Go. Our team will review your report.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFF757575),
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 32),

                // Done button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF2E7D32),
                          Color(0xFF1B5E20),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x401B5E20),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
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
