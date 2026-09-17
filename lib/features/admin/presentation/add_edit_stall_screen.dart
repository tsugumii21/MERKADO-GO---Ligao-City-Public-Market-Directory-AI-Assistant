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
import '../../map/domain/zone_palette.dart';
import 'widgets/admin_stall_location_picker.dart';
import 'widgets/admin_market_section_picker.dart';

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

  // Stepper & UI State
  int _currentStep = 0;
  bool _isSubcategoriesExpanded = false;
  final ScrollController _scrollController = ScrollController();

  // State Variables
  String? _selectedCategoryKey;
  final Set<String> _selectedSubcategories = {};
  final Map<String, List<String>> _categorySubcategoriesMap = {};
  bool _isLoadingSubcategories = false;
  List<String> _products = [];
  String? _selectedSection;
  String? _selectedPhysicalStallId;
  final List<String> _selectedTags = [];
  final List<String> _selectedDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  String _stallStatus = 'open';
  Uint8List? _selectedImageBytes;
  String? _existingPhotoUrl;
  bool _isPhotoRemoved = false;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _actualDocumentId;

  // Canonical Primary Category Name
  String get _finalPrimaryCategoryName {
    if (_selectedCategoryKey != null) {
      final cat = MarketCategories.findCategory(_selectedCategoryKey);
      if (cat != null) return cat.primaryCategoryName;
    }
    return '';
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
      'color': Color(0xFFDC2626),
      'bgColor': Color(0xFFFEF2F2),
      'borderColor': Color(0xFFFECACA),
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
    _scrollController.dispose();
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
          _isPhotoRemoved = false;
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

  void _removePhoto() {
    setState(() {
      _selectedImageBytes = null;
      _existingPhotoUrl = null;
      _isPhotoRemoved = true;
    });
  }

  bool get _hasPhoto =>
      !_isPhotoRemoved &&
      (_selectedImageBytes != null ||
          (_existingPhotoUrl != null && _existingPhotoUrl!.isNotEmpty));

  Future<void> _loadStallData() async {
    setState(() => _isLoading = true);
    try {
      DocumentSnapshot<Map<String, dynamic>>? doc;
      final directDoc = await FirebaseFirestore.instance
          .collection('stalls')
          .doc(widget.stallId)
          .get();

      if (directDoc.exists) {
        doc = directDoc;
      } else {
        final queries = await Future.wait([
          FirebaseFirestore.instance
              .collection('stalls')
              .where('stall_id', isEqualTo: widget.stallId)
              .limit(1)
              .get(),
          FirebaseFirestore.instance
              .collection('stalls')
              .where('physical_stall_id', isEqualTo: widget.stallId)
              .limit(1)
              .get(),
          FirebaseFirestore.instance
              .collection('stalls')
              .where('id', isEqualTo: widget.stallId)
              .limit(1)
              .get(),
        ]);
        for (final q in queries) {
          if (q.docs.isNotEmpty) {
            doc = q.docs.first;
            break;
          }
        }
      }

      if (doc != null && doc.exists && mounted) {
        _actualDocumentId = doc.id;
        final stall = StallModel.fromFirestore(doc);
        final data = doc.data() ?? {};
        _nameController.text = stall.name;
        _products = List<String>.from(stall.products);
        _stallNumberController.text = stall.address;
        _selectedPhysicalStallId = stall.hasMapLocation ? stall.mapStallId : null;

        // Find matching primary category
        final matchedCat = MarketCategories.findCategory(stall.category) ??
            (stall.categories.isNotEmpty ? MarketCategories.findCategory(stall.categories.first) : null);

        _selectedCategoryKey = matchedCat?.id;
        _selectedSubcategories.clear();

        if (_selectedCategoryKey != null) {
          await _loadSubcategoriesForCategory(_selectedCategoryKey!);
        }

        // Extract subcategories (products are never subcategories)
        final rawSubcategories = <String>{
          ...stall.subcategories,
          ...stall.tags,
          ...stall.categories,
          if (data['subcategories'] is List)
            ...(data['subcategories'] as List).map((e) => (e ?? '').toString().trim()),
        }..removeWhere((s) => _products.any((p) => p.trim().toLowerCase() == s.trim().toLowerCase()));

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
    const Map<String, int> dayOrder = {
      'Mon': 1, 'Tue': 2, 'Wed': 3, 'Thu': 4, 'Fri': 5, 'Sat': 6, 'Sun': 7,
      'Monday': 1, 'Tuesday': 2, 'Wednesday': 3, 'Thursday': 4, 'Friday': 5, 'Saturday': 6, 'Sunday': 7,
    };
    final sorted = List<String>.from(_selectedDays)
      ..sort((a, b) => (dayOrder[a] ?? 99).compareTo(dayOrder[b] ?? 99));

    final Map<String, String> dayMap = {
      'Mon': 'Monday',
      'Tue': 'Tuesday',
      'Wed': 'Wednesday',
      'Thu': 'Thursday',
      'Fri': 'Friday',
      'Sat': 'Saturday',
      'Sun': 'Sunday',
    };
    return sorted.map((d) => dayMap[d] ?? d).toList();
  }

  TimeOfDay _parseTimeOfDay(String timeStr) {
    try {
      final clean = timeStr.trim().toUpperCase();
      final isPm = clean.contains('PM');
      final isAm = clean.contains('AM');
      final raw = clean.replaceAll('AM', '').replaceAll('PM', '').trim();
      final parts = raw.split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0].trim());
        final minute = int.parse(parts[1].trim());
        if (isPm && hour < 12) hour += 12;
        if (isAm && hour == 12) hour = 0;
        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (_) {}
    return const TimeOfDay(hour: 6, minute: 0);
  }

  Future<void> _selectTime(TextEditingController controller) async {
    final initial = controller.text.isNotEmpty
        ? _parseTimeOfDay(controller.text)
        : const TimeOfDay(hour: 6, minute: 0);

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: AppTheme.buildTimePickerTheme,
    );

    if (picked != null && mounted) {
      final hour = picked.hourOfPeriod;
      final minute = picked.minute.toString().padLeft(2, '0');
      final period = picked.period == DayPeriod.am ? 'AM' : 'PM';
      setState(() {
        controller.text = '${hour == 0 ? 12 : hour}:$minute $period';
      });
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
            return Dialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF1B5E20), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Add Subcategory',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  'Category: $_finalPrimaryCategoryName',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'This will be saved to the database under $_finalPrimaryCategoryName and available for all stalls.',
                        style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B), height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: textController,
                        autofocus: true,
                        style: GoogleFonts.poppins(fontSize: 13.5, color: const Color(0xFF0F172A)),
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
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: isAdding ? null : () => Navigator.of(ctx).pop(),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
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
                                      if (!mounted || !context.mounted) return;
                                      setState(() {
                                        _categorySubcategoriesMap[_selectedCategoryKey!] = updatedList;
                                        _selectedSubcategories.add(newName);
                                      });
                                      if (ctx.mounted) {
                                        Navigator.of(ctx).pop();
                                      }
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Subcategory "$newName" added & saved to database!',
                                            style: GoogleFonts.poppins(),
                                          ),
                                          backgroundColor: const Color(0xFF1B5E20),
                                        ),
                                      );
                                    } catch (e) {
                                      setDialogState(() => isAdding = false);
                                      if (!mounted || !context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error: $e', style: GoogleFonts.poppins()),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1B5E20),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                            ),
                            child: isAdding
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : Text(
                                    'Save to Database',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
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
            return Dialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.edit_rounded, color: Color(0xFF1B5E20), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Edit Subcategory',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  'Category: $_finalPrimaryCategoryName',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Rename "$currentName" across the database for $_finalPrimaryCategoryName.',
                        style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B), height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: textController,
                        autofocus: true,
                        style: GoogleFonts.poppins(fontSize: 13.5, color: const Color(0xFF0F172A)),
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
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: isEditing ? null : () => Navigator.of(ctx).pop(),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
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
                                      if (!mounted || !context.mounted) return;
                                      setState(() {
                                        _categorySubcategoriesMap[_selectedCategoryKey!] = updatedList;
                                        if (_selectedSubcategories.remove(currentName)) {
                                          _selectedSubcategories.add(newName);
                                        }
                                      });
                                      if (ctx.mounted) {
                                        Navigator.of(ctx).pop();
                                      }
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Subcategory renamed to "$newName" in database!',
                                            style: GoogleFonts.poppins(),
                                          ),
                                          backgroundColor: const Color(0xFF1B5E20),
                                        ),
                                      );
                                    } catch (e) {
                                      setDialogState(() => isEditing = false);
                                      if (!mounted || !context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error: $e', style: GoogleFonts.poppins()),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1B5E20),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                            ),
                            child: isEditing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : Text(
                                    'Update Database',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
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
            return Dialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Delete Subcategory',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Are you sure you want to remove "$nameToDelete" from the database under $_finalPrimaryCategoryName?',
                      style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF334155), height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isDeleting ? null : () => Navigator.of(ctx).pop(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
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
                                    if (!mounted || !context.mounted) return;
                                    setState(() {
                                      _categorySubcategoriesMap[_selectedCategoryKey!] = updatedList;
                                      _selectedSubcategories.remove(nameToDelete);
                                    });
                                    if (ctx.mounted) {
                                      Navigator.of(ctx).pop();
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Subcategory "$nameToDelete" removed from database!',
                                          style: GoogleFonts.poppins(),
                                        ),
                                        backgroundColor: const Color(0xFF1B5E20),
                                      ),
                                    );
                                  } catch (e) {
                                    setDialogState(() => isDeleting = false);
                                    if (!mounted || !context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: $e', style: GoogleFonts.poppins()),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                          ),
                          child: isDeleting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Text(
                                  'Delete from Database',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSubcategoryActionSheet(String subcategoryName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.tune_rounded, size: 18, color: Color(0xFF1B5E20)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Subcategory: $subcategoryName',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 6),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.edit_rounded, color: Color(0xFF1B5E20)),
                  title: Text('Edit / Rename', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  subtitle: Text('Modify name in database', style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF64748B))),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showEditSubcategoryDialog(subcategoryName);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
                  title: Text('Delete Subcategory', style: GoogleFonts.poppins(color: const Color(0xFFDC2626), fontWeight: FontWeight.w600, fontSize: 13.5)),
                  subtitle: Text('Remove from database catalog', style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF64748B))),
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

            return Dialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Icon + Title + Category Subtitle + Close Button
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.tune_rounded,
                            color: Color(0xFF1B5E20),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Manage Subcategories',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Category: $_finalPrimaryCategoryName',
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Material(
                          color: const Color(0xFFF1F5F9),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.of(ctx).pop(),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 12),

                    // Scrollable List of Subcategory Cards
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: currentSubs.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 28),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.label_off_outlined, size: 36, color: Colors.grey.shade400),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No subcategories found.\nTap Add below to create one.',
                                      style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF64748B)),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: currentSubs.length,
                              itemBuilder: (context, idx) {
                                final sub = currentSubs[idx];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE8F5E9),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.label_outline_rounded,
                                          size: 15,
                                          color: Color(0xFF1B5E20),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          sub,
                                          style: GoogleFonts.poppins(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF1E293B),
                                          ),
                                        ),
                                      ),
                                      Material(
                                        color: const Color(0xFFE8F5E9),
                                        borderRadius: BorderRadius.circular(8),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(8),
                                          onTap: () async {
                                            await _showEditSubcategoryDialog(sub);
                                            setManageState(() {});
                                          },
                                          child: const Padding(
                                            padding: EdgeInsets.all(6),
                                            child: Icon(Icons.edit_rounded, size: 16, color: Color(0xFF1B5E20)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Material(
                                        color: const Color(0xFFFEE2E2),
                                        borderRadius: BorderRadius.circular(8),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(8),
                                          onTap: () async {
                                            await _showDeleteSubcategoryDialog(sub);
                                            setManageState(() {});
                                          },
                                          child: const Padding(
                                            padding: EdgeInsets.all(6),
                                            child: Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 16),

                    // Full-width Add Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await _showAddSubcategoryDialog();
                          setManageState(() {});
                        },
                        icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                        label: Text(
                          'Add New Subcategory',
                          style: GoogleFonts.poppins(fontSize: 13.5, color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B5E20),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // SAVE STALL & FORM HANDLING
  // =========================================================================

  Future<void> _showSuccessDialog({
    required bool isUpdate,
    required String stallName,
    required String category,
    required String address,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success Icon Badge
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFA7F3D0),
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF059669),
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Title
                Text(
                  isUpdate
                      ? 'Stall Updated Successfully'
                      : 'Stall Created Successfully',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  isUpdate
                      ? 'Changes to "$stallName" have been saved and are now live on the market directory.'
                      : '"$stallName" has been registered and is now live on the market directory.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    color: const Color(0xFF64748B),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),

                // Stall Summary Card Preview inside Dialog
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.storefront_rounded,
                            size: 16,
                            color: Color(0xFF1B5E20),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              stallName,
                              style: GoogleFonts.poppins(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (category.isNotEmpty || address.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          [
                            if (category.isNotEmpty) category,
                            if (address.isNotEmpty) address,
                          ].join(' • '),
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Action Button: "Done"
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogCtx).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Center(
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
        );
      },
    );
  }

  Future<void> _saveStall() async {
    // 1. Form Field Validation
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please fill in all required fields (Stall Name & Address)',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    // 2. Primary Category Selection Validation
    if (_finalPrimaryCategoryName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select a primary category for this stall',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    // 2.5 Subcategory Selection Validation (Ensure user assigns a subcategory for the category)
    final availableSubs = _selectedCategoryKey != null
        ? _getCurrentSubcategories(_selectedCategoryKey!)
        : <String>[];
    if (availableSubs.isNotEmpty && _selectedSubcategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select at least one subcategory for $_finalPrimaryCategoryName',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    // 3. Operating Days Validation
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select at least one operating day',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? photoUrl;
      if (!_isPhotoRemoved && _selectedImageBytes == null) {
        photoUrl = _existingPhotoUrl;
      }

      // Upload newly selected image to Cloudinary if picked
      if (_selectedImageBytes != null) {
        photoUrl = await CloudinaryService.uploadStallImageBytes(
          _selectedImageBytes!,
          stallId: widget.stallId,
        );
      }

      final combinedTags = <String>[
        ..._selectedSubcategories,
      ];

      final addressText = _stallNumberController.text.trim();
      final stallNameText = _nameController.text.trim();
      final openTimeText = _openTimeController.text.trim().isNotEmpty
          ? _openTimeController.text.trim()
          : '5:00 AM';
      final closeTimeText = _closeTimeController.text.trim().isNotEmpty
          ? _closeTimeController.text.trim()
          : '6:00 PM';
      final latValue = double.tryParse(_latitudeController.text.trim()) ?? 13.2419233;
      final lngValue = double.tryParse(_longitudeController.text.trim()) ?? 123.538546;

      final physicalSlot = (_selectedPhysicalStallId != null &&
              _selectedPhysicalStallId!.trim().isNotEmpty)
          ? _selectedPhysicalStallId!.trim()
          : null;

      final resolvedStallId = widget.stallId != null && widget.stallId!.isNotEmpty
          ? widget.stallId!
          : (physicalSlot ?? '');

      final stallData = <String, dynamic>{
        if (resolvedStallId.isNotEmpty) ...{
          'id': resolvedStallId,
          'stallId': physicalSlot ?? resolvedStallId,
          'stall_id': physicalSlot ?? resolvedStallId,
        },
        if (physicalSlot != null) ...{
          'physical_stall_id': physicalSlot,
          'physicalStallId': physicalSlot,
          'has_map_location': true,
        } else ...{
          'physical_stall_id': FieldValue.delete(),
          'physicalStallId': FieldValue.delete(),
          'has_map_location': false,
        },
        'name': stallNameText,
        'category': _finalPrimaryCategoryName,
        'categories': [_finalPrimaryCategoryName, ..._selectedSubcategories],
        'subcategories': _selectedSubcategories.toList(),
        'products': _products,
        'address': addressText,
        'stallNumber': addressText,
        'stall_number': addressText,
        'photoUrls': photoUrl != null && photoUrl.isNotEmpty
            ? [photoUrl]
            : <String>[],
        'photo_urls': photoUrl != null && photoUrl.isNotEmpty
            ? [photoUrl]
            : <String>[],
        if (_isPhotoRemoved && photoUrl == null) ...{
          'photoUrl': FieldValue.delete(),
          'photo_url': FieldValue.delete(),
        },
        'openTime': openTimeText,
        'open_time': openTimeText,
        'closeTime': closeTimeText,
        'close_time': closeTimeText,
        'daysOpen': _getDaysOpenArray(),
        'days_open': _getDaysOpenArray(),
        'latitude': latValue,
        'longitude': lngValue,
        'status': _stallStatus,
        'isOpen': _stallStatus == 'open',
        'isActive': true,
        'section': _selectedSection ?? '',
        'building_or_section': _selectedSection ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
        'tags': combinedTags,
      };

      if (widget.stallId != null && widget.stallId!.isNotEmpty) {
        // Edit Existing Stall - Use set with merge to guarantee save
        await FirebaseFirestore.instance
            .collection('stalls')
            .doc(_actualDocumentId ?? widget.stallId)
            .set(stallData, SetOptions(merge: true));
      } else {
        // Add New Stall
        if (physicalSlot != null && physicalSlot.isNotEmpty) {
          // Write directly to document matching the physical SVG slot ID
          await FirebaseFirestore.instance
              .collection('stalls')
              .doc(physicalSlot)
              .set(stallData, SetOptions(merge: true));
        } else {
          final newDoc =
              await FirebaseFirestore.instance.collection('stalls').add(stallData);
          await newDoc.set({
            'stallId': newDoc.id,
            'id': newDoc.id,
            'stall_id': newDoc.id,
          }, SetOptions(merge: true));
        }
      }

      if (mounted) {
        final isEdit = widget.stallId != null && widget.stallId!.isNotEmpty;
        await _showSuccessDialog(
          isUpdate: isEdit,
          stallName: stallNameText,
          category: _finalPrimaryCategoryName,
          address: addressText,
        );
        if (mounted) {
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving stall: $e', style: GoogleFonts.poppins(color: Colors.white)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      backgroundColor: AppColors.canvas,
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
              widget.stallId != null
                  ? 'Update stall information & schedule'
                  : 'Register a new vendor in the directory',
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
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(isDesktop),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  children: [
                    _buildStepperHeader(),
                    const Divider(height: 1, color: AppColors.border),
                    Expanded(
                      child: Form(
                        key: _formKey,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          padding: EdgeInsets.fromLTRB(
                            isDesktop ? 24 : 16,
                            16,
                            isDesktop ? 24 : 16,
                            32,
                          ),
                          child: _buildCurrentStepContent(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep0BasicInfo();
      case 1:
        return _buildStep1CategoryAndLocation();
      case 2:
        return _buildStep2ScheduleAndProducts();
      case 3:
      default:
        return _buildStep3PhotoAndStatus();
    }
  }

  // ----------------------------------------------------
  // STEP 0: BASIC INFORMATION & MARKET MAP LOCATION
  // ----------------------------------------------------
  Widget _buildStep0BasicInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                textAlignVertical: TextAlignVertical.center,
                style: GoogleFonts.poppins(fontSize: 13.5, color: const Color(0xFF0F172A)),
                decoration: _buildFieldDecoration(
                  hintText: "e.g. 4E'S LLOBET MEATSHOP",
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
                textAlignVertical: TextAlignVertical.center,
                style: GoogleFonts.poppins(fontSize: 13.5, color: const Color(0xFF0F172A)),
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
        _buildMapLocationCard(),
      ],
    );
  }

  // ----------------------------------------------------
  // STEP 1: CATEGORY & BUILDING LOCATION
  // ----------------------------------------------------
  Widget _buildStep1CategoryAndLocation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Primary Category Card
        _buildFormCard(
          title: 'Primary Category',
          subtitle: 'Main commodity classification for map coloring and directory search',
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
                          _selectedTags.clear();
                          _isSubcategoriesExpanded = false;
                        } else {
                          _selectedCategoryKey = cat['key'] as String;
                          _selectedSubcategories.clear();
                          _selectedTags.clear();
                          _isSubcategoriesExpanded = true;
                          _loadSubcategoriesForCategory(_selectedCategoryKey!);
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            cat['icon'] as IconData,
                            size: 15,
                            color: isSelected
                                ? Colors.white
                                : (cat['color'] as Color? ?? AppColors.primary),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            cat['label'] as String,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected ? Colors.white : AppColors.ink,
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
              if (_finalPrimaryCategoryName.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Selected: $_finalPrimaryCategoryName',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
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

        // Market Section & Building Card (Searchable Dropdown)
        _buildFormCard(
          title: 'Market Section & Building',
          subtitle: 'Physical architectural wing in Ligao Public Market (optional)',
          icon: Icons.account_balance_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFieldLabel('Market Section & Building'),
              const SizedBox(height: 8),
              AdminMarketSectionPicker(
                selectedSectionId: _selectedSection,
                onSectionChanged: (newSecId) {
                  setState(() => _selectedSection = newSecId);
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Subcategories & Tags Card (Collapsed by default)
        _buildSubcategoriesExpandable(),
      ],
    );
  }

  // ----------------------------------------------------
  // STEP 2: OPERATING SCHEDULE & INVENTORY
  // ----------------------------------------------------
  Widget _buildStep2ScheduleAndProducts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Operating Schedule
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
                          color: isSelected ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.border,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            day['label']!,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected ? Colors.white : AppColors.inkMuted,
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

        // Products & Inventory
        _buildFormCard(
          title: 'Products & Inventory',
          subtitle: 'Items and goods sold at this stall (optional)',
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
                    color: AppColors.inkMuted,
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
                            color: AppColors.canvas,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add_rounded, size: 13, color: AppColors.inkMuted),
                              const SizedBox(width: 4),
                              Text(
                                s,
                                style: GoogleFonts.poppins(fontSize: 11.5, color: AppColors.ink),
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
                        color: AppColors.primary,
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
                      style: GoogleFonts.poppins(fontSize: 13, color: AppColors.ink),
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
                    color: AppColors.primary,
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
      ],
    );
  }

  // ----------------------------------------------------
  // STEP 3: PHOTO & OPERATIONAL STATUS
  // ----------------------------------------------------
  Widget _buildStep3PhotoAndStatus() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stall Operational Status
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
                          : AppColors.border,
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
                              : AppColors.canvas,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          status['icon'] as IconData,
                          size: 18,
                          color: isSelected ? status['color'] as Color : AppColors.inkMuted,
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
                                color: isSelected ? status['color'] as Color : AppColors.ink,
                              ),
                            ),
                            Text(
                              status['description'] as String,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppColors.inkMuted,
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
                                : AppColors.border,
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

        const SizedBox(height: 16),

        // Stall Photo Card (Optional)
        _buildFormCard(
          title: 'Stall Photo',
          subtitle: 'Upload a clear front-facing photo of this stall (optional)',
          icon: Icons.photo_camera_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPhotoSection(),
              if (_hasPhoto) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.photo_library_rounded, size: 16, color: AppColors.primary),
                        label: Text(
                          'Change Photo',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                        onPressed: _isSaving ? null : _pickImage,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                        label: Text(
                          'Remove Photo',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFFDC2626),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFFEF2F2),
                          side: const BorderSide(color: Color(0xFFFECACA), width: 1.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                        onPressed: _isSaving ? null : _removePhoto,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Review Summary Card
        _buildReviewSummaryCard(),
      ],
    );
  }

  // ----------------------------------------------------
  // SUB-COMPONENTS: EXPANDABLE SUBCATEGORIES & SUMMARY
  // ----------------------------------------------------
  Widget _buildSubcategoriesExpandable() {
    if (_selectedCategoryKey == null) {
      return _buildFormCard(
        title: 'Subcategories',
        subtitle: 'Select a primary category above to view required subcategories',
        icon: Icons.tune_rounded,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.canvas,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.inkMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Select a Primary Category above to view and assign required subcategories.',
                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.inkMuted),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final subcategories = _getCurrentSubcategories(_selectedCategoryKey!);
    final count = _selectedSubcategories.length;

    return _buildFormCard(
      title: 'Subcategories',
      subtitle: 'Assign at least one subcategory classification (required)',
      icon: Icons.tune_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: AppColors.canvas,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                setState(() => _isSubcategoriesExpanded = !_isSubcategoriesExpanded);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: count > 0 ? AppColors.primary : AppColors.border,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.subdirectory_arrow_right_rounded,
                        size: 14,
                        color: count > 0 ? Colors.white : AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                count > 0
                                    ? '$count Subcategories Selected'
                                    : 'Subcategories',
                                style: GoogleFonts.poppins(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '*',
                                style: GoogleFonts.poppins(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            _isSubcategoriesExpanded
                                ? 'Tap to collapse'
                                : (count > 0
                                    ? 'Tap to edit assigned subcategories'
                                    : 'Tap to expand & select required subcategories'),
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              color: count > 0 ? AppColors.primary : AppColors.inkMuted,
                              fontWeight: count > 0 ? FontWeight.w500 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _isSubcategoriesExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.inkMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isSubcategoriesExpanded) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Subcategories for $_finalPrimaryCategoryName *',
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: _showAddSubcategoryDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              'Add',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _showManageSubcategoriesDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.canvas,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.tune_rounded, size: 14, color: AppColors.inkMuted),
                            const SizedBox(width: 4),
                            Text(
                              'Manage',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        child: Text(
                          _selectedSubcategories.length == subcategories.length ? 'Clear' : 'Select All',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceDim,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: _isLoadingSubcategories
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2.5,
                          ),
                        ),
                      ),
                    )
                  : Wrap(
                      spacing: 10,
                      runSpacing: 10,
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
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(
                                color: isSubSelected ? AppColors.primary : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSubSelected ? AppColors.primary : AppColors.border,
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
                                    size: 15,
                                    color: isSubSelected ? Colors.white : AppColors.inkSubtle,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    subValue,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      height: 1.25,
                                      letterSpacing: 0.1,
                                      fontWeight: isSubSelected ? FontWeight.w600 : FontWeight.w500,
                                      color: isSubSelected ? Colors.white : AppColors.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        GestureDetector(
                          onTap: _showAddSubcategoryDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.primary),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
                                const SizedBox(width: 6),
                                Text(
                                  'Add Subcategory',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    height: 1.25,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
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
        ],
      ),
    );
  }

  Widget _buildReviewSummaryCard() {
    final catItem = MarketCategories.findCategory(_selectedCategoryKey);
    final secItem = MarketSections.findSection(_selectedSection);
    final hasMapLoc = _selectedPhysicalStallId != null && _selectedPhysicalStallId!.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Review Stall Summary',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildSummaryRow(
            'Name',
            _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'Not provided',
          ),
          _buildSummaryRow(
            'Category',
            catItem?.displayName ?? (_finalPrimaryCategoryName.isNotEmpty ? _finalPrimaryCategoryName : 'Not selected'),
          ),
          if (_selectedSubcategories.isNotEmpty)
            _buildSummaryRow(
              'Subcategories',
              _selectedSubcategories.join(', '),
            ),
          _buildSummaryRow(
            'Section',
            secItem?.label ?? (_selectedSection ?? 'Unassigned'),
          ),
          _buildSummaryRow(
            'Map Slot',
            hasMapLoc ? _selectedPhysicalStallId! : 'No vector map location',
          ),
          _buildSummaryRow(
            'Hours',
            '${_openTimeController.text} - ${_closeTimeController.text}',
          ),
          _buildSummaryRow(
            'Days',
            _selectedDays.join(', '),
          ),
          _buildSummaryRow(
            'Status',
            _stallStatus.toUpperCase(),
          ),
          if (_products.isNotEmpty)
            _buildSummaryRow(
              'Products',
              '${_products.length} items',
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.inkMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // STEPPER HEADER & BOTTOM NAVIGATION
  // ----------------------------------------------------
  Widget _buildStepperHeader() {
    final steps = [
      ('Basic Info', Icons.storefront_rounded),
      ('Category & Location', Icons.category_rounded),
      ('Schedule & Products', Icons.schedule_rounded),
      ('Photo & Status', Icons.photo_camera_rounded),
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < steps.length; i++) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: () => _goToStep(i),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 30,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (i > 0)
                                Expanded(
                                  child: Container(
                                    height: 2,
                                    color: i <= _currentStep
                                        ? AppColors.primary
                                        : AppColors.border,
                                  ),
                                )
                              else
                                const Spacer(),
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: i < _currentStep
                                      ? AppColors.primary
                                      : (i == _currentStep
                                          ? AppColors.primary
                                          : AppColors.canvas),
                                  border: Border.all(
                                    color: i <= _currentStep
                                        ? AppColors.primary
                                        : AppColors.border,
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: i < _currentStep
                                      ? const Icon(
                                          Icons.check_rounded,
                                          size: 16,
                                          color: Colors.white,
                                        )
                                      : Text(
                                          '${i + 1}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: i == _currentStep
                                                ? Colors.white
                                                : AppColors.inkMuted,
                                          ),
                                        ),
                                ),
                              ),
                              if (i < steps.length - 1)
                                Expanded(
                                  child: Container(
                                    height: 2,
                                    color: i < _currentStep
                                        ? AppColors.primary
                                        : AppColors.border,
                                  ),
                                )
                              else
                                const Spacer(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 28,
                          child: Text(
                            steps[i].$1,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 10.5,
                              height: 1.15,
                              fontWeight: i == _currentStep
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: i == _currentStep
                                  ? AppColors.primary
                                  : AppColors.inkMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Step ${_currentStep + 1} of 4: ',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  steps[_currentStep].$1,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool isDesktop) {
    return Container(
      padding: EdgeInsets.only(
        left: isDesktop ? 24 : 16,
        right: isDesktop ? 24 : 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom > 0
            ? MediaQuery.of(context).padding.bottom + 8
            : 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: isDesktop ? 120 : 96,
            height: 50,
            child: OutlinedButton.icon(
              icon: Icon(
                _currentStep == 0 ? Icons.close_rounded : Icons.arrow_back_rounded,
                size: 16,
                color: AppColors.inkMuted,
              ),
              label: Text(
                _currentStep == 0 ? 'Cancel' : 'Back',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkMuted,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                side: const BorderSide(color: AppColors.border, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _prevStep,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.center,
                              child: Text(
                                _currentStep < 3
                                    ? (_currentStep == 0
                                        ? 'Next: Category & Location'
                                        : (_currentStep == 1
                                            ? 'Next: Schedule & Products'
                                            : 'Next: Photo & Status'))
                                    : (widget.stallId != null ? 'Save Stall Changes' : 'Create Stall'),
                                maxLines: 1,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            _currentStep < 3
                                ? Icons.arrow_forward_rounded
                                : Icons.check_circle_outline_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // STEPPER NAVIGATION & VALIDATION
  // ----------------------------------------------------
  bool _validateCurrentStep() {
    if (_currentStep == 0) {
      final name = _nameController.text.trim();
      final address = _stallNumberController.text.trim();
      if (name.isEmpty) {
        _showValidationWarning('Please enter a stall name.');
        return false;
      }
      if (address.isEmpty) {
        _showValidationWarning('Please enter stall number and address.');
        return false;
      }
      return _formKey.currentState?.validate() ?? true;
    } else if (_currentStep == 1) {
      if (_selectedCategoryKey == null || _selectedCategoryKey!.isEmpty) {
        _showValidationWarning('Please select a primary category.');
        return false;
      }
      final availableSubs = _getCurrentSubcategories(_selectedCategoryKey!);
      if (availableSubs.isNotEmpty && _selectedSubcategories.isEmpty) {
        setState(() => _isSubcategoriesExpanded = true);
        _showValidationWarning('Please select at least one subcategory for $_finalPrimaryCategoryName.');
        return false;
      }
      return true;
    } else if (_currentStep == 2) {
      if (_openTimeController.text.trim().isEmpty || _closeTimeController.text.trim().isEmpty) {
        _showValidationWarning('Please set operating hours.');
        return false;
      }
      if (_selectedDays.isEmpty) {
        _showValidationWarning('Please select at least one operating day.');
        return false;
      }
      return true;
    }
    return true;
  }

  void _showValidationWarning(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _goToStep(int step) {
    if (step < _currentStep) {
      setState(() => _currentStep = step);
      _scrollToTop();
    } else if (step > _currentStep) {
      if (_validateCurrentStep()) {
        setState(() => _currentStep = step);
        _scrollToTop();
      }
    }
  }

  void _nextStep() {
    if (_validateCurrentStep()) {
      if (_currentStep < 3) {
        setState(() => _currentStep++);
        _scrollToTop();
      } else {
        _saveStall();
      }
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _scrollToTop();
    } else {
      context.pop();
    }
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _openMapLocationPicker() async {
    final result = await AdminStallLocationPicker.show(
      context,
      initialStallId: _selectedPhysicalStallId ?? widget.stallId,
      stallCategory: _finalPrimaryCategoryName,
      stallName: _nameController.text.trim(),
    );

    if (result != null && mounted) {
      if (result.isCleared) {
        setState(() {
          _selectedPhysicalStallId = null;
        });
      } else {
        setState(() {
          _selectedPhysicalStallId = result.stallId;
          if (_selectedSection == null || _selectedSection!.isEmpty) {
            final matchedSec = MarketSections.findSection(result.sectionName);
            _selectedSection = matchedSec?.id ?? result.sectionName;
          }
          if (_stallNumberController.text.trim().isEmpty) {
            _stallNumberController.text = result.suggestedStallNumber;
          }
        });
      }
    }
  }

  Widget _buildMapLocationCard() {
    final hasLocation =
        _selectedPhysicalStallId != null && _selectedPhysicalStallId!.isNotEmpty;
    final catColorSet = _finalPrimaryCategoryName.isNotEmpty
        ? ZonePalette.getColorSet(_finalPrimaryCategoryName)
        : ZonePalette.produce;

    return _buildFormCard(
      title: 'Market Map Location',
      subtitle:
          'Physical position on the vector market map (only vacant light gray stalls can be picked)',
      icon: Icons.map_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hasLocation) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B5E20).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.add_location_alt_rounded,
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
                          'No Map Location Selected',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          'Tap the button below to pick an empty light gray stall on the map.',
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
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.map_rounded, size: 18, color: Color(0xFF1B5E20)),
                label: Text(
                  'Select Stall on Market Map',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1B5E20),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF1B5E20), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _openMapLocationPicker,
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B5E20).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.place_rounded,
                          color: Color(0xFF1B5E20),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedPhysicalStallId!,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: catColorSet.fill,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _finalPrimaryCategoryName.isNotEmpty
                                      ? 'Color: $_finalPrimaryCategoryName'
                                      : 'Color based on Category',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Text(
                          'Assigned',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF16A34A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(
                            Icons.edit_location_alt_rounded,
                            size: 16,
                            color: Color(0xFF1B5E20),
                          ),
                          label: Text(
                            'Change Location',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1B5E20),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF1B5E20)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _openMapLocationPicker,
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Color(0xFFDC2626),
                        ),
                        label: Text(
                          'Remove',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFDC2626),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFDC2626)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _selectedPhysicalStallId = null;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
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
      prefixIconConstraints: const BoxConstraints(minWidth: 46, minHeight: 46),
      isDense: true,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _buildTimePickerTile({
    required String label,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectTime(controller),
        borderRadius: BorderRadius.circular(10),
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
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller,
                      builder: (context, value, _) {
                        return Text(
                          value.text.isNotEmpty ? value.text : 'Set time',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F172A),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
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
    if (_hasPhoto && _selectedImageBytes != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              _selectedImageBytes!,
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.black.withValues(alpha: 0.65),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _isSaving ? null : _removePhoto,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_hasPhoto &&
        _existingPhotoUrl != null &&
        _existingPhotoUrl!.isNotEmpty &&
        _existingPhotoUrl!.startsWith('http')) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              _existingPhotoUrl!,
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildPhotoPlaceholder(),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.black.withValues(alpha: 0.65),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _isSaving ? null : _removePhoto,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
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


