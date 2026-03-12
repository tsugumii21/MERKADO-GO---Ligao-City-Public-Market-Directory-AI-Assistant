import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/stall_model.dart';
import '../../../core/services/cloudinary_service.dart';

class AddEditStallScreen extends StatefulWidget {
  final String? stallId;

  const AddEditStallScreen({super.key, this.stallId});

  @override
  State<AddEditStallScreen> createState() => _AddEditStallScreenState();
}

class _AddEditStallScreenState extends State<AddEditStallScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _stallNumberController = TextEditingController();
  final _openTimeController = TextEditingController();
  final _closeTimeController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  // State variables
  final List<String> _selectedCategories = [];
  final List<String> _selectedTags = [];
  final List<String> _selectedDays = [];
  bool _isOpen = true;
  File? _selectedImage;
  String? _existingPhotoUrl;
  bool _isLoading = false;
  bool _isSaving = false;

  // Category options with emojis
  final List<Map<String, String>> _categories = [
    {'value': 'fresh', 'label': '🌿 Fresh'},
    {'value': 'seafood', 'label': '🐟 Seafood'},
    {'value': 'pork', 'label': '🥩 Pork'},
    {'value': 'beef', 'label': '🐄 Beef'},
    {'value': 'poultry', 'label': '🐔 Poultry'},
    {'value': 'vegetables', 'label': '🥦 Vegetables'},
    {'value': 'fruits', 'label': '🍎 Fruits'},
    {'value': 'frozen', 'label': '🧊 Frozen'},
    {'value': 'processed', 'label': '🏭 Processed'},
    {'value': 'spices', 'label': '🌶️ Spices'},
    {'value': 'rice_dealer', 'label': '🌾 Rice Dealer'},
    {'value': 'dried_fish', 'label': '🐠 Dried Fish'},
    {'value': 'carinderia', 'label': '🍳 Carinderia'},
    {'value': 'bakery', 'label': '🥖 Bakery'},
    {'value': 'kakanin', 'label': '🍡 Kakanin'},
    {'value': 'snack_stand', 'label': '🍢 Snack Stand'},
    {'value': 'sari_sari', 'label': '🏪 Sari-Sari Store'},
    {'value': 'ukay_ukay', 'label': '👗 Ukay-Ukay'},
    {'value': 'tailor_shop', 'label': '✂️ Tailor Shop'},
    {'value': 'hardware', 'label': '🔧 Hardware'},
    {'value': 'school_supplies', 'label': '📚 School Supplies'},
    {'value': 'home_supplies', 'label': '🏠 Home Supplies'},
    {'value': 'agrivet', 'label': '🌱 Agrivet'},
    {'value': 'electronics_repair', 'label': '📱 Electronics & Repair'},
    {'value': 'barber_salon', 'label': '💈 Barber/Salon'},
    {'value': 'general', 'label': '🛒 General Merchandise'},
  ];

  // Tag options
  final List<String> _availableTags = [
    'halal',
    'organic',
    'local',
    'wholesale',
    'budget_friendly',
    'premium',
    'fresh_daily',
    'made_to_order',
    'delivery_available',
    'open_early',
    'open_late',
    'takeout',
    'dine_in',
  ];

  final Map<String, String> _tagLabels = {
    'halal': 'Halal',
    'organic': 'Organic',
    'local': 'Local',
    'wholesale': 'Wholesale',
    'budget_friendly': 'Budget-Friendly',
    'premium': 'Premium',
    'fresh_daily': 'Fresh Daily',
    'made_to_order': 'Made to Order',
    'delivery_available': 'Delivery Available',
    'open_early': 'Opens Early',
    'open_late': 'Closes Late',
    'takeout': 'Takeout',
    'dine_in': 'Dine-in',
  };

  // Day options
  final List<Map<String, String>> _days = [
    {'value': 'Mon', 'label': 'Mon'},
    {'value': 'Tue', 'label': 'Tue'},
    {'value': 'Wed', 'label': 'Wed'},
    {'value': 'Thu', 'label': 'Thu'},
    {'value': 'Fri', 'label': 'Fri'},
    {'value': 'Sat', 'label': 'Sat'},
    {'value': 'Sun', 'label': 'Sun'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.stallId != null) {
      _loadStallData();
    } else {
      // Default values for new stall
      _openTimeController.text = '6:00 AM';
      _closeTimeController.text = '6:00 PM';
      _selectedDays.addAll(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _stallNumberController.dispose();
    _openTimeController.dispose();
    _closeTimeController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _loadStallData() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('stalls')
          .doc(widget.stallId)
          .get();

      if (doc.exists && mounted) {
        final stall = StallModel.fromFirestore(doc);
        _nameController.text = stall.name;
        _descriptionController.text = stall.products.join(', ');
        _stallNumberController.text = stall.address;
        
        // Load categories (multi-select)
        _selectedCategories.clear();
        _selectedCategories.addAll(stall.categories);
        
        // Load tags
        _selectedTags.clear();
        _selectedTags.addAll(stall.tags);
        
        _openTimeController.text = stall.openTime;
        _closeTimeController.text = stall.closeTime;
        
        // Parse operating days
        _parseOperatingDays(stall.daysOpen);
        
        _isOpen = stall.isActive;
        _latitudeController.text = stall.latitude.toString();
        _longitudeController.text = stall.longitude.toString();
        
        // Load existing photo URL - filter out demo/placeholder URLs
        if (stall.photoUrls.isNotEmpty) {
          _existingPhotoUrl = stall.photoUrls.first;
          // Remove hardcoded demo URLs
          if (_existingPhotoUrl != null &&
              (_existingPhotoUrl!.isEmpty ||
               _existingPhotoUrl!.contains('demo') ||
               _existingPhotoUrl!.contains('samples/food'))) {
            _existingPhotoUrl = null;
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error loading stall data: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _parseOperatingDays(List<String> daysOpen) {
    _selectedDays.clear();
    
    // Check if it's a formatted string like "Mon-Sat" in the first element
    if (daysOpen.isNotEmpty) {
      final firstDay = daysOpen.first;
      if (firstDay.contains('-')) {
        // Parse ranges like "Mon-Sat", "Mon-Sun", "Mon-Fri"
        if (firstDay == 'Mon-Sun') {
          _selectedDays.addAll(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']);
        } else if (firstDay == 'Mon-Sat') {
          _selectedDays.addAll(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']);
        } else if (firstDay == 'Mon-Fri') {
          _selectedDays.addAll(['Mon', 'Tue', 'Wed', 'Thu', 'Fri']);
        }
      } else {
        // Individual days
        for (final day in daysOpen) {
          final abbrev = day.substring(0, 3);
          if (!_selectedDays.contains(abbrev)) {
            _selectedDays.add(abbrev);
          }
        }
      }
    }
  }

  String _getOperatingDaysString() {
    if (_selectedDays.isEmpty) return '';
    if (_selectedDays.length == 7) return 'Mon-Sun';
    if (_selectedDays.length == 6 && !_selectedDays.contains('Sun')) return 'Mon-Sat';
    if (_selectedDays.length == 5 && 
        !_selectedDays.contains('Sat') && 
        !_selectedDays.contains('Sun')) return 'Mon-Fri';
    return _selectedDays.join(', ');
  }

  List<String> _getDaysOpenArray() {
    final Map<String, String> dayMap = {
      'Mon': 'Monday',
      'Tue': 'Tuesday',
      'Wed': 'Wednesday',
      'Thu': 'Thursday',
      'Fri': 'Friday',
      'Sat': 'Saturday',
      'Sun': 'Sunday',
    };
    
    return _selectedDays.map((abbrev) => dayMap[abbrev] ?? abbrev).toList();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Widget _buildPhotoSection() {
    // Case 1: User just picked a new image
    if (_selectedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          _selectedImage!,
          width: double.infinity,
          height: 180,
          fit: BoxFit.cover,
        ),
      );
    }

    // Case 2: Existing photo from Firestore
    if (_existingPhotoUrl != null &&
        _existingPhotoUrl!.isNotEmpty &&
        _existingPhotoUrl!.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          _existingPhotoUrl!,
          width: double.infinity,
          height: 180,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildPhotoPlaceholder(),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  color: const Color(0xFF1B5E20),
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
        ),
      );
    }

    // Case 3: No photo - show placeholder
    return _buildPhotoPlaceholder();
  }

  Widget _buildPhotoPlaceholder() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFE0E0E0),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_photo_alternate_rounded,
              size: 48,
              color: Color(0xFF9E9E9E),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to add stall photo',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF9E9E9E),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'JPG, PNG up to 5MB',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: const Color(0xFFBDBDBD),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectTime(TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1B5E20),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final hour = picked.hourOfPeriod;
      final minute = picked.minute.toString().padLeft(2, '0');
      final period = picked.period == DayPeriod.am ? 'AM' : 'PM';
      controller.text = '${hour == 0 ? 12 : hour}:$minute $period';
    }
  }

  Future<void> _pickLocationOnMap() async {
    // Navigate to map picker screen (implement if available)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Map picker feature coming soon',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: const Color(0xFF666666),
      ),
    );
  }

  Future<void> _saveStall() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select at least one category',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: const Color(0xFFE53935),
        ),
      );
      return;
    }

    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select at least one operating day',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: const Color(0xFFE53935),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? photoUrl = _existingPhotoUrl;

      // Upload image if a new one was selected
      if (_selectedImage != null) {
        final uid = FirebaseAuth.instance.currentUser?.uid ?? 'stall_${DateTime.now().millisecondsSinceEpoch}';
        photoUrl = await CloudinaryService.uploadProfileImage(
          _selectedImage!,
          'stall_$uid',
        );
      }

      final stallData = {
        'name': _nameController.text.trim(),
        'category': _selectedCategories.first, // First category for backward compatibility
        'categories': _selectedCategories, // Multi-category array
        'products': _descriptionController.text.trim().split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList(),
        'address': _stallNumberController.text.trim(),
        'photoUrls': photoUrl != null ? [photoUrl] : [],
        'openTime': _openTimeController.text.trim(),
        'closeTime': _closeTimeController.text.trim(),
        'daysOpen': _getDaysOpenArray(),
        'latitude': double.tryParse(_latitudeController.text) ?? 13.4144,
        'longitude': double.tryParse(_longitudeController.text) ?? 123.5244,
        'isActive': _isOpen,
        'updatedAt': FieldValue.serverTimestamp(),
        'tags': _selectedTags,
      };

      if (widget.stallId != null) {
        // Update existing stall
        await FirebaseFirestore.instance
            .collection('stalls')
            .doc(widget.stallId)
            .update(stallData);
      } else {
        // Create new stall
        await FirebaseFirestore.instance
            .collection('stalls')
            .add(stallData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.stallId != null ? 'Stall updated successfully' : 'Stall created successfully',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error saving stall: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildStableChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1B5E20) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF1B5E20) : const Color(0xFFE0E0E0),
            width: 1.5,
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

  InputDecoration _buildInputDecoration({
    required String label,
    String? hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GoogleFonts.poppins(
        fontSize: 13,
        color: const Color(0xFF666666),
      ),
      hintStyle: GoogleFonts.poppins(
        fontSize: 13,
        color: const Color(0xFF9E9E9E),
      ),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1B5E20), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE53935)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE53935), width: 2),
      ),
      prefixIcon: Icon(icon, color: const Color(0xFF1B5E20), size: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
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
            widget.stallId != null ? 'Edit Stall' : 'Add Stall',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF1B5E20)),
        ),
      );
    }

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
          widget.stallId != null ? 'Edit Stall' : 'Add Stall',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Stall Name
              TextFormField(
                controller: _nameController,
                decoration: _buildInputDecoration(
                  label: 'Stall Name *',
                  hint: 'Enter stall name',
                  icon: Icons.store_rounded,
                ),
                style: GoogleFonts.poppins(fontSize: 14),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter stall name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // 2. Categories (Multi-select chips)
              Text(
                'Categories *',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF212121),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select all that apply',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: const Color(0xFF666666),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((cat) {
                    final isSelected = _selectedCategories.contains(cat['value']);
                    return _buildStableChip(
                      label: cat['label']!,
                      isSelected: isSelected,
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedCategories.remove(cat['value']);
                          } else {
                            _selectedCategories.add(cat['value']!);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              // 3. Tags (Multi-select chips)
              Text(
                'Tags (Optional)',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF212121),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableTags.map((tag) {
                    final isSelected = _selectedTags.contains(tag);
                    return _buildStableChip(
                      label: _tagLabels[tag] ?? tag,
                      isSelected: isSelected,
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedTags.remove(tag);
                          } else {
                            _selectedTags.add(tag);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              // 4. Description
              TextFormField(
                controller: _descriptionController,
                decoration: _buildInputDecoration(
                  label: 'Description',
                  hint: 'Enter products/services (comma-separated)',
                  icon: Icons.description_rounded,
                ),
                style: GoogleFonts.poppins(fontSize: 14),
                maxLines: 3,
              ),
              const SizedBox(height: 20),

              // 5. Stall Number
              TextFormField(
                controller: _stallNumberController,
                decoration: _buildInputDecoration(
                  label: 'Stall Number',
                  hint: 'e.g. Stall 12, Section A',
                  icon: Icons.tag_rounded,
                ),
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              const SizedBox(height: 20),

              // 6. Operating Hours
              Text(
                'Operating Hours',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF212121),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _openTimeController,
                      decoration: _buildInputDecoration(
                        label: 'Open Time',
                        icon: Icons.access_time_rounded,
                      ),
                      style: GoogleFonts.poppins(fontSize: 14),
                      readOnly: true,
                      onTap: () => _selectTime(_openTimeController),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _closeTimeController,
                      decoration: _buildInputDecoration(
                        label: 'Close Time',
                        icon: Icons.access_time_filled_rounded,
                      ),
                      style: GoogleFonts.poppins(fontSize: 14),
                      readOnly: true,
                      onTap: () => _selectTime(_closeTimeController),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 7. Operating Days
              Text(
                'Operating Days',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF212121),
                ),
              ),
              const SizedBox(height: 8),
              
              // Quick select buttons
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selectedDays.clear();
                        _selectedDays.addAll(['Mon', 'Tue', 'Wed', 'Thu', 'Fri']);
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF1B5E20)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Mon-Fri',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF1B5E20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selectedDays.clear();
                        _selectedDays.addAll(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']);
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF1B5E20)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Mon-Sat',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF1B5E20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selectedDays.clear();
                        _selectedDays.addAll(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']);
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF1B5E20)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Mon-Sun',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF1B5E20),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Day chips
              Row(
                children: _days.map((day) {
                  final isSelected = _selectedDays.contains(day['value']);
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedDays.remove(day['value']);
                          } else {
                            _selectedDays.add(day['value']!);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF1B5E20) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF1B5E20) : const Color(0xFFE0E0E0),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            day['label']!,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : const Color(0xFF666666),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // 8. Location
              Text(
                'Location (Optional)',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF212121),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latitudeController,
                      decoration: _buildInputDecoration(
                        label: 'Latitude',
                        icon: Icons.location_on_rounded,
                      ),
                      style: GoogleFonts.poppins(fontSize: 14),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _longitudeController,
                      decoration: _buildInputDecoration(
                        label: 'Longitude',
                        icon: Icons.location_on_outlined,
                      ),
                      style: GoogleFonts.poppins(fontSize: 14),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickLocationOnMap,
                icon: const Icon(Icons.map_rounded, size: 18),
                label: Text(
                  'Pick on Map',
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1B5E20),
                  side: const BorderSide(color: Color(0xFF1B5E20)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Photo upload
              Text(
                'Stall Photo',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF212121),
                ),
              ),
              const SizedBox(height: 8),
              _buildPhotoSection(),
              const SizedBox(height: 8),
              // Photo action buttons
              if (_selectedImage != null ||
                  (_existingPhotoUrl != null && _existingPhotoUrl!.isNotEmpty)) ...[  
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(
                          Icons.photo_library_rounded,
                          size: 16,
                          color: Color(0xFF1B5E20),
                        ),
                        label: Text(
                          'Change Photo',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFF1B5E20),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF1B5E20)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _pickImage,
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 16,
                        color: Color(0xFFE53935),
                      ),
                      label: Text(
                        'Remove',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Color(0xFFE53935),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE53935)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedImage = null;
                          _existingPhotoUrl = null;
                        });
                      },
                    ),
                  ],
                ),
              ] else ...[  
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(
                      Icons.photo_library_rounded,
                      size: 16,
                      color: Color(0xFF1B5E20),
                    ),
                    label: Text(
                      'Choose Photo',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF1B5E20),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF1B5E20)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _pickImage,
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // 9. Status Toggle
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Stall is Open',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF212121),
                      ),
                    ),
                    Switch(
                      value: _isOpen,
                      onChanged: (value) {
                        setState(() {
                          _isOpen = value;
                        });
                      },
                      activeColor: const Color(0xFF1B5E20),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 10. Save Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveStall,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    disabledBackgroundColor: const Color(0xFF1B5E20).withOpacity(0.6),
                    minimumSize: const Size(double.infinity, 56),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Save Stall',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
