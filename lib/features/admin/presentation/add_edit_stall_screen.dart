import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/stall_model.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/utils/stall_utils.dart';

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
  final _productController = TextEditingController();
  final _stallNumberController = TextEditingController();
  final _openTimeController = TextEditingController();
  final _closeTimeController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final FocusNode _productFocusNode = FocusNode();

  // State variables
  // Selected top-level category key
  String? _selectedCategoryKey;

  // Selected subcategory value (if has subcategories)
  String? _selectedSubcategory;

  // Final category value saved to Firestore
  // = subcategory if selected, else top-level value
  String get _finalCategoryValue {
    if (_selectedSubcategory != null && _selectedSubcategory!.isNotEmpty) {
      return _selectedSubcategory!;
    }
    if (_selectedCategoryKey != null) {
      final cat = _categoryList.firstWhere(
        (c) => c['key'] == _selectedCategoryKey,
        orElse: () => {},
      );
      return cat['value'] as String? ?? '';
    }
    return '';
  }

  // For backward compat with existing _selectedCategories list usage
  List<String> get _selectedCategories {
    final val = _finalCategoryValue;
    return val.isNotEmpty ? [val] : [];
  }

  List<String> _products = [];
  String? _selectedSection;
  final List<String> _selectedTags = [];
  final List<String> _selectedDays = [];
  String _stallStatus = 'open';
  File? _selectedImage;
  String? _existingPhotoUrl;
  bool _isLoading = false;
  bool _isSaving = false;

  static const List<Map<String, dynamic>> _categoryList = [
    {
      'key': 'fresh',
      'label': 'Fresh Produce',
      'icon': '🌿',
      'hasSubcategories': true,
      'value': 'fresh',
      'subcategories': [
        {
          'label': 'Seafood',
          'value': 'seafood',
          'icon': '🐟',
        },
        {
          'label': 'Meat',
          'value': 'meat',
          'icon': '🥩',
        },
        {
          'label': 'Poultry',
          'value': 'poultry',
          'icon': '🐔',
        },
        {
          'label': 'Vegetables',
          'value': 'vegetables',
          'icon': '🥬',
        },
        {
          'label': 'Fruits',
          'value': 'fruits',
          'icon': '🍎',
        },
      ],
    },
    {
      'key': 'processed',
      'label': 'Frozen & Processed',
      'icon': '🧊',
      'hasSubcategories': true,
      'value': 'frozen',
      'subcategories': [
        {
          'label': 'Frozen Goods',
          'value': 'frozen_goods',
          'icon': '❄️',
        },
        {
          'label': 'Processed Foods',
          'value': 'processed_foods',
          'icon': '🥫',
        },
        {
          'label': 'Spices',
          'value': 'spices',
          'icon': '🌶️',
        },
      ],
    },
    {
      'key': 'dry_goods',
      'label': 'Dry Goods',
      'icon': '🥬',
      'hasSubcategories': true,
      'value': 'dry_goods',
      'subcategories': [
        {
          'label': 'Rice Dealer',
          'value': 'rice_dealer',
          'icon': '🍚',
        },
        {
          'label': 'Dried Fish',
          'value': 'dried_fish',
          'icon': '🐠',
        },
      ],
    },
    {
      'key': 'cooked',
      'label': 'Cooked Food',
      'icon': '🍳',
      'hasSubcategories': true,
      'value': 'cooked',
      'subcategories': [
        {
          'label': 'Carinderia',
          'value': 'carinderia',
          'icon': '🍱',
        },
        {
          'label': 'Bakery',
          'value': 'bakery',
          'icon': '🍞',
        },
        {
          'label': 'Kakanin',
          'value': 'kakanin',
          'icon': '🍡',
        },
        {
          'label': 'Snack Stand',
          'value': 'snack_stand',
          'icon': '🍿',
        },
      ],
    },
    {
      'key': 'sari_sari',
      'label': 'Sari-Sari Store',
      'icon': '🏪',
      'hasSubcategories': false,
      'value': 'sari_sari',
      'subcategories': [],
    },
    {
      'key': 'retail',
      'label': 'Retail / Clothing',
      'icon': '👗',
      'hasSubcategories': true,
      'value': 'retail',
      'subcategories': [
        {
          'label': 'Ukay-Ukay',
          'value': 'ukay_ukay',
          'icon': '👕',
        },
        {
          'label': 'Tailor Shop',
          'value': 'tailor_shop',
          'icon': '🧵',
        },
      ],
    },
    {
      'key': 'general',
      'label': 'General Merchandise',
      'icon': '🛒',
      'hasSubcategories': true,
      'value': 'general',
      'subcategories': [
        {
          'label': 'Hardware & Tools',
          'value': 'hardware',
          'icon': '🔨',
        },
        {
          'label': 'School Supplies',
          'value': 'school_supplies',
          'icon': '📚',
        },
        {
          'label': 'Home Supplies',
          'value': 'home_supplies',
          'icon': '🏠',
        },
        {
          'label': 'Agrivet Supplies',
          'value': 'agrivet',
          'icon': '🌱',
        },
      ],
    },
    {
      'key': 'services',
      'label': 'Services',
      'icon': '🔧',
      'hasSubcategories': true,
      'value': 'services',
      'subcategories': [
        {
          'label': 'Electronics & Repair',
          'value': 'electronics_repair',
          'icon': '📱',
        },
        {
          'label': 'Barber / Salon',
          'value': 'barber_salon',
          'icon': '💈',
        },
      ],
    },
  ];

  static const List<Map<String, dynamic>> _statusOptions = [
    {
      'value': 'open',
      'label': 'Open for Service',
      'description': 'Currently serving customers',
      'icon': Icons.store_rounded,
      'color': Color(0xFF2E7D32),
      'bgColor': Color(0xFFE8F5E9),
    },
    {
      'value': 'closed',
      'label': 'Closed',
      'description': 'Not open today',
      'icon': Icons.storefront_outlined,
      'color': Color(0xFFC62828),
      'bgColor': Color(0xFFFFEBEE),
    },
    {
      'value': 'temporarily_closed',
      'label': 'Temporarily Closed',
      'description': 'Will reopen soon',
      'icon': Icons.pause_circle_outline_rounded,
      'color': Color(0xFFE65100),
      'bgColor': Color(0xFFFFF3E0),
    },
    {
      'value': 'renovation',
      'label': 'Under Renovation',
      'description': 'Stall is being renovated',
      'icon': Icons.construction_rounded,
      'color': Color(0xFF6A1B9A),
      'bgColor': Color(0xFFF3E5F5),
    },
    {
      'value': 'coming_soon',
      'label': 'Coming Soon',
      'description': 'New stall opening soon',
      'icon': Icons.new_releases_outlined,
      'color': Color(0xFF1565C0),
      'bgColor': Color(0xFFE3F2FD),
    },
  ];

  static const List<Map<String, dynamic>> _marketSections = [
    {
      'value': 'dry_goods_section',
      'label': 'Dry Goods Section',
      'description': 'Rice, dried fish, grains, condiments',
    },
    {
      'value': 'fruit_section',
      'label': 'Fruit Section',
      'description': 'Fresh fruits and produce',
    },
    {
      'value': 'vegetable_section',
      'label': 'Vegetable Section',
      'description': 'Fresh vegetables and greens',
    },
    {
      'value': 'rice_section',
      'label': 'Rice Section',
      'description': 'Rice dealers and grain sellers',
    },
    {
      'value': 'fish_chicken_section',
      'label': 'Fish & Chicken Section',
      'description': 'Fresh seafood and dressed poultry',
    },
    {
      'value': 'meat_section',
      'label': 'Meat Section',
      'description': 'Pork, beef, and carabao meat',
    },
    {
      'value': 'cooked_food_section',
      'label': 'Food Section',
      'description': 'Carinderia, eateries, and food stalls',
    },
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

  List<String> get _productSuggestions {
    final suggestions = <String>[];

    if (_selectedCategories.contains('seafood') ||
        _selectedCategories.contains('fresh')) {
      suggestions.addAll([
        'Bangus',
        'Tilapia',
        'Galunggong',
        'Pusit',
        'Hipon',
        'Alimango',
        'Tahong',
        'Tulingan',
      ]);
    }
    if (_selectedCategories.contains('meat')) {
      suggestions.addAll([
        'Pork',
        'Beef',
        'Carabao',
        'Pork Liempo',
        'Pork Ribs',
        'Ground Pork',
        'Beef Bulalo',
      ]);
    }
    if (_selectedCategories.contains('poultry')) {
      suggestions.addAll([
        'Whole Chicken',
        'Chicken Parts',
        'Native Chicken',
        'Duck',
        'Eggs',
        'Dressed Chicken',
      ]);
    }
    if (_selectedCategories.contains('vegetables')) {
      suggestions.addAll([
        'Ampalaya',
        'Sitaw',
        'Kangkong',
        'Pechay',
        'Kamote',
        'Gabi',
        'Talong',
        'Kamatis',
        'Sibuyas',
      ]);
    }
    if (_selectedCategories.contains('fruits')) {
      suggestions.addAll([
        'Mangga',
        'Saging',
        'Papaya',
        'Lansones',
        'Santol',
        'Suha',
        'Pineapple',
        'Watermelon',
      ]);
    }
    if (_selectedCategories.contains('cooked') ||
        _selectedCategories.contains('carinderia')) {
      suggestions.addAll([
        'Sinangag',
        'Adobo',
        'Sinigang',
        'Kare-kare',
        'Menudo',
        'Giniling',
        'Tinola',
        'Bulalo',
        'Breakfast Meal',
        'Lunch Special',
      ]);
    }
    if (_selectedCategories.contains('rice_dealer') ||
        _selectedCategories.contains('dry_goods')) {
      suggestions.addAll([
        'Dinorado',
        'Sinandomeng',
        'Jasmine Rice',
        'Brown Rice',
        'Malagkit',
        'Special Rice',
      ]);
    }
    if (_selectedCategories.contains('bakery')) {
      suggestions.addAll([
        'Pandesal',
        'Tasty Bread',
        'Ensaymada',
        'Monay',
        'Espasol',
        'Puto',
      ]);
    }
    if (_selectedCategories.contains('sari_sari')) {
      suggestions.addAll([
        'Canned Goods',
        'Softdrinks',
        'Snacks',
        'Instant Noodles',
        'Coffee',
        'Detergent',
        'Toiletries',
        'Candies',
      ]);
    }
    if (_selectedCategories.contains('retail')) {
      suggestions.addAll([
        'T-shirts',
        'Pants',
        'Dresses',
        'Ukay-Ukay',
        'School Uniforms',
        'Sandals',
        'Bags',
      ]);
    }
    if (_selectedCategories.contains('services')) {
      suggestions.addAll([
        'Haircut',
        'Hair Color',
        'Phone Repair',
        'Gadget Repair',
        'Alterations',
        'Tailoring',
      ]);
    }

    return suggestions.where((s) => !_products.contains(s)).toList();
  }

  String _normalizeCategoryValue(String value) {
    final v = value.toLowerCase().trim();
    switch (v) {
      case 'fish':
      case 'isda':
        return 'seafood';
      case 'beef':
      case 'pork':
      case 'karne':
        return 'meat';
      case 'chicken':
      case 'manok':
        return 'poultry';
      case 'gulay':
        return 'vegetables';
      case 'prutas':
        return 'fruits';
      case 'processed':
      case 'processed_foods':
      case 'frozen_goods':
      case 'spices':
      case 'pampalasa':
        return 'frozen';
      case 'drygoods':
        return 'dry_goods';
      case 'rice_dealer':
      case 'bigas':
        return 'rice';
      case 'cooked_food':
      case 'carinderia':
      case 'eatery':
      case 'bakery':
      case 'kakanin':
      case 'snack_stand':
        return 'cooked';
      case 'sarisari':
      case 'sari-sari':
      case 'sari_sari_store':
        return 'sari_sari';
      case 'clothing':
      case 'ukay_ukay':
      case 'tailor_shop':
        return 'retail';
      case 'hardware':
      case 'school_supplies':
      case 'home_supplies':
      case 'agrivet':
        return 'general';
      case 'electronics_repair':
      case 'barber_salon':
        return 'services';
      default:
        return v;
    }
  }

  void _addProduct(String value) {
    final parts = value
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      _productController.clear();
      return;
    }

    final existingLower = _products.map((p) => p.toLowerCase()).toSet();
    final toAdd = <String>[];

    for (final part in parts) {
      if (part.length > 40) continue;
      final lower = part.toLowerCase();
      if (existingLower.contains(lower) ||
          toAdd.any((item) => item.toLowerCase() == lower)) {
        continue;
      }
      toAdd.add(part);
    }

    setState(() {
      _products.addAll(toAdd);
      _productController.clear();
    });
  }

  void _removeProduct(String product) {
    setState(() {
      _products.remove(product);
    });
  }

  @override
  void initState() {
    super.initState();
    _productFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
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
    _productController.dispose();
    _stallNumberController.dispose();
    _openTimeController.dispose();
    _closeTimeController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _productFocusNode.dispose();
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
        _products = List<String>.from(stall.products);
        _stallNumberController.text = stall.address;
        
        final stallCat = _normalizeCategoryValue(stall.category).toLowerCase();

        _selectedCategoryKey = null;
        _selectedSubcategory = null;

        for (final cat in _categoryList) {
          final topValue = (cat['value'] as String).toLowerCase();
          final subs = cat['subcategories'] as List;

          if (stallCat == topValue) {
            _selectedCategoryKey = cat['key'] as String;
            break;
          }

          for (final sub in subs) {
            final subMap = sub as Map;
            final subValue = (subMap['value'] as String).toLowerCase();
            if (stallCat == subValue) {
              _selectedCategoryKey = cat['key'] as String;
              _selectedSubcategory = subMap['value'] as String;
              break;
            }
          }

          if (_selectedCategoryKey != null) {
            break;
          }
        }
        
        // Load tags
        _selectedTags.clear();
        _selectedTags.addAll(stall.tags);
        _selectedSection = stall.section?.isNotEmpty == true ? stall.section : null;
        
        _openTimeController.text = stall.openTime;
        _closeTimeController.text = stall.closeTime;
        
        // Parse operating days
        _parseOperatingDays(stall.daysOpen);
        
        _stallStatus = stall.status.isNotEmpty
          ? stall.status
          : (stall.isActive ? 'open' : 'closed');
        _latitudeController.text = stall.latitude.toString();
        _longitudeController.text = stall.longitude.toString();
        
        // Load existing photo URL - filter out demo/placeholder URLs
        if (stall.photoUrls.isNotEmpty) {
          _existingPhotoUrl = stall.photoUrls.first;
          // Remove hardcoded demo URLs
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

    if (_finalCategoryValue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select a category',
            style: GoogleFonts.poppins(
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
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
        'category': _finalCategoryValue,
        'categories': _selectedCategories,
        'products': _products,
        'address': _stallNumberController.text.trim(),
        'photoUrls': photoUrl != null ? [photoUrl] : [],
        'openTime': _openTimeController.text.trim(),
        'closeTime': _closeTimeController.text.trim(),
        'daysOpen': _getDaysOpenArray(),
        'latitude': double.tryParse(_latitudeController.text) ?? 13.4144,
        'longitude': double.tryParse(_longitudeController.text) ?? 123.5244,
        'status': _stallStatus,
        'isOpen': _stallStatus == 'open',
        'isActive': _stallStatus == 'open',
        'section': _selectedSection ?? '',
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

              // 2. Category
              Row(
                children: [
                  Text(
                    'Category',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Required',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: const Color(0xFFC62828),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Select the main category then choose a specific type.',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: const Color(0xFF9E9E9E),
                ),
              ),
              const SizedBox(height: 12),
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
                          _selectedSubcategory = null;
                        } else {
                          _selectedCategoryKey = cat['key'] as String;
                          _selectedSubcategory = null;
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF1B5E20) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF1B5E20) : const Color(0xFFE0E0E0),
                          width: isSelected ? 1.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF1B5E20).withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : [],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            cat['icon'] as String,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            cat['label'] as String,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected ? Colors.white : const Color(0xFF212121),
                            ),
                          ),
                          if ((cat['hasSubcategories'] as bool) && !isSelected) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: Color(0xFF9E9E9E),
                            ),
                          ],
                          if (isSelected) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: _selectedCategoryKey != null
                    ? Builder(
                        builder: (context) {
                          final selectedCat = _categoryList.firstWhere(
                            (c) => c['key'] == _selectedCategoryKey,
                            orElse: () => {'subcategories': []},
                          );

                          final subcategories = selectedCat['subcategories'] as List;

                          if (subcategories.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.subdirectory_arrow_right_rounded,
                                    size: 16,
                                    color: Color(0xFF1B5E20),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Select specific type (optional)',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1B5E20),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F8E9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF4CAF50).withOpacity(0.3),
                                  ),
                                ),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedSubcategory = null;
                                        });
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                        decoration: BoxDecoration(
                                          color: _selectedSubcategory == null
                                              ? const Color(0xFF1B5E20)
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: _selectedSubcategory == null
                                                ? const Color(0xFF1B5E20)
                                                : const Color(0xFFE0E0E0),
                                          ),
                                        ),
                                        child: Text(
                                          'General',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: _selectedSubcategory == null
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                            color: _selectedSubcategory == null
                                                ? Colors.white
                                                : const Color(0xFF666666),
                                          ),
                                        ),
                                      ),
                                    ),
                                    ...subcategories.map((sub) {
                                      final subMap = sub as Map<String, dynamic>;
                                      final isSubSelected = _selectedSubcategory == subMap['value'];

                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedSubcategory = isSubSelected
                                                ? null
                                                : subMap['value'] as String;
                                          });
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                          decoration: BoxDecoration(
                                            color: isSubSelected
                                                ? const Color(0xFF1B5E20)
                                                : Colors.white,
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: isSubSelected
                                                  ? const Color(0xFF1B5E20)
                                                  : const Color(0xFFE0E0E0),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                subMap['icon'] as String,
                                                style: const TextStyle(fontSize: 13),
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                subMap['label'] as String,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  fontWeight: isSubSelected
                                                      ? FontWeight.w600
                                                      : FontWeight.w400,
                                                  color: isSubSelected
                                                      ? Colors.white
                                                      : const Color(0xFF212121),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      )
                    : const SizedBox.shrink(),
              ),
              if (_finalCategoryValue.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF4CAF50)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: Color(0xFF2E7D32),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Category set to: ${StallUtils.getCategoryLabel(_finalCategoryValue)}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCategoryKey = null;
                            _selectedSubcategory = null;
                          });
                        },
                        child: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // 3. Market Section (Optional)
              Row(
                children: [
                  Text(
                    'Market Section',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E5F5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Optional',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: const Color(0xFF6A1B9A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Select the physical section where this stall is located in the market.',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: const Color(0xFF9E9E9E),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedSection = null;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedSection == null
                            ? const Color(0xFF424242)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _selectedSection == null
                              ? const Color(0xFF424242)
                              : const Color(0xFFE0E0E0),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'None',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: _selectedSection == null
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: _selectedSection == null
                                  ? Colors.white
                                  : const Color(0xFF9E9E9E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ..._marketSections.map((section) {
                    final isSelected = _selectedSection == section['value'];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedSection = isSelected ? null : section['value'] as String;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF1B5E20) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF1B5E20)
                                : const Color(0xFFE0E0E0),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              section['label'] as String,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                color: isSelected ? Colors.white : const Color(0xFF212121),
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
              if (_selectedSection != null) ...[
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final selected = _marketSections.firstWhere(
                      (s) => s['value'] == _selectedSection,
                    );
                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF4CAF50)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 16,
                            color: Color(0xFF2E7D32),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selected['label'] as String,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF2E7D32),
                                  ),
                                ),
                                Text(
                                  selected['description'] as String,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: const Color(0xFF4CAF50),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 20),

              // 4. Tags (Optional)
              Row(
                children: [
                  Text(
                    'Tags',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E5F5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Optional',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: const Color(0xFF6A1B9A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Select additional attributes for better stall visibility.',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: const Color(0xFF9E9E9E),
                ),
              ),
              const SizedBox(height: 12),
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

              // 4. Products / Services Sold
              Text(
                'Products / Services Sold',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF212121),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Add what this stall sells or offers',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: const Color(0xFF9E9E9E),
                ),
              ),
              const SizedBox(height: 10),
              if (_productSuggestions.isNotEmpty) ...[
                Text(
                  'Suggestions',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF666666),
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
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE0E0E0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.add_rounded,
                                size: 14,
                                color: Color(0xFF666666),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                s,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color(0xFF666666),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (_products.isNotEmpty) ...[
                Text(
                  'Added',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _products.map((p) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B5E20),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            p,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _removeProduct(p),
                            child: Container(
                              padding: const EdgeInsets.all(1),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.3),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _productController,
                      focusNode: _productFocusNode,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF212121),
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g. Pork, Adobo, Haircut...',
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF9E9E9E),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(
                          Icons.shopping_basket_outlined,
                          size: 18,
                          color: Color(0xFF9E9E9E),
                        ),
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
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                      onTapOutside: (_) => FocusScope.of(context).unfocus(),
                      onSubmitted: (_) => FocusScope.of(context).unfocus(),
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
                        width: 46,
                        height: 46,
                        child: Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Only + adds items. Use commas to split multiple items (e.g. Pork, Chicken).',
                style: GoogleFonts.poppins(
                  fontSize: 10.5,
                  color: const Color(0xFF9E9E9E),
                ),
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

              // 9. Stall Status
              Text(
                'Stall Status',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF212121),
                ),
              ),
              const SizedBox(height: 10),
              Column(
                children: _statusOptions.map((status) {
                  final isSelected = _stallStatus == status['value'];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _stallStatus = status['value'] as String;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (status['bgColor'] as Color)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? (status['color'] as Color)
                              : const Color(0xFFE0E0E0),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (status['color'] as Color).withOpacity(0.15)
                                  : const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              status['icon'] as IconData,
                              size: 20,
                              color: isSelected
                                  ? status['color'] as Color
                                  : const Color(0xFF9E9E9E),
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
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? status['color'] as Color
                                        : const Color(0xFF212121),
                                  ),
                                ),
                                Text(
                                  status['description'] as String,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: const Color(0xFF9E9E9E),
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
                                    : const Color(0xFFE0E0E0),
                                width: 2,
                              ),
                              color: isSelected
                                  ? status['color'] as Color
                                  : Colors.transparent,
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 12,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
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
