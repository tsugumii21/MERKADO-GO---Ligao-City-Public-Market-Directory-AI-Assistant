import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/stall_model.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/stall_utils.dart';

class ManageStallsScreen extends StatefulWidget {
  const ManageStallsScreen({super.key});

  @override
  State<ManageStallsScreen> createState() => _ManageStallsScreenState();
}

class _ManageStallsScreenState extends State<ManageStallsScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _refreshTimer;
  String _searchQuery = '';
  String _selectedType = 'all';
  String? _selectedSubcategory;
  String? _selectedTag;
  bool _subcategoryRowOpen = false;

  // Complete category map (exact copy from stalls_directory_screen.dart)
  final Map<String, Map<String, dynamic>> _categoryMap = {
    'all': {
      'label': 'All',
      'icon': Icons.store_rounded,
      'hasSubcategories': false,
      'categories': <String>[],
      'subcategories': <Map>[],
    },
    'fresh': {
      'label': 'Fresh Produce',
      'icon': Icons.eco_rounded,
      'hasSubcategories': true,
      'categories': [
        'fresh','seafood','fish','meat',
        'beef','pork','karne','poultry',
        'chicken','manok','vegetables',
        'gulay','fruits','prutas',
      ],
      'subcategories': [
        {
          'label': 'All Fresh',
          'tag': null,
          'categories': [
            'fresh','seafood','fish','meat',
            'beef','pork','karne','poultry',
            'chicken','manok','vegetables',
            'gulay','fruits','prutas',
          ],
        },
        {
          'label': 'Seafood',
          'tag': null,
          'categories': ['seafood','fish'],
        },
        {
          'label': 'Meat',
          'tag': null,
          'categories': [
            'meat','beef','pork','karne'],
        },
        {
          'label': 'Poultry',
          'tag': null,
          'categories': [
            'poultry','chicken','manok'],
        },
        {
          'label': 'Vegetables',
          'tag': null,
          'categories': [
            'vegetables','gulay'],
        },
        {
          'label': 'Fruits',
          'tag': null,
          'categories': [
            'fruits','prutas'],
        },
      ],
    },
    'processed': {
      'label': 'Frozen & Processed',
      'icon': Icons.kitchen_rounded,
      'hasSubcategories': true,
      'categories': [
        'frozen','frozen_goods','processed',
        'processed_foods','spices','pampalasa',
      ],
      'subcategories': [
        {
          'label': 'All Processed',
          'tag': null,
          'categories': [
            'frozen','frozen_goods',
            'processed','processed_foods',
            'spices','pampalasa',
          ],
        },
        {
          'label': 'Frozen Goods',
          'tag': null,
          'categories': [
            'frozen','frozen_goods'],
        },
        {
          'label': 'Processed Foods',
          'tag': null,
          'categories': [
            'processed','processed_foods'],
        },
        {
          'label': 'Spices',
          'tag': null,
          'categories': [
            'spices','pampalasa'],
        },
      ],
    },
    'dry_goods': {
      'label': 'Dry Goods',
      'icon': Icons.inventory_2_rounded,
      'hasSubcategories': true,
      'categories': [
        'dry_goods','drygoods','rice',
        'rice_dealer','bigas','dried_fish',
        'bulad','daing',
      ],
      'subcategories': [
        {
          'label': 'All Dry Goods',
          'tag': null,
          'categories': [
            'dry_goods','drygoods','rice',
            'rice_dealer','bigas',
            'dried_fish','bulad','daing',
          ],
        },
        {
          'label': 'Rice Dealer',
          'tag': 'rice_dealer',
          'categories': [
            'dry_goods','drygoods','rice',
            'rice_dealer','bigas',
            'dried_fish','bulad','daing',
          ],
        },
        {
          'label': 'Dried Fish',
          'tag': 'dried_fish',
          'categories': [
            'dry_goods','drygoods','rice',
            'rice_dealer','bigas',
            'dried_fish','bulad','daing',
          ],
        },
      ],
    },
    'cooked': {
      'label': 'Cooked Food',
      'icon': Icons.restaurant_rounded,
      'hasSubcategories': true,
      'categories': [
        'eatery','carinderia','cooked',
        'cooked_food','bakery','kakanin',
        'snack_stand','lutong_ulam',
      ],
      'subcategories': [
        {
          'label': 'All Cooked',
          'tag': null,
          'categories': [
            'eatery','carinderia','cooked',
            'cooked_food','bakery','kakanin',
            'snack_stand','lutong_ulam',
          ],
        },
        {
          'label': 'Carinderia',
          'tag': 'carinderia',
          'categories': [
            'eatery','carinderia','cooked',
            'cooked_food','bakery','kakanin',
            'snack_stand','lutong_ulam',
          ],
        },
        {
          'label': 'Bakery',
          'tag': 'bakery',
          'categories': [
            'eatery','carinderia','cooked',
            'cooked_food','bakery','kakanin',
            'snack_stand','lutong_ulam',
          ],
        },
        {
          'label': 'Kakanin',
          'tag': 'kakanin',
          'categories': [
            'eatery','carinderia','cooked',
            'cooked_food','bakery','kakanin',
            'snack_stand','lutong_ulam',
          ],
        },
        {
          'label': 'Snack Stand',
          'tag': 'snack_stand',
          'categories': [
            'eatery','carinderia','cooked',
            'cooked_food','bakery','kakanin',
            'snack_stand','lutong_ulam',
          ],
        },
      ],
    },
    'sari_sari': {
      'label': 'Sari-Sari Store',
      'icon': Icons.storefront_rounded,
      'hasSubcategories': false,
      'categories': [
        'sari_sari','sarisari',
        'sari-sari','sari_sari_store',
      ],
      'subcategories': <Map>[],
    },
    'retail': {
      'label': 'Retail / Clothing',
      'icon': Icons.checkroom_rounded,
      'hasSubcategories': true,
      'categories': [
        'retail','clothing','ukay_ukay',
        'ukay-ukay','ukay','tailor',
        'tailor_shop',
      ],
      'subcategories': [
        {
          'label': 'All Retail',
          'tag': null,
          'categories': [
            'retail','clothing','ukay_ukay',
            'ukay-ukay','ukay','tailor',
            'tailor_shop',
          ],
        },
        {
          'label': 'Ukay-Ukay',
          'tag': 'ukay_ukay',
          'categories': [
            'retail','clothing','ukay_ukay',
            'ukay-ukay','ukay','tailor',
            'tailor_shop',
          ],
        },
        {
          'label': 'Tailor Shop',
          'tag': 'tailor_shop',
          'categories': [
            'retail','clothing','ukay_ukay',
            'ukay-ukay','ukay','tailor',
            'tailor_shop',
          ],
        },
      ],
    },
    'general': {
      'label': 'General Merchandise',
      'icon': Icons.shopping_bag_rounded,
      'hasSubcategories': true,
      'categories': [
        'general','hardware','tools',
        'hardware_tools','school_supplies',
        'school','home_supplies','home',
        'agrivet','agrivet_supplies',
      ],
      'subcategories': [
        {
          'label': 'All General',
          'tag': null,
          'categories': [
            'general','hardware','tools',
            'hardware_tools',
            'school_supplies','school',
            'home_supplies','home',
            'agrivet','agrivet_supplies',
          ],
        },
        {
          'label': 'Hardware & Tools',
          'tag': 'hardware',
          'categories': [
            'general','hardware','tools',
            'hardware_tools',
            'school_supplies','school',
            'home_supplies','home',
            'agrivet','agrivet_supplies',
          ],
        },
        {
          'label': 'School Supplies',
          'tag': 'school_supplies',
          'categories': [
            'general','hardware','tools',
            'hardware_tools',
            'school_supplies','school',
            'home_supplies','home',
            'agrivet','agrivet_supplies',
          ],
        },
        {
          'label': 'Home Supplies',
          'tag': 'home_supplies',
          'categories': [
            'general','hardware','tools',
            'hardware_tools',
            'school_supplies','school',
            'home_supplies','home',
            'agrivet','agrivet_supplies',
          ],
        },
        {
          'label': 'Agrivet Supplies',
          'tag': 'agrivet',
          'categories': [
            'general','hardware','tools',
            'hardware_tools',
            'school_supplies','school',
            'home_supplies','home',
            'agrivet','agrivet_supplies',
          ],
        },
      ],
    },
    'services': {
      'label': 'Services',
      'icon': Icons.build_rounded,
      'hasSubcategories': true,
      'categories': [
        'services','electronics',
        'repair','electronics_repair',
        'barber','salon','barber_salon',
      ],
      'subcategories': [
        {
          'label': 'All Services',
          'tag': null,
          'categories': [
            'services','electronics',
            'repair','electronics_repair',
            'barber','salon','barber_salon',
          ],
        },
        {
          'label': 'Electronics & Repair',
          'tag': 'electronics_repair',
          'categories': [
            'services','electronics',
            'repair','electronics_repair',
            'barber','salon','barber_salon',
          ],
        },
        {
          'label': 'Barber / Salon',
          'tag': 'barber_salon',
          'categories': [
            'services','electronics',
            'repair','electronics_repair',
            'barber','salon','barber_salon',
          ],
        },
      ],
    },
  };

  List<String> _keywordsForFilterKeys(List<String> keys) {
    const keywordMap = {
      'seafood': ['fish', 'isda', 'tilapia', 'bangus', 'galunggong', 'tuna', 'shrimp', 'hipon', 'crab', 'squid', 'pusit', 'mussels', 'tahong'],
      'fish': ['fish', 'isda', 'tilapia', 'bangus', 'galunggong', 'tuna'],
      'meat': ['meat', 'karne', 'pork', 'baboy', 'beef', 'baka', 'carabao', 'chicken', 'manok'],
      'beef': ['beef', 'baka', 'carabao'],
      'pork': ['pork', 'baboy', 'liempo', 'ribs'],
      'poultry': ['chicken', 'manok', 'duck', 'itlog', 'eggs', 'poultry'],
      'chicken': ['chicken', 'manok'],
      'vegetables': ['vegetable', 'gulay', 'tomato', 'onion', 'garlic', 'eggplant', 'kangkong', 'sitaw', 'okra', 'pechay', 'cabbage', 'carrot'],
      'gulay': ['vegetable', 'gulay', 'tomato', 'onion', 'garlic', 'eggplant', 'kangkong', 'sitaw', 'okra', 'pechay', 'cabbage', 'carrot'],
      'fruits': ['fruit', 'prutas', 'mango', 'mangga', 'banana', 'saging', 'papaya', 'watermelon', 'pakwan', 'rambutan', 'lansones'],
      'prutas': ['fruit', 'prutas', 'mango', 'mangga', 'banana', 'saging', 'papaya', 'watermelon', 'pakwan', 'rambutan', 'lansones'],
      'frozen': ['frozen', 'processed', 'tocino', 'longganisa', 'hotdog', 'ham'],
      'frozen_goods': ['frozen', 'processed', 'tocino', 'longganisa', 'hotdog', 'ham'],
      'processed': ['processed', 'canned', 'de lata', 'instant'],
      'processed_foods': ['processed', 'canned', 'de lata', 'instant'],
      'spices': ['spice', 'pampalasa', 'seasoning', 'pepper', 'asin', 'toyo', 'suka'],
      'pampalasa': ['spice', 'pampalasa', 'seasoning', 'pepper', 'asin', 'toyo', 'suka'],
      'dry_goods': ['rice', 'bigas', 'dry', 'dried', 'bulad', 'daing', 'beans'],
      'drygoods': ['rice', 'bigas', 'dry', 'dried', 'bulad', 'daing', 'beans'],
      'rice': ['rice', 'bigas', 'sinandomeng', 'dinorado', 'jasmine', 'malagkit'],
      'rice_dealer': ['rice', 'bigas', 'sinandomeng', 'dinorado', 'jasmine', 'malagkit'],
      'bigas': ['rice', 'bigas', 'sinandomeng', 'dinorado', 'jasmine', 'malagkit'],
      'dried_fish': ['dried fish', 'bulad', 'daing', 'tuyo'],
      'bulad': ['dried fish', 'bulad', 'daing', 'tuyo'],
      'daing': ['dried fish', 'bulad', 'daing', 'tuyo'],
      'eatery': ['ulam', 'adobo', 'sinigang', 'pinakbet', 'carinderia', 'lutong', 'cooked', 'meal'],
      'carinderia': ['ulam', 'adobo', 'sinigang', 'pinakbet', 'carinderia', 'lutong', 'cooked', 'meal'],
      'cooked': ['ulam', 'adobo', 'sinigang', 'pinakbet', 'carinderia', 'lutong', 'cooked', 'meal'],
      'cooked_food': ['ulam', 'adobo', 'sinigang', 'pinakbet', 'carinderia', 'lutong', 'cooked', 'meal'],
      'lutong_ulam': ['ulam', 'adobo', 'sinigang', 'pinakbet', 'lutong'],
      'bakery': ['bread', 'tinapay', 'pan', 'cake', 'pastry', 'bakery'],
      'kakanin': ['kakanin', 'bibingka', 'suman', 'puto'],
      'snack_stand': ['snack', 'merienda', 'street food'],
      'sari_sari': ['canned', 'snacks', 'softdrinks', 'toiletries', 'condiments', 'sari'],
      'sarisari': ['canned', 'snacks', 'softdrinks', 'toiletries', 'condiments', 'sari'],
      'sari-sari': ['canned', 'snacks', 'softdrinks', 'toiletries', 'condiments', 'sari'],
      'sari_sari_store': ['canned', 'snacks', 'softdrinks', 'toiletries', 'condiments', 'sari'],
      'retail': ['clothes', 'clothing', 'ukay', 'shirt', 'pants', 'dress', 'tailor', 'tela'],
      'clothing': ['clothes', 'clothing', 'ukay', 'shirt', 'pants', 'dress', 'tailor', 'tela'],
      'ukay_ukay': ['ukay', 'secondhand', 'clothes', 'shirt', 'pants', 'dress'],
      'ukay-ukay': ['ukay', 'secondhand', 'clothes', 'shirt', 'pants', 'dress'],
      'ukay': ['ukay', 'secondhand', 'clothes', 'shirt', 'pants', 'dress'],
      'tailor': ['tailor', 'repair', 'alter'],
      'tailor_shop': ['tailor', 'repair', 'alter'],
      'general': ['hardware', 'tools', 'school', 'home', 'agrivet', 'merchandise'],
      'hardware': ['hardware', 'tools', 'martilyo', 'pako'],
      'tools': ['hardware', 'tools', 'martilyo', 'pako'],
      'hardware_tools': ['hardware', 'tools', 'martilyo', 'pako'],
      'school_supplies': ['notebook', 'paper', 'ballpen', 'school'],
      'school': ['notebook', 'paper', 'ballpen', 'school'],
      'home_supplies': ['home', 'cleaner', 'household'],
      'home': ['home', 'cleaner', 'household'],
      'agrivet': ['feed', 'veterinary', 'agrivet', 'fertilizer'],
      'agrivet_supplies': ['feed', 'veterinary', 'agrivet', 'fertilizer'],
      'services': ['repair', 'barber', 'salon', 'service'],
      'electronics': ['electronics', 'cellphone', 'repair'],
      'repair': ['repair', 'fix'],
      'electronics_repair': ['electronics', 'cellphone', 'repair'],
      'barber': ['barber', 'gupit', 'haircut', 'salon'],
      'salon': ['barber', 'gupit', 'haircut', 'salon'],
      'barber_salon': ['barber', 'gupit', 'haircut', 'salon'],
    };

    final all = <String>{};
    for (final key in keys) {
      all.addAll(keywordMap[key.toLowerCase()] ?? const <String>[]);
    }
    return all.toList();
  }

  String _normalizeFilterKey(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
  }

  bool _containsKeyword(String text, String keyword) {
    final cleanKeyword = keyword.toLowerCase().trim();
    if (cleanKeyword.isEmpty) return false;

    // Multi-word keywords should stay phrase-based, while single words use boundaries.
    if (cleanKeyword.contains(' ')) {
      return text.contains(cleanKeyword);
    }

    final pattern = RegExp(
      '(^|[^a-z0-9])' + RegExp.escape(cleanKeyword) + r'([^a-z0-9]|$)',
    );
    return pattern.hasMatch(text);
  }

  bool _matchesSellingData(StallModel stall, List<String> filterKeys) {
    final productText = stall.products.join(' ').toLowerCase();
    final tagSet = stall.tags.map((t) => _normalizeFilterKey(t)).toSet();
    final keySet = filterKeys.map((k) => _normalizeFilterKey(k)).toSet();
    const strictSubcategoryKeywords = {
      'rice_dealer': ['rice', 'bigas', 'sinandomeng', 'dinorado', 'jasmine', 'malagkit'],
      'dried_fish': ['dried fish', 'bulad', 'daing', 'tuyo'],
      'carinderia': ['ulam', 'adobo', 'sinigang', 'pinakbet', 'carinderia', 'lutong'],
      'bakery': ['bread', 'tinapay', 'cake', 'pastry', 'bakery', 'pan de'],
      'kakanin': ['kakanin', 'bibingka', 'suman', 'puto'],
      'snack_stand': ['snack', 'merienda', 'street food'],
      'ukay_ukay': ['ukay', 'secondhand', 'clothes'],
      'tailor_shop': ['tailor', 'alter', 'repair'],
      'electronics_repair': ['electronics', 'cellphone', 'repair'],
      'barber_salon': ['barber', 'haircut', 'gupit', 'salon'],
      'hardware': ['hardware', 'tools', 'martilyo', 'pako'],
      'school_supplies': ['notebook', 'paper', 'ballpen', 'school'],
      'home_supplies': ['household', 'cleaner', 'home'],
      'agrivet': ['agrivet', 'feed', 'veterinary', 'fertilizer'],
    };

    if (tagSet.intersection(keySet).isNotEmpty) {
      return true;
    }

    final strictKeys =
        keySet.where((k) => strictSubcategoryKeywords.containsKey(k)).toList();
    if (strictKeys.isNotEmpty) {
      final strictMatched = strictKeys.any((key) {
        final words = strictSubcategoryKeywords[key] ?? const <String>[];
        return words.any((word) => _containsKeyword(productText, word));
      });
      if (strictMatched) {
        return true;
      }
      if (keySet.length == 1) {
        return false;
      }
    }

    final keywords = _keywordsForFilterKeys(filterKeys);
    return keywords.any((kw) => _containsKeyword(productText, kw));
  }

  List<StallModel> _filterStalls(List<StallModel> stalls) {
    if (_selectedType == 'all') return stalls;
    
    final typeData = _categoryMap[_selectedType]!;
    final categories = List<String>.from(
        typeData['categories'] as List);
    
    List<StallModel> filtered = stalls.where((s) {
      final stallCats = s.categories.map((c) => c.toLowerCase().trim()).toList();
      final singleCat = s.category.toLowerCase().trim();
      final categoryMatch =
          stallCats.any((c) => categories.contains(c)) || categories.contains(singleCat);
      final sellingMatch = _matchesSellingData(s, categories);
      return categoryMatch || sellingMatch;
    }).toList();
    
    // Apply subcategory tag filter
    if (_selectedTag != null) {
      filtered = filtered
          .where((s) {
            final tagMatch = s.tags
                .map((t) => t.toLowerCase().trim())
                .contains(_selectedTag!.toLowerCase().trim());
            return tagMatch || _matchesSellingData(s, <String>[_selectedTag!]);
          })
          .toList();
    }
    
    return filtered;
  }

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteStall(BuildContext context, String stallId, String stallName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete "$stallName"?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'This stall will be permanently removed from the directory and the market map. This cannot be undone.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: const Color(0xFF666666),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: const Color(0xFF666666),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        // Delete from Firestore - map auto-updates via stream
        await FirebaseFirestore.instance
            .collection('stalls')
            .doc(stallId)
            .delete();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '"$stallName" has been deleted.',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              backgroundColor: const Color(0xFF2E7D32),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error deleting stall: $e',
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        elevation: 0,
        title: Text(
          'Manage Stalls',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1B5E20),
        onPressed: () => context.push(RouteNames.adminAddStall),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Add Stall',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search stalls by name, category...',
                hintStyle: GoogleFonts.poppins(color: const Color(0xFF999999)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF1B5E20)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Color(0xFF999999)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8F9FA),
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),

          // Filter Chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('fresh'),
                  const SizedBox(width: 8),
                  _buildFilterChip('processed'),
                  const SizedBox(width: 8),
                  _buildFilterChip('dry_goods'),
                  const SizedBox(width: 8),
                  _buildFilterChip('cooked'),
                  const SizedBox(width: 8),
                  _buildFilterChip('sari_sari'),
                  const SizedBox(width: 8),
                  _buildFilterChip('retail'),
                  const SizedBox(width: 8),
                  _buildFilterChip('general'),
                  const SizedBox(width: 8),
                  _buildFilterChip('services'),
                ],
              ),
            ),
          ),

          // Subcategory Row
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _subcategoryRowOpen
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8F9FA),
                      border: Border(
                        bottom: BorderSide(
                          color: Color(0xFFE0E0E0),
                          width: 1,
                        ),
                      ),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _buildSubcategoryChips(),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // Stalls List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('stalls')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1B5E20)),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading stalls',
                          style: GoogleFonts.poppins(color: Colors.red),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.store_outlined,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No stalls yet',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF666666),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to add your first stall',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: const Color(0xFF999999),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                var allStalls = snapshot.data!.docs
                    .map((doc) => StallModel.fromFirestore(doc))
                    .toList();

                // Apply category filter
                var stalls = _filterStalls(allStalls);

                // Apply search filter
                if (_searchQuery.isNotEmpty) {
                  stalls = stalls.where((stall) {
                    return stall.name.toLowerCase().contains(_searchQuery) ||
                        stall.category.toLowerCase().contains(_searchQuery) ||
                        stall.tags.any((tag) => tag.toLowerCase().contains(_searchQuery));
                  }).toList();
                }

                if (stalls.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No stalls found',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: const Color(0xFF666666),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Try a different search term'
                              : 'No stalls match this filter',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: const Color(0xFF999999),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stall count
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Text(
                        '${stalls.length} stalls',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF666666),
                        ),
                      ),
                    ),
                    
                    // Stall list
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          await Future.delayed(const Duration(milliseconds: 500));
                        },
                        color: const Color(0xFF1B5E20),
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: stalls.length,
                          itemBuilder: (context, index) {
                            final stall = stalls[index];
                            return _buildStallCard(context, stall);
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String type) {
    final typeData = _categoryMap[type]!;
    final isSelected = _selectedType == type;
    final hasSubcategories = typeData['hasSubcategories'] as bool;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (_selectedType == type) {
            // Same chip tapped - do nothing or optionally reset to 'all'
            return;
          }

          _selectedType = type;
          _selectedSubcategory = null;
          _selectedTag = null;

          // Open subcategory row if this type has subcategories
          if (hasSubcategories) {
            _subcategoryRowOpen = true;
          } else {
            _subcategoryRowOpen = false;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1B5E20) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF1B5E20) : const Color(0xFF1B5E20),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              typeData['icon'] as IconData,
              size: 16,
              color: isSelected ? Colors.white : const Color(0xFF1B5E20),
            ),
            const SizedBox(width: 6),
            Text(
              typeData['label'] as String,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF1B5E20),
              ),
            ),
            if (hasSubcategories) ...[
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: _subcategoryRowOpen && isSelected ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  size: 16,
                  color: isSelected ? Colors.white : const Color(0xFF1B5E20),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSubcategoryChips() {
    if (_selectedType == 'all') return [];

    final typeData = _categoryMap[_selectedType];
    if (typeData == null) return [];

    final subcategories = typeData['subcategories'] as List;
    if (subcategories.isEmpty) return [];

    List<Widget> chips = [];
    for (var i = 0; i < subcategories.length; i++) {
      final subcat = subcategories[i] as Map;
      final label = subcat['label'] as String;
      final tag = subcat['tag'] as String?;

      final isSelected = (_selectedSubcategory == label) ||
          (_selectedSubcategory == null && label.startsWith('All'));

      chips.add(
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedSubcategory = label;
              _selectedTag = tag;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF1B5E20) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF1B5E20),
                width: 1,
              ),
            ),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF1B5E20),
              ),
            ),
          ),
        ),
      );

      if (i < subcategories.length - 1) {
        chips.add(const SizedBox(width: 8));
      }
    }

    return chips;
  }

  String _getSectionLabel(String value) {
    const labels = {
      'dry_goods_section': 'Dry Goods Section',
      'fruit_section': 'Fruit Section',
      'vegetable_section': 'Vegetable Section',
      'rice_section': 'Rice Section',
      'fish_chicken_section': 'Fish & Chicken Section',
      'meat_section': 'Meat Section',
      'cooked_food_section': 'Food Section',
    };
    return labels[value] ??
        value
            .replaceAll('_', ' ')
            .split(' ')
            .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
            .join(' ');
  }

  Widget _buildStallCard(BuildContext context, StallModel stall) {
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
          // Row 1: Stall Name + Edit/Delete buttons
          Row(
            children: [
              Expanded(
                child: Text(
                  stall.name,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF212121),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 20),
                color: const Color(0xFF1B5E20),
                onPressed: () {
                  context.push(
                    '${RouteNames.adminStalls}/${stall.stallId}/edit',
                  );
                },
                tooltip: 'Edit',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_rounded, size: 20),
                color: const Color(0xFFE53935),
                onPressed: () => _deleteStall(
                  context,
                  stall.stallId,
                  stall.name,
                ),
                tooltip: 'Delete',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Row 2: Category chip + status badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF4CAF50)),
                ),
                child: Text(
                  StallUtils.getCategoryLabel(stall.category),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF2E7D32),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StallUtils.buildStatusBadge(stall),
            ],
          ),
          
          // Row 3: Tags (limit to 3)
          if (stall.section != null && stall.section!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 12,
                    color: Color(0xFF9E9E9E),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getSectionLabel(stall.section!),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color(0xFF9E9E9E),
                    ),
                  ),
                ],
              ),
            ),

          // Row 4: Tags (limit to 3)
          if (stall.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                ...stall.tags.take(3).map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E5F5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCE93D8)),
                  ),
                  child: Text(
                    StallUtils.getTagLabel(tag),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6A1B9A),
                    ),
                  ),
                )).toList(),
                if (stall.tags.length > 3)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E5F5),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCE93D8)),
                    ),
                    child: Text(
                      '+${stall.tags.length - 3} more',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6A1B9A),
                      ),
                    ),
                  ),
              ],
            ),
          ],

          // Row 5: Operating hours + days
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 12,
                color: Color(0xFF9E9E9E),
              ),
              const SizedBox(width: 4),
              Text(
                '${stall.openTime} - ${stall.closeTime}',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: const Color(0xFF9E9E9E),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.calendar_today_rounded,
                size: 12,
                color: Color(0xFF9E9E9E),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  StallUtils.formatOperatingDays(stall.daysOpen.join(', ')),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF9E9E9E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
