import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../providers/user_provider.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/theme/app_colors.dart';

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

  Uint8List? _selectedImageBytes;
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
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to pick image. Please try again.',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
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
      if (_selectedImageBytes != null) {
        newPhotoUrl = await CloudinaryService.uploadProfileImageBytes(
          _selectedImageBytes!,
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
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border, width: 1.0),
              ),
              title: Text(
                'Verify New Email',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppColors.ink,
                ),
              ),
              content: Text(
                'A verification link has been sent to $newEmail\n\n'
                'Please check your inbox and click the link to confirm your new email address.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.inkMuted,
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
                      color: AppColors.primary,
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
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
              ),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
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
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => context.pop(),
        ),
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Edit Profile',
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
      ),
      body: userDataAsync.when(
        data: (userData) {
          if (userData == null) {
            return Center(
              child: Text(
                'No user data found',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.inkMuted,
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

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 24 : 16,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // PART 2: AVATAR SECTION
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: AppColors.primaryLight,
                            backgroundImage: _selectedImageBytes != null
                                ? MemoryImage(_selectedImageBytes!)
                                : (userData.profilePhotoUrl != null
                                    ? CachedNetworkImageProvider(userData.profilePhotoUrl!) as ImageProvider
                                    : null),
                            child: (_selectedImageBytes == null && userData.profilePhotoUrl == null)
                                ? const Icon(
                                    Icons.person_rounded,
                                    size: 48,
                                    color: AppColors.primary,
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: Center(
                                child: GestureDetector(
                                  onTap: _pickImage,
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppColors.surface, width: 2),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      color: Colors.white,
                                      size: 15,
                                    ),
                                  ),
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
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // PART 3: EDITABLE FIELDS SECTION
                    _buildSectionLabel('PERSONAL INFORMATION'),

                    const SizedBox(height: 10),

                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.border,
                          width: 1.0,
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildEditableRow(
                            'Username',
                            Icons.alternate_email_rounded,
                            _usernameController,
                          ),
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: AppColors.borderLight,
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
                    _buildSectionLabel('EMAIL ADDRESS'),

                    const SizedBox(height: 10),

                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.border,
                          width: 1.0,
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildCurrentEmailRow(),
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: AppColors.borderLight,
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
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.warningBorder, width: 1.0),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.warning,
                            size: 16,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'A verification link will be sent to your new email. '
                              'The change only takes effect after you confirm it.',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.ink,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // PART 5: SAVE CHANGES BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Save Changes',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, stack) => Center(
          child: Text(
            'Error loading profile',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.error,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.inkSubtle,
          letterSpacing: 1.2,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceDim,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              cursorColor: AppColors.primary,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.ink,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                labelText: fieldName,
                labelStyle: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.inkMuted,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: AppColors.primary,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceDim,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.email_outlined,
              size: 18,
              color: AppColors.primary,
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
                    color: AppColors.inkMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _currentEmail,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppColors.ink,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Active',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
