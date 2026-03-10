import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
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
  final _nameController = TextEditingController();
  final _productsController = TextEditingController();
  final _addressController = TextEditingController();
  final _openTimeController = TextEditingController();
  final _closeTimeController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  String _selectedCategory = 'fresh';
  bool _isActive = true;
  List<String> _selectedDays = [];
  List<File> _selectedImages = [];
  List<String> _existingPhotoUrls = [];
  bool _isLoading = false;
  bool _isUploading = false;
  int _uploadProgress = 0;
  int _uploadTotal = 0;

  final List<String> _categories = [
    'fresh',
    'frozen',
    'dry',
    'cooked',
    'sari-sari',
    'retail',
    'general',
    'services',
  ];

  final List<String> _daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.stallId != null) {
      _loadStallData();
    }
    _selectedDays = List.from(_daysOfWeek); // Default: all days
  }

  @override
  void dispose() {
    _nameController.dispose();
    _productsController.dispose();
    _addressController.dispose();
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
        _productsController.text = stall.products.join(', ');
        _addressController.text = stall.address;
        _openTimeController.text = stall.openTime;
        _closeTimeController.text = stall.closeTime;
        _latitudeController.text = stall.latitude.toString();
        _longitudeController.text = stall.longitude.toString();
        _selectedCategory = stall.category;
        _isActive = stall.isActive;
        _selectedDays = List.from(stall.daysOpen);
        _existingPhotoUrls = List.from(stall.photoUrls);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading stall: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImages() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();

      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images.map((xfile) => File(xfile.path)));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking images: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<File?> _compressImage(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 1024,
        minHeight: 1024,
        quality: 85,
      );
      
      final tempPath = file.path.replaceAll('.jpg', '_compressed.jpg');
      final compressedFile = File(tempPath);
      await compressedFile.writeAsBytes(result);
      return compressedFile;
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return file; // Return original if compression fails
    }
  }

  Future<void> _selectTime(TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null && mounted) {
      final formattedTime = picked.format(context);
      controller.text = formattedTime;
    }
  }

  Future<void> _saveStall() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _isUploading = true;
      _uploadProgress = 0;
      _uploadTotal = _selectedImages.length;
    });

    try {
      // Compress and upload new images
      List<String> uploadedUrls = List.from(_existingPhotoUrls);
      
      for (int i = 0; i < _selectedImages.length; i++) {
        setState(() => _uploadProgress = i);
        
        final compressed = await _compressImage(_selectedImages[i]);
        if (compressed != null) {
          final url = await CloudinaryService.uploadStallImage(compressed);
          if (url != null) {
            uploadedUrls.add(url);
          }
        }
      }

      setState(() => _uploadProgress = _selectedImages.length);

      // Prepare stall data
      final products = _productsController.text
          .split(',')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();

      final stallData = {
        'name': _nameController.text.trim(),
        'category': _selectedCategory,
        'products': products,
        'address': _addressController.text.trim(),
        'photoUrls': uploadedUrls,
        'openTime': _openTimeController.text,
        'closeTime': _closeTimeController.text,
        'daysOpen': _selectedDays,
        'latitude': double.tryParse(_latitudeController.text) ?? 0.0,
        'longitude': double.tryParse(_longitudeController.text) ?? 0.0,
        'isActive': _isActive,
        'updatedAt': Timestamp.now(),
        'tags': [],
      };

      // Save to Firestore
      if (widget.stallId != null) {
        await FirebaseFirestore.instance
            .collection('stalls')
            .doc(widget.stallId)
            .update(stallData);
      } else {
        final docRef = FirebaseFirestore.instance.collection('stalls').doc();
        await docRef.set(stallData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.stallId != null
                  ? 'Stall updated successfully'
                  : 'Stall created successfully',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving stall: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          widget.stallId == null ? 'Add Stall' : 'Edit Stall',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: _isLoading && widget.stallId != null
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B5E20)))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Name
                  _buildTextField(
                    controller: _nameController,
                    label: 'Stall Name',
                    icon: Icons.store,
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Category
                  _buildDropdown(),
                  const SizedBox(height: 16),

                  // Products
                  _buildTextField(
                    controller: _productsController,
                    label: 'Products (comma-separated)',
                    icon: Icons.shopping_basket,
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Address
                  _buildTextField(
                    controller: _addressController,
                    label: 'Address',
                    icon: Icons.location_on,
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),

                  // Photos
                  _buildPhotoSection(),
                  const SizedBox(height: 16),

                  // Time Range
                  Row(
                    children: [
                      Expanded(
                        child: _buildTimeField(
                          controller: _openTimeController,
                          label: 'Open Time',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTimeField(
                          controller: _closeTimeController,
                          label: 'Close Time',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Days Open
                  _buildDaysSelector(),
                  const SizedBox(height: 16),

                  // Coordinates
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _latitudeController,
                          label: 'Latitude',
                          icon: Icons.pin_drop,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) {
                            if (v?.isEmpty ?? true) return 'Required';
                            if (double.tryParse(v!) == null) return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _longitudeController,
                          label: 'Longitude',
                          icon: Icons.pin_drop,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) {
                            if (v?.isEmpty ?? true) return 'Required';
                            if (double.tryParse(v!) == null) return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Is Active
                  SwitchListTile(
                    value: _isActive,
                    onChanged: (value) => setState(() => _isActive = value),
                    title: Text('Active', style: GoogleFonts.poppins()),
                    subtitle: Text(
                      _isActive ? 'Stall is visible to users' : 'Stall is hidden',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                    activeColor: const Color(0xFF1B5E20),
                  ),
                  const SizedBox(height: 24),

                  // Upload Progress
                  if (_isUploading) _buildUploadProgress(),

                  // Save Button
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveStall,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              widget.stallId == null ? 'Create Stall' : 'Update Stall',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(),
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
    );
  }

  Widget _buildDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      decoration: InputDecoration(
        labelText: 'Category',
        labelStyle: GoogleFonts.poppins(),
        prefixIcon: const Icon(Icons.category),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      items: _categories.map((cat) {
        return DropdownMenuItem(value: cat, child: Text(cat));
      }).toList(),
      onChanged: (value) {
        if (value != null) setState(() => _selectedCategory = value);
      },
    );
  }

  Widget _buildTimeField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(),
        prefixIcon: const Icon(Icons.access_time),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      onTap: () => _selectTime(controller),
      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
    );
  }

  Widget _buildPhotoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Photos', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (_existingPhotoUrls.isNotEmpty || _selectedImages.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._existingPhotoUrls.map((url) => _buildPhotoThumbnail(url: url)),
                ..._selectedImages.map((file) => _buildPhotoThumbnail(file: file)),
              ],
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickImages,
            icon: const Icon(Icons.add_photo_alternate),
            label: Text('Add Photos', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoThumbnail({String? url, File? file}) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 80,
            height: 80,
            color: Colors.grey[200],
            child: file != null
                ? Image.file(file, fit: BoxFit.cover)
                : Image.network(url!, fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: () {
              setState(() {
                if (file != null) {
                  _selectedImages.remove(file);
                } else {
                  _existingPhotoUrls.remove(url);
                }
              });
            },
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDaysSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Days Open', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _daysOfWeek.map((day) {
              final isSelected = _selectedDays.contains(day);
              return FilterChip(
                label: Text(day.substring(0, 3)),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedDays.add(day);
                    } else {
                      _selectedDays.remove(day);
                    }
                  });
                },
                selectedColor: Colors.green[100],
                checkmarkColor: Colors.green,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadProgress() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            'Uploading photos to Cloudinary...',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _uploadTotal > 0 ? _uploadProgress / _uploadTotal : 0,
            backgroundColor: Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1B5E20)),
          ),
          const SizedBox(height: 4),
          Text(
            '$_uploadProgress / $_uploadTotal',
            style: GoogleFonts.poppins(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
