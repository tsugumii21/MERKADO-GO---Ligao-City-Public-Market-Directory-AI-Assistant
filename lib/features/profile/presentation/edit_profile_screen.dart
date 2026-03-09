// Part 10: Edit Profile Screen with Cloudinary photo upload and email verification
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/exceptions/auth_exception.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _newEmailController = TextEditingController();
  final _imagePicker = ImagePicker();

  File? _selectedImage;
  bool _isSaving = false;
  bool _isInitialized = false;
  String _currentEmail = '';

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _newEmailController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to pick image. Please try again.',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFE53935),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      // Upload new photo to Cloudinary if selected
      String? newPhotoUrl;
      if (_selectedImage != null) {
        newPhotoUrl = await CloudinaryService.uploadProfileImage(
          _selectedImage!,
          user.uid,
        );

        if (newPhotoUrl == null) {
          throw Exception('Failed to upload image');
        }
      }

      // Prepare Firestore update data
      final Map<String, dynamic> updateData = {
        'username': _usernameController.text.trim(),
        'fullName': _fullNameController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add photo URL if uploaded
      if (newPhotoUrl != null) {
        updateData['profilePhotoUrl'] = newPhotoUrl;
      }

      // Remove null values
      updateData.removeWhere((key, value) => value == null);

      // STEP 1: Save non-email fields to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(updateData);

      // STEP 2: Handle email change separately
      final newEmail = _newEmailController.text.trim();
      if (newEmail.isNotEmpty && newEmail != _currentEmail) {
        // Send verification to NEW email
        await user.verifyBeforeUpdateEmail(newEmail);

        // Show info dialog
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Verify New Email',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1B5E20),
                ),
              ),
              content: Text(
                'A verification link has been sent to $newEmail\n\n'
                'Please check your inbox and click the link to confirm your new email address.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: const Color(0xFF424242),
                  height: 1.5,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.pop();
                  },
                  child: Text(
                    'OK',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF1B5E20),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      } else {
        // STEP 3: Show success snackbar for other fields
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Profile updated successfully!',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              backgroundColor: const Color(0xFF1B5E20),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
          context.pop(); // go back to profile
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString()}',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFE53935),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userDataAsync = ref.watch(userDataStreamProvider);

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
          'Edit Profile',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
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

          // Initialize controllers with current data (only once)
          if (!_isInitialized) {
            _usernameController.text = userData.username;
            _fullNameController.text = userData.fullName;
            _currentEmail = userData.email;
            _isInitialized = true;
          }

          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 32),

                // PART 2: AVATAR SECTION
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 52,
                        backgroundColor: const Color(0xFFE8F5E9),
                        backgroundImage: _selectedImage != null
                            ? FileImage(_selectedImage!)
                            : (userData.profilePhotoUrl != null
                                ? CachedNetworkImageProvider(userData.profilePhotoUrl!) as ImageProvider
                                : null),
                        child: (_selectedImage == null && userData.profilePhotoUrl == null)
                            ? const Icon(
                                Icons.person_rounded,
                                size: 52,
                                color: Color(0xFF1B5E20),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B5E20),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                Center(
                  child: Text(
                    'Tap to change photo',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF9E9E9E),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // PART 3: EDITABLE FIELDS SECTION
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'PERSONAL INFORMATION',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF9E9E9E),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Container(
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
                      _buildEditableRow(
                        'Username',
                        Icons.alternate_email_rounded,
                        _usernameController,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 68),
                        child: const Divider(
                          height: 1,
                          color: Color(0xFFF0F0F0),
                        ),
                      ),
                      _buildEditableRow(
                        'Full Name',
                        Icons.person_outline_rounded,
                        _fullNameController,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // PART 4: EMAIL CHANGE SECTION
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'EMAIL ADDRESS',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF9E9E9E),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Container(
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
                      _buildCurrentEmailRow(),
                      Padding(
                        padding: const EdgeInsets.only(left: 68),
                        child: const Divider(
                          height: 1,
                          color: Color(0xFFF0F0F0),
                        ),
                      ),
                      _buildEditableRow(
                        'New Email Address',
                        Icons.forward_to_inbox_rounded,
                        _newEmailController,
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Email verification info box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFDE7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFE082), width: 1),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFFF57F17),
                        size: 16,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'A verification link will be sent to your new email. '
                          'The change only takes effect after you confirm it.',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFF795548),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // PART 5: SAVE CHANGES BUTTON
                Container(
                  width: double.infinity,
                  height: 54,
                  constraints: const BoxConstraints(
                    minHeight: 54,
                    maxHeight: 54,
                  ),
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      disabledBackgroundColor: const Color(0xFF1B5E20).withOpacity(0.6),
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 54),
                      maximumSize: const Size(double.infinity, 54),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSaving
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Saving...',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            'Save Changes',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 48),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
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

  Widget _buildEditableRow(
    String fieldName,
    IconData icon,
    TextEditingController controller, {
    TextInputType? keyboardType,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F8E9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: const Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFF212121),
                fontWeight: FontWeight.w400,
              ),
              decoration: InputDecoration(
                labelText: fieldName,
                labelStyle: GoogleFonts.poppins(
                  fontSize: 11,
                  color: const Color(0xFF9E9E9E),
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: Color(0xFF1B5E20),
                    width: 1.5,
                  ),
                ),
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.only(bottom: 4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentEmailRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F8E9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.email_outlined,
              size: 18,
              color: Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Email',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF9E9E9E),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _currentEmail,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFF212121),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Active',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1B5E20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
