import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../models/stall_model.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/services/category_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/market_categories.dart';
import '../../../core/constants/market_sections.dart';

class AddEditStallScreen extends StatefulWidget {
  final String? stallId;

  const AddEditStallScreen({super.key, this.stallId});

  @override
  State<AddEditStallScreen> createState() => _AddEditStallScreenState();
}

class _AddEditStallScreenState extends State<AddEditStallScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  final _nameController = TextEditingController();
  final _productController = TextEditingController();
  final _stallNumberController = TextEditingController();
  final _openTimeController = TextEditingController(text: '5:00 AM');
  final _closeTimeController = TextEditingController(text: '6:00 PM');
  final _latitudeController = TextEditingController(text: '13.2419233');
  final _longitudeController = TextEditingController(text: '123.538546');
  final FocusNode _productFocusNode = FocusNode();

  // State Variables
  String? _selectedCategoryKey;
  final Set<String> _selectedSubcategories = {};
  final Map<String, List<String>> _categorySubcategoriesMap = {};
  bool _isLoadingSubcategories = false;
  List<String> _products = [];
  String? _selectedSection;
  final List<String> _selectedTags = [];
  final List<String> _selectedDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  String _stallStatus = 'open';
  Uint8List? _selectedImageBytes;
  String? _existingPhotoUrl;
  bool _isLoading = false;
  bool _isSaving = false;

  // Canonical Primary Category Name
  String get _finalPrimaryCategoryName {
    if (_selectedCategoryKey != null) {
      final cat = MarketCategories.findCategory(_selectedCategoryKey);
      if (cat != null) return cat.primaryCategoryName;
    }
    return '';
  }

  String get _finalCategoryValue => _finalPrimaryCategoryName;

  List<String> get _selectedCategories {
    final primary = _finalPrimaryCategoryName;
    if (primary.isEmpty) return [];
    return [primary, ..._selectedSubcategories];
  }

  static List<Map<String, dynamic>> get _categoryList =>
      MarketCategories.items.map((cat) {
        return {
          'key': cat.id,
          'label': cat.displayName,
          'icon': cat.icon,
          'color': cat.colorSet.fill,
          'hasSubcategories': cat.subcategories.isNotEmpty,
          'value': cat.primaryCategoryName,
          'subcategories': cat.subcategories,
        };
      }).toList();

  static const List<Map<String, dynamic>> _statusOptions = [
    {
      'value': 'open',
      'label': 'Open for Service',
      'description': 'Currently serving customers in the market',
      'icon': Icons.store_rounded,
      'color': Color(0xFF16A34A),
      'bgColor': Color(0xFFF0FDF4),
      'borderColor': Color(0xFF86EFAC),
    },
    {
      'value': 'closed',
      'label': 'Closed',
      'description': 'Not open today or past operating hours',
      'icon': Icons.storefront_outlined,
      'color': Color(0xFF64748B),
      'bgColor': Color(0xFFF8FAFC),
      'borderColor': Color(0xFFCBD5E1),
    },
    {
      'value': 'temporarily_closed',
      'label': 'Temporarily Closed',
      'description': 'Short-term closure, will reopen soon',
      'icon': Icons.pause_circle_outline_rounded,
      'color': Color(0xFFD97706),
      'bgColor': Color(0xFFFFFBEB),
      'borderColor': Color(0xFFFDE68A),
    },
    {
      'value': 'under_renovation',
      'label': 'Under Renovation',
      'description': 'Stall is currently undergoing maintenance',
      'icon': Icons.construction_rounded,
      'color': Color(0xFFEA580C),
      'bgColor': Color(0xFFFFF7ED),
      'borderColor': Color(0xFFFED7AA),
    },
    {
      'value': 'coming_soon',
      'label': 'Coming Soon',
      'description': 'New market stall opening soon',
      'icon': Icons.new_releases_outlined,
      'color': Color(0xFF2563EB),
      'bgColor': Color(0xFFEFF6FF),
      'borderColor': Color(0xFFBFDBFE),
    },
  ];

  final List<String> _availableTags = [
    'fresh_daily',
    'local',
    'wholesale',
    'budget_friendly',
    'organic',
    'halal',
    'made_to_order',
    'takeout',
    'dine_in',
    'delivery_available',
  ];

  final Map<String, String> _tagLabels = {
    'fresh_daily': 'Fresh Daily',
    'local': 'Local Goods',
    'wholesale': 'Wholesale',
    'budget_friendly': 'Budget-Friendly',
    'organic': 'Organic',
    'halal': 'Halal',
    'made_to_order': 'Made to Order',
    'takeout': 'Takeout Available',
    'dine_in': 'Dine-in Available',
    'delivery_available': 'Delivery Available',
  };

  final List<Map<String, String>> _days = [
    {'value': 'Mon', 'label': 'Mon'},
    {'value': 'Tue', 'label': 'Tue'},
    {'value': 'Wed', 'label': 'Wed'},
    {'value': 'Thu', 'label': 'Thu'},
    {'value': 'Fri', 'label': 'Fri'},
    {'value': 'Sat', 'label': 'Sat'},
    {'value': 'Sun', 'label': 'Sun'},
  ];

  List<String> get _productSuggestions {
    final catKey = _selectedCategoryKey?.toLowerCase() ?? '';
    if (catKey.contains('meat')) {
      return ['Pork Liempo', 'Pork Chops', 'Beef Shank (Bulalo)', 'Ground Pork', 'Beef Ribs', 'Carabao Meat'];
    } else if (catKey.contains('fish')) {
      return ['Bangus (Milkfish)', 'Tilapia', 'Galunggong', 'Pusit (Squid)', 'Hipon (Shrimp)', 'Tahong', 'Tulingan'];
    } else if (catKey.contains('produce')) {
      return ['Ampalaya', 'Sitaw', 'Kangkong', 'Pechay', 'Kamote', 'Talong', 'Kamatis', 'Sibuyas', 'Bawang'];
    } else if (catKey.contains('eateries')) {
      return ['Pork Adobo', 'Sinigang', 'Bicol Express', 'Pancit Guisado', 'Bulalo', 'Fried Chicken', 'Halo-Halo'];
    } else if (catKey.contains('rice')) {
      return ['Sinandomeng', 'Dinorado', 'Jasponica', 'Brown Rice', 'Glutinous Rice (Malagkit)', 'Well-Milled Rice'];
    } else if (catKey.contains('dry_goods')) {
      return ['Kitchenware', 'Plastic Containers', 'Brooms & Dustpans', 'Footwear', 'Bed Sheets', 'Curtains'];
    }
    return ['Pork Cuts', 'Fresh Fish', 'Vegetables', 'Rice Grains', 'Snacks', 'Seasonings'];
  }

  @override
  void initState() {
    super.initState();
    if (widget.stallId != null) {
      _loadStallData();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _productController.dispose();
    _stallNumberController.dispose();
    _openTimeController.dispose();
    _closeTimeController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _productFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSubcategoriesForCategory(String categoryKey) async {
    if (_categorySubcategoriesMap.containsKey(categoryKey)) {
      return;
    }
    setState(() => _isLoadingSubcategories = true);
    try {
      final list = await CategoryService.getSubcategories(categoryKey);
      if (mounted) {
        setState(() {
          _categorySubcategoriesMap[categoryKey] = list;
          _isLoadingSubcategories = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSubcategories = false);
    }
  }

  List<String> _getCurrentSubcategories(String categoryKey) {
    if (_categorySubcategoriesMap.containsKey(categoryKey)) {
      return _categorySubcategoriesMap[categoryKey]!;
    }
    final defaultCat = MarketCategories.findCategory(categoryKey);
    return defaultCat?.subcategories ?? [];
  }

  void _addProduct(String product) {
    final trimmed = product.trim();
    if (trimmed.isEmpty) return;

    final items = trimmed.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
    setState(() {
      for (final item in items) {
        if (!_products.contains(item)) {
          _products.add(item);
        }
      }
      _productController.clear();
    });
  }

  void _removeProduct(String product) {
    setState(() {
      _products.remove(product);
    });
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _existingPhotoUrl = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting image: $e', style: GoogleFonts.poppins()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
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
        final data = doc.data() as Map<String, dynamic>? ?? {};
        _nameController.text = stall.name;
        _products = List<String>.from(stall.products);
        _stallNumberController.text = stall.address;

        // Find matching primary category
        final matchedCat = MarketCategories.findCategory(stall.category) ??
            (stall.categories.isNotEmpty ? MarketCategories.findCategory(stall.categories.first) : null);

        _selectedCategoryKey = matchedCat?.id;
        _selectedSubcategories.clear();

        if (_selectedCategoryKey != null) {
          await _loadSubcategoriesForCategory(_selectedCategoryKey!);
        }

        // Extract subcategories
        final rawSubcategories = <String>{
          ...stall.tags,
          ...stall.categories,
          if (data['subcategories'] is List)
            ...(data['subcategories'] as List).map((e) => (e ?? '').toString().trim()),
        };

        if (_selectedCategoryKey != null) {
          final currentSubs = _getCurrentSubcategories(_selectedCategoryKey!);
          for (final sub in currentSubs) {
            if (rawSubcategories.any((r) => r.toLowerCase() == sub.toLowerCase())) {
              _selectedSubcategories.add(sub);
            }
          }
        }

        // Load custom tags
        _selectedTags.clear();
        for (final tag in stall.tags) {
          if (!_selectedSubcategories.any((s) => s.toLowerCase() == tag.toLowerCase())) {
            _selectedTags.add(tag);
          }
        }

        final matchedSec = MarketSections.findSection(stall.section);
        _selectedSection = matchedSec?.id ?? (stall.section?.isNotEmpty == true ? stall.section : null);

        _openTimeController.text = stall.openTime.isNotEmpty ? stall.openTime : '5:00 AM';
        _closeTimeController.text = stall.closeTime.isNotEmpty ? stall.closeTime : '6:00 PM';

        _parseOperatingDays(stall.daysOpen);

        _stallStatus = stall.status.isNotEmpty
            ? stall.status
            : (stall.isActive ? 'open' : 'closed');
        _latitudeController.text = stall.latitude.toString();
        _longitudeController.text = stall.longitude.toString();

        if (stall.photoUrls.isNotEmpty) {
          _existingPhotoUrl = stall.photoUrls.first;
          if (_existingPhotoUrl != null &&
              (_existingPhotoUrl!.isEmpty ||
                  _existingPhotoUrl!.contains('demo') ||
                  _existingPhotoUrl!.contains('placeholder'))) {
            _existingPhotoUrl = null;
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading stall data: $e', style: GoogleFonts.poppins()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _parseOperatingDays(List<String> daysOpen) {
    _selectedDays.clear();
    if (daysOpen.isNotEmpty) {
      final firstDay = daysOpen.first;
      if (firstDay.contains('-')) {
        if (firstDay == 'Mon-Sun') {
          _selectedDays.addAll(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']);
        } else if (firstDay == 'Mon-Sat') {
          _selectedDays.addAll(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']);
        } else if (firstDay == 'Mon-Fri') {
          _selectedDays.addAll(['Mon', 'Tue', 'Wed', 'Thu', 'Fri']);
        }
      } else {
        for (final day in daysOpen) {
          final trimmed = day.trim();
          final abbrev = trimmed.length >= 3 ? trimmed.substring(0, 3) : trimmed;
          if (abbrev.isNotEmpty && !_selectedDays.contains(abbrev)) {
            _selectedDays.add(abbrev);
          }
        }
      }
    }
    if (_selectedDays.isEmpty) {
      _selectedDays.addAll(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']);
    }
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
    return _selectedDays.map((d) => dayMap[d] ?? d).toList();
  }

  Future<void> _selectTime(TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: AppTheme.buildTimePickerTheme,
    );

    if (picked != null) {
      final hour = picked.hourOfPeriod;
      final minute = picked.minute.toString().padLeft(2, '0');
      final period = picked.period == DayPeriod.am ? 'AM' : 'PM';
      controller.text = '${hour == 0 ? 12 : hour}:$minute $period';
    }
  }

  // =========================================================================
  // SUB-CATEGORY CRUD OPERATIONS & MODALS (PERSISTED IN FIRESTORE)
  // =========================================================================

  Future<void> _showAddSubcategoryDialog() async {
    if (_selectedCategoryKey == null) return;
    final textController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) {
        bool isAdding = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B5E20).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF1B5E20), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Add Subcategory',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This will be saved to the database under $_finalPrimaryCategoryName and available for all stalls.',
                      style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: textController,
                      autofocus: true,
                      style: GoogleFonts.poppins(fontSize: 13.5),
                      decoration: _buildFieldDecoration(
                        hintText: 'e.g. Special Cuts, Organic Eggs',
                        prefixIcon: Icons.label_outline_rounded,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter subcategory name';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Cancel', style: GoogleFonts.poppins(color: const Color(0xFF64748B))),
                ),
                ElevatedButton(
                  onPressed: isAdding
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          final newName = textController.text.trim();
                          setDialogState(() => isAdding = true);
                          try {
                            final updatedList = await CategoryService.addSubcategory(
                              _selectedCategoryKey!,
                              newName,
                            );
                            if (mounted) {
                              setState(() {
                                _categorySubcategoriesMap[_selectedCategoryKey!] = updatedList;
                                _selectedSubcategories.add(newName);
                              });
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Subcategory "$newName" added & saved to database!',
                                    style: GoogleFonts.poppins(),
                                  ),
                                  backgroundColor: const Color(0xFF1B5E20),
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isAdding = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e', style: GoogleFonts.poppins()),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isAdding
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text('Save to Database', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditSubcategoryDialog(String currentName) async {
    if (_selectedCategoryKey == null) return;
    final textController = TextEditingController(text: currentName);
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) {
        bool isEditing = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B5E20).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit_rounded, color: Color(0xFF1B5E20), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Edit Subcategory',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rename "$currentName" in the database across $_finalPrimaryCategoryName.',
                      style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: textController,
                      autofocus: true,
                      style: GoogleFonts.poppins(fontSize: 13.5),
                      decoration: _buildFieldDecoration(
                        hintText: 'Enter new subcategory name',
                        prefixIcon: Icons.label_outline_rounded,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Subcategory name cannot be empty';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Cancel', style: GoogleFonts.poppins(color: const Color(0xFF64748B))),
                ),
                ElevatedButton(
                  onPressed: isEditing
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          final newName = textController.text.trim();
                          if (newName == currentName) {
                            Navigator.of(ctx).pop();
                            return;
                          }
                          setDialogState(() => isEditing = true);
                          try {
                            final updatedList = await CategoryService.editSubcategory(
                              categoryKey: _selectedCategoryKey!,
                              oldName: currentName,
                              newName: newName,
                            );
                            if (mounted) {
                              setState(() {
                                _categorySubcategoriesMap[_selectedCategoryKey!] = updatedList;
                                if (_selectedSubcategories.remove(currentName)) {
                                  _selectedSubcategories.add(newName);
                                }
                              });
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Subcategory renamed to "$newName" in database!',
                                    style: GoogleFonts.poppins(),
                                  ),
                                  backgroundColor: const Color(0xFF1B5E20),
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isEditing = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e', style: GoogleFonts.poppins()),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isEditing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text('Update Database', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showDeleteSubcategoryDialog(String nameToDelete) async {
    if (_selectedCategoryKey == null) return;

    await showDialog(
      context: context,
      builder: (ctx) {
        bool isDeleting = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Delete Subcategory',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              content: Text(
                'Are you sure you want to remove "$nameToDelete" from the database under $_finalPrimaryCategoryName?',
                style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF334155)),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Cancel', style: GoogleFonts.poppins(color: const Color(0xFF64748B))),
                ),
                ElevatedButton(
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setDialogState(() => isDeleting = true);
                          try {
                            final updatedList = await CategoryService.deleteSubcategory(
                              _selectedCategoryKey!,
                              nameToDelete,
                            );
                            if (mounted) {
                              setState(() {
                                _categorySubcategoriesMap[_selectedCategoryKey!] = updatedList;
                                _selectedSubcategories.remove(nameToDelete);
                              });
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Subcategory "$nameToDelete" removed from database!',
                                    style: GoogleFonts.poppins(),
                                  ),
                                  backgroundColor: const Color(0xFF1B5E20),
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isDeleting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e', style: GoogleFonts.poppins()),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text('Delete from Database', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSubcategoryActionSheet(String subcategoryName) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune_rounded, size: 20, color: Color(0xFF1B5E20)),
                    const SizedBox(width: 10),
                    Text(
                      'Subcategory: $subcategoryName',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.edit_rounded, color: Color(0xFF1B5E20)),
                  title: Text('Edit / Rename', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                  subtitle: Text('Modify name in the database', style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B))),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showEditSubcategoryDialog(subcategoryName);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
                  title: Text('Delete Subcategory', style: GoogleFonts.poppins(color: const Color(0xFFDC2626), fontWeight: FontWeight.w500)),
                  subtitle: Text('Remove from database catalog', style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B))),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showDeleteSubcategoryDialog(subcategoryName);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showManageSubcategoriesDialog() async {
    if (_selectedCategoryKey == null) return;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setManageState) {
            final currentSubs = _getCurrentSubcategories(_selectedCategoryKey!);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manage Subcategories',
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Category: $_finalPrimaryCategoryName',
                          style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: currentSubs.isEmpty
                    ? Center(
                        child: Text(
                          'No subcategories found. Tap Add below to create one.',
                          style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: currentSubs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        itemBuilder: (context, idx) {
                          final sub = currentSubs[idx];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            title: Text(
                              sub,
                              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF1B5E20)),
                                  onPressed: () async {
                                    await _showEditSubcategoryDialog(sub);
                                    setManageState(() {});
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                                  onPressed: () async {
                                    await _showDeleteSubcategoryDialog(sub);
                                    setManageState(() {});
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                ElevatedButton.icon(
                  onPressed: () async {
                    await _showAddSubcategoryDialog();
                    setManageState(() {});
                  },
                  icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                  label: Text('Add New Subcategory', style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.white, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // SAVE STALL & FORM HANDLING
  // =========================================================================

  Future<void> _saveStall() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_finalPrimaryCategoryName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a primary category', style: GoogleFonts.poppins(color: Colors.white)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select at least one operating day', style: GoogleFonts.poppins()),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? photoUrl = _existingPhotoUrl;

      if (_selectedImageBytes != null) {
        photoUrl = await CloudinaryService.uploadStallImageBytes(_selectedImageBytes!);
      }

      final combinedTags = <String>[
        ..._selectedSubcategories,
        ..._selectedTags.where((t) => !_selectedSubcategories.contains(t)),
      ];

      final stallData = <String, dynamic>{
        'name': _nameController.text.trim(),
        'category': _finalPrimaryCategoryName,
        'categories': [_finalPrimaryCategoryName, ..._selectedSubcategories],
        'subcategories': _selectedSubcategories.toList(),
        'products': _products,
        'address': _stallNumberController.text.trim(),
        'photoUrls': photoUrl != null ? [photoUrl] : (_existingPhotoUrl != null ? [_existingPhotoUrl!] : []),
        'openTime': _openTimeController.text.trim(),
        'closeTime': _closeTimeController.text.trim(),
        'daysOpen': _getDaysOpenArray(),
        'latitude': double.tryParse(_latitudeController.text) ?? 13.2419233,
        'longitude': double.tryParse(_longitudeController.text) ?? 123.538546,
        'status': _stallStatus,
        'isOpen': _stallStatus == 'open',
        'isActive': _stallStatus == 'open',
        'section': _selectedSection ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
        'tags': combinedTags,
      };

      if (widget.stallId != null) {
        await FirebaseFirestore.instance.collection('stalls').doc(widget.stallId).update(stallData);
      } else {
        await FirebaseFirestore.instance.collection('stalls').add(stallData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.stallId != null ? 'Stall updated successfully' : 'Stall created successfully',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: const Color(0xFF1B5E20),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving stall: $e', style: GoogleFonts.poppins()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
            color: const Color(0xFFF1F5F9),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => context.pop(),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFF1E293B),
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
              widget.stallId != null ? 'Edit Stall' : 'Add New Stall',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
            ),
            Text(
              widget.stallId != null ? 'Update stall information & schedule' : 'Register a new vendor in the directory',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          isDesktop ? 24 : 16,
          12,
          isDesktop ? 24 : 16,
          MediaQuery.of(context).padding.bottom + 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(
            top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveStall,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              disabledBackgroundColor: const Color(0xFF1B5E20).withValues(alpha: 0.6),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        widget.stallId != null ? 'Save Stall Changes' : 'Create Stall',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1B5E20)),
            )
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      isDesktop ? 24 : 16,
                      16,
                      isDesktop ? 24 : 16,
                      32,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // SECTION 1: BASIC INFORMATION
                        _buildFormCard(
                          title: 'Basic Information',
                          subtitle: 'Stall business name and physical address / number',
                          icon: Icons.storefront_rounded,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel('Stall Name', isRequired: true),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _nameController,
                                style: GoogleFonts.poppins(fontSize: 13.5, color: const Color(0xFF0F172A)),
                                decoration: _buildFieldDecoration(
                                  hintText: 'e.g. 4E\'S LLOBET MEATSHOP',
                                  prefixIcon: Icons.store_rounded,
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Stall name is required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildFieldLabel('Stall Number & Full Address', isRequired: true),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _stallNumberController,
                                style: GoogleFonts.poppins(fontSize: 13.5, color: const Color(0xFF0F172A)),
                                maxLines: 2,
                                minLines: 1,
                                decoration: _buildFieldDecoration(
                                  hintText: 'e.g. STALL #1 MEAT SECTION MARKET SITE, BAGUMBAYAN',
                                  prefixIcon: Icons.location_on_outlined,
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Stall address is required';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // SECTION 2: CATEGORY & SUBCATEGORIES
                        _buildFormCard(
                          title: 'Category & Subcategories',
                          subtitle: 'Select primary classification and add/edit subcategories (saved in database)',
                          icon: Icons.category_rounded,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel('Primary Category', isRequired: true),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _categoryList.map((cat) {
                                  final isSelected = _selectedCategoryKey == cat['key'];
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedCategoryKey = null;
                                          _selectedSubcategories.clear();
                                        } else {
                                          _selectedCategoryKey = cat['key'] as String;
                                          _selectedSubcategories.clear();
                                          _loadSubcategoriesForCategory(_selectedCategoryKey!);
                                        }
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFF1B5E20) : Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isSelected ? const Color(0xFF1B5E20) : const Color(0xFFE2E8F0),
                                          width: isSelected ? 1.5 : 1,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: const Color(0xFF1B5E20).withOpacity(0.18),
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
                                            cat['icon'] as IconData,
                                            size: 15,
                                            color: isSelected
                                                ? Colors.white
                                                : (cat['color'] as Color? ?? const Color(0xFF1B5E20)),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            cat['label'] as String,
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                              color: isSelected ? Colors.white : const Color(0xFF1E293B),
                                            ),
                                          ),
                                          if (isSelected) ...[
                                            const SizedBox(width: 5),
                                            const Icon(
                                              Icons.check_circle_rounded,
                                              size: 13,
                                              color: Colors.white,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),

                              // Subcategories Multi-Select Panel with Dynamic Add/Edit/Delete
                              AnimatedSize(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                                child: _selectedCategoryKey != null
                                    ? Builder(
                                        builder: (context) {
                                          final subcategories = _getCurrentSubcategories(_selectedCategoryKey!);

                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const SizedBox(height: 16),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.subdirectory_arrow_right_rounded,
                                                        size: 16,
                                                        color: Color(0xFF1B5E20),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        'Subcategories',
                                                        style: GoogleFonts.poppins(
                                                          fontSize: 12.5,
                                                          fontWeight: FontWeight.w700,
                                                          color: const Color(0xFF1B5E20),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Row(
                                                    children: [
                                                      // Quick Add Button
                                                      GestureDetector(
                                                        onTap: _showAddSubcategoryDialog,
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFF1B5E20),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              const Icon(Icons.add_rounded, size: 13, color: Colors.white),
                                                              const SizedBox(width: 3),
                                                              Text(
                                                                'Add',
                                                                style: GoogleFonts.poppins(
                                                                  fontSize: 11,
                                                                  fontWeight: FontWeight.w600,
                                                                  color: Colors.white,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      // Manage All Button
                                                      GestureDetector(
                                                        onTap: _showManageSubcategoriesDialog,
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFFF1F5F9),
                                                            borderRadius: BorderRadius.circular(6),
                                                            border: Border.all(color: const Color(0xFFCBD5E1)),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              const Icon(Icons.tune_rounded, size: 13, color: Color(0xFF475569)),
                                                              const SizedBox(width: 3),
                                                              Text(
                                                                'Manage',
                                                                style: GoogleFonts.poppins(
                                                                  fontSize: 11,
                                                                  fontWeight: FontWeight.w600,
                                                                  color: const Color(0xFF475569),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      // Select All / Clear All
                                                      GestureDetector(
                                                        onTap: () {
                                                          setState(() {
                                                            if (_selectedSubcategories.length == subcategories.length) {
                                                              _selectedSubcategories.clear();
                                                            } else {
                                                              _selectedSubcategories.addAll(subcategories);
                                                            }
                                                          });
                                                        },
                                                        child: Text(
                                                          _selectedSubcategories.length == subcategories.length
                                                              ? 'Clear'
                                                              : 'Select All',
                                                          style: GoogleFonts.poppins(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w600,
                                                            color: const Color(0xFF1B5E20),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF1F8E9),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: const Color(0xFF4CAF50).withOpacity(0.3),
                                                  ),
                                                ),
                                                child: _isLoadingSubcategories
                                                    ? const Padding(
                                                        padding: EdgeInsets.all(12.0),
                                                        child: Center(
                                                          child: SizedBox(
                                                            width: 20,
                                                            height: 20,
                                                            child: CircularProgressIndicator(
                                                              color: Color(0xFF1B5E20),
                                                              strokeWidth: 2,
                                                            ),
                                                          ),
                                                        ),
                                                      )
                                                    : Wrap(
                                                        spacing: 8,
                                                        runSpacing: 8,
                                                        children: [
                                                          ...subcategories.map((subValue) {
                                                            final isSubSelected = _selectedSubcategories.contains(subValue);

                                                            return GestureDetector(
                                                              onTap: () {
                                                                setState(() {
                                                                  if (isSubSelected) {
                                                                    _selectedSubcategories.remove(subValue);
                                                                  } else {
                                                                    _selectedSubcategories.add(subValue);
                                                                  }
                                                                });
                                                              },
                                                              onLongPress: () => _showSubcategoryActionSheet(subValue),
                                                              child: AnimatedContainer(
                                                                duration: const Duration(milliseconds: 180),
                                                                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                                                                decoration: BoxDecoration(
                                                                  color: isSubSelected ? const Color(0xFF1B5E20) : Colors.white,
                                                                  borderRadius: BorderRadius.circular(20),
                                                                  border: Border.all(
                                                                    color: isSubSelected
                                                                        ? const Color(0xFF1B5E20)
                                                                        : const Color(0xFFE2E8F0),
                                                                    width: isSubSelected ? 1.5 : 1,
                                                                  ),
                                                                ),
                                                                child: Row(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  children: [
                                                                    Icon(
                                                                      isSubSelected
                                                                          ? Icons.check_circle_rounded
                                                                          : Icons.add_circle_outline_rounded,
                                                                      size: 13,
                                                                      color: isSubSelected
                                                                          ? Colors.white
                                                                          : const Color(0xFF94A3B8),
                                                                    ),
                                                                    const SizedBox(width: 5),
                                                                    Text(
                                                                      subValue,
                                                                      style: GoogleFonts.poppins(
                                                                        fontSize: 11.5,
                                                                        fontWeight: isSubSelected
                                                                            ? FontWeight.w600
                                                                            : FontWeight.w400,
                                                                        color: isSubSelected
                                                                            ? Colors.white
                                                                            : const Color(0xFF1E293B),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            );
                                                          }),
                                                          // Inline Add Chip
                                                          GestureDetector(
                                                            onTap: _showAddSubcategoryDialog,
                                                            child: Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                              decoration: BoxDecoration(
                                                                color: Colors.white,
                                                                borderRadius: BorderRadius.circular(20),
                                                                border: Border.all(
                                                                  color: const Color(0xFF1B5E20),
                                                                  style: BorderStyle.solid,
                                                                ),
                                                              ),
                                                              child: Row(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  const Icon(Icons.add_rounded, size: 14, color: Color(0xFF1B5E20)),
                                                                  const SizedBox(width: 4),
                                                                  Text(
                                                                    'Add Subcategory',
                                                                    style: GoogleFonts.poppins(
                                                                      fontSize: 11.5,
                                                                      fontWeight: FontWeight.w600,
                                                                      color: const Color(0xFF1B5E20),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                              ),
                                            ],
                                          );
                                        },
                                      )
                                    : const SizedBox.shrink(),
                              ),

                              if (_finalPrimaryCategoryName.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFF81C784)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF2E7D32)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _selectedSubcategories.isEmpty
                                              ? 'Category: $_finalPrimaryCategoryName'
                                              : '$_finalPrimaryCategoryName (${_selectedSubcategories.length} subcategories selected)',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF1B5E20),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // SECTION 3: MARKET SECTION & BUILDING LOCATION
                        _buildFormCard(
                          title: 'Market Section / Building',
                          subtitle: 'Physical building, specialized section, or extension',
                          icon: Icons.account_balance_rounded,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...[
                                'Commodity Sections',
                                'Camarin Buildings',
                                'Numbered Buildings',
                                'Market Extensions',
                              ].map((groupName) {
                                final groupItems =
                                    MarketSections.items.where((s) => s.group == groupName).toList();
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4, bottom: 6),
                                      child: Text(
                                        groupName.toUpperCase(),
                                        style: GoogleFonts.poppins(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF64748B),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    Wrap(
                                      spacing: 7,
                                      runSpacing: 7,
                                      children: groupItems.map((section) {
                                        final isSelected =
                                            _selectedSection?.toUpperCase() == section.id.toUpperCase();
                                        return GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _selectedSection = isSelected ? null : section.id;
                                            });
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 180),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: isSelected ? const Color(0xFF1B5E20) : Colors.white,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isSelected
                                                    ? const Color(0xFF1B5E20)
                                                    : const Color(0xFFE2E8F0),
                                                width: isSelected ? 1.5 : 1,
                                              ),
                                              boxShadow: isSelected
                                                  ? [
                                                      BoxShadow(
                                                        color: const Color(0xFF1B5E20).withOpacity(0.18),
                                                        blurRadius: 4,
                                                        offset: const Offset(0, 2),
                                                      ),
                                                    ]
                                                  : [],
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  section.icon,
                                                  size: 13,
                                                  color: isSelected ? Colors.white : const Color(0xFF16A34A),
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  section.label,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 11.5,
                                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                    color: isSelected ? Colors.white : const Color(0xFF1E293B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                );
                              }),

                              if (_selectedSection != null) ...[
                                const SizedBox(height: 2),
                                Builder(
                                  builder: (context) {
                                    final sectionItem = MarketSections.findSection(_selectedSection);
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F5E9),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFF81C784)),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            sectionItem?.icon ?? Icons.location_on_rounded,
                                            size: 16,
                                            color: const Color(0xFF2E7D32),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Assigned: ${sectionItem?.label ?? _selectedSection!}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF1B5E20),
                                              ),
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () => setState(() => _selectedSection = null),
                                            child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF2E7D32)),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // SECTION 4: OPERATING SCHEDULE
                        _buildFormCard(
                          title: 'Operating Hours & Schedule',
                          subtitle: 'Service times and active days in the week',
                          icon: Icons.schedule_rounded,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel('Operating Hours', isRequired: true),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTimePickerTile(
                                      label: 'Open Time',
                                      controller: _openTimeController,
                                      icon: Icons.wb_sunny_outlined,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildTimePickerTile(
                                      label: 'Close Time',
                                      controller: _closeTimeController,
                                      icon: Icons.nightlight_outlined,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildFieldLabel('Operating Days', isRequired: true),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _buildDayPresetButton('Mon - Fri', ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']),
                                  const SizedBox(width: 8),
                                  _buildDayPresetButton('Mon - Sat', ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']),
                                  const SizedBox(width: 8),
                                  _buildDayPresetButton('Everyday', ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']),
                                ],
                              ),
                              const SizedBox(height: 10),
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
                                            color: isSelected ? const Color(0xFF1B5E20) : const Color(0xFFCBD5E1),
                                            width: isSelected ? 1.5 : 1,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            day['label']!,
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                              color: isSelected ? Colors.white : const Color(0xFF475569),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // SECTION 5: PRODUCTS & INVENTORY
                        _buildFormCard(
                          title: 'Products & Inventory',
                          subtitle: 'Items and goods sold at this stall',
                          icon: Icons.shopping_basket_rounded,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_productSuggestions.isNotEmpty) ...[
                                Text(
                                  'POPULAR SUGGESTIONS',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF64748B),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: _productSuggestions.take(8).map((s) {
                                      return GestureDetector(
                                        onTap: () => _addProduct(s),
                                        child: Container(
                                          margin: const EdgeInsets.only(right: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: const Color(0xFFCBD5E1)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.add_rounded, size: 13, color: Color(0xFF475569)),
                                              const SizedBox(width: 4),
                                              Text(
                                                s,
                                                style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF334155)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (_products.isNotEmpty) ...[
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: _products.map((p) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1B5E20),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            p,
                                            style: GoogleFonts.poppins(
                                              fontSize: 11.5,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          GestureDetector(
                                            onTap: () => _removeProduct(p),
                                            child: const Icon(Icons.close_rounded, size: 13, color: Colors.white),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 12),
                              ],
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _productController,
                                      focusNode: _productFocusNode,
                                      style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF0F172A)),
                                      decoration: _buildFieldDecoration(
                                        hintText: 'Add product (e.g. Pork Liempo, Adobo)',
                                        prefixIcon: Icons.add_shopping_cart_rounded,
                                      ),
                                      textInputAction: TextInputAction.done,
                                      onSubmitted: (_) => _addProduct(_productController.text),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Material(
                                    color: const Color(0xFF1B5E20),
                                    borderRadius: BorderRadius.circular(10),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: () => _addProduct(_productController.text),
                                      child: const SizedBox(
                                        width: 44,
                                        height: 44,
                                        child: Icon(Icons.add_rounded, color: Colors.white, size: 22),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // SECTION 6: STALL PHOTO
                        _buildFormCard(
                          title: 'Stall Photo',
                          subtitle: 'Upload a clear front-facing photo of this stall',
                          icon: Icons.photo_camera_rounded,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildPhotoSection(),
                              if (_selectedImageBytes != null ||
                                  (_existingPhotoUrl != null && _existingPhotoUrl!.isNotEmpty)) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.photo_library_rounded, size: 16, color: Color(0xFF1B5E20)),
                                        label: Text('Change Photo', style: GoogleFonts.poppins(fontSize: 12, color: Color(0xFF1B5E20))),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Color(0xFF1B5E20)),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        onPressed: _pickImage,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFE53935)),
                                      label: Text('Remove', style: GoogleFonts.poppins(fontSize: 12, color: Color(0xFFE53935))),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Color(0xFFE53935)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _selectedImageBytes = null;
                                          _existingPhotoUrl = null;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // SECTION 7: STALL STATUS
                        _buildFormCard(
                          title: 'Stall Operational Status',
                          subtitle: 'Current operational state shown in the public directory',
                          icon: Icons.toggle_on_rounded,
                          child: Column(
                            children: _statusOptions.map((status) {
                              final isSelected = _stallStatus == status['value'];
                              return GestureDetector(
                                onTap: () => setState(() => _stallStatus = status['value'] as String),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isSelected ? (status['bgColor'] as Color) : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? (status['color'] as Color)
                                          : const Color(0xFFE2E8F0),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? (status['color'] as Color).withValues(alpha: 0.15)
                                              : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          status['icon'] as IconData,
                                          size: 18,
                                          color: isSelected ? status['color'] as Color : const Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              status['label'] as String,
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                color: isSelected ? status['color'] as Color : const Color(0xFF0F172A),
                                              ),
                                            ),
                                            Text(
                                              status['description'] as String,
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                color: const Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSelected
                                                ? status['color'] as Color
                                                : const Color(0xFFCBD5E1),
                                            width: 2,
                                          ),
                                          color: isSelected ? status['color'] as Color : Colors.transparent,
                                        ),
                                        child: isSelected
                                            ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildFormCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B5E20).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: const Color(0xFF1B5E20)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String text, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF334155),
          ),
        ),
        if (isRequired)
          const Text(
            ' *',
            style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 13),
          ),
      ],
    );
  }

  InputDecoration _buildFieldDecoration({
    required String hintText,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF94A3B8)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      prefixIcon: Icon(prefixIcon, size: 18, color: const Color(0xFF64748B)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF1B5E20), width: 1.8),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _buildTimePickerTile({
    required String label,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: () => _selectTime(controller),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF1B5E20)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF64748B)),
                  ),
                  Text(
                    controller.text.isNotEmpty ? controller.text : 'Set time',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayPresetButton(String label, List<String> days) {
    final isMatching = _selectedDays.length == days.length && days.every(_selectedDays.contains);
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedDays.clear();
            _selectedDays.addAll(days);
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isMatching ? const Color(0xFF1B5E20) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isMatching ? const Color(0xFF1B5E20) : const Color(0xFFCBD5E1),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: isMatching ? FontWeight.w600 : FontWeight.w500,
                color: isMatching ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    if (_selectedImageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          _selectedImageBytes!,
          width: double.infinity,
          height: 180,
          fit: BoxFit.cover,
        ),
      );
    }

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
          errorBuilder: (_, __, ___) => _buildPhotoPlaceholder(),
        ),
      );
    }

    return _buildPhotoPlaceholder();
  }

  Widget _buildPhotoPlaceholder() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_a_photo_outlined, size: 28, color: Color(0xFF1B5E20)),
            ),
            const SizedBox(height: 10),
            Text(
              'Tap to upload stall photo',
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
            ),
            const SizedBox(height: 2),
            Text(
              'JPG, PNG up to 5MB',
              style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }
}
