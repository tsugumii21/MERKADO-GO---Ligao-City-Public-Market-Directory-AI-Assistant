import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/stall_model.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/stall_utils.dart';
import '../../../core/theme/app_colors.dart';

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
      'icon': Icons.store_rounded,
      'hasSubcategories': false,
      'categories': [
        'sari_sari','sarisari','sari-sari',
        'sari_sari_store',
      ],
      'subcategories': <Map>[],
    },
    'retail': {
      'label': 'Clothing & Tailoring',
      'icon': Icons.checkroom_rounded,
      'hasSubcategories': true,
      'categories': [
        'retail','clothing','ukay_ukay',
        'ukay-ukay','ukay','tailor',
        'tailor_shop',
      ],
      'subcategories': [
        {
          'label': 'All Clothing',
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
            'ukay-ukay','ukay',
          ],
        },
        {
          'label': 'Tailor Shop',
          'tag': 'tailor_shop',
          'categories': [
            'tailor','tailor_shop',
          ],
        },
      ],
    },
    'general': {
      'label': 'General Merchandise',
      'icon': Icons.shopping_bag_rounded,
      'hasSubcategories': true,
      'categories': [
        'general','hardware','hardware_tools',
        'school_supplies','home_supplies',
        'agrivet','agrivet_supplies',
      ],
      'subcategories': [
        {
          'label': 'All Merchandise',
          'tag': null,
          'categories': [
            'general','hardware','hardware_tools',
            'school_supplies','home_supplies',
            'agrivet','agrivet_supplies',
          ],
        },
        {
          'label': 'Hardware & Tools',
          'tag': 'hardware',
          'categories': [
            'general','hardware','hardware_tools',
          ],
        },
        {
          'label': 'School & Office',
          'tag': 'school_supplies',
          'categories': [
            'general','school_supplies',
          ],
        },
        {
          'label': 'Home Supplies',
          'tag': 'home_supplies',
          'categories': [
            'general','home_supplies',
          ],
        },
        {
          'label': 'Agrivet Supplies',
          'tag': 'agrivet',
          'categories': [
            'general','agrivet','agrivet_supplies',
          ],
        },
      ],
    },
    'services': {
      'label': 'Services & Repair',
      'icon': Icons.build_rounded,
      'hasSubcategories': true,
      'categories': [
        'services','electronics_repair',
        'barber_salon',
      ],
      'subcategories': [
        {
          'label': 'All Services',
          'tag': null,
          'categories': [
            'services','electronics_repair',
            'barber_salon',
          ],
        },
        {
          'label': 'Electronics Repair',
          'tag': 'electronics_repair',
          'categories': [
            'services','electronics_repair',
          ],
        },
        {
          'label': 'Barber & Salon',
          'tag': 'barber_salon',
          'categories': [
            'services','barber_salon',
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

    if (cleanKeyword.contains(' ')) {
      return text.contains(cleanKeyword);
    }

    final pattern = RegExp(
      '(^|[^a-z0-9])${RegExp.escape(cleanKeyword)}([^a-z0-9]|\$)',
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
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1.0),
        ),
        title: Text(
          'Delete "$stallName"?',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        content: Text(
          'This stall will be permanently removed from the directory and the market map. This action cannot be undone.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.inkMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.inkMuted,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
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
              backgroundColor: AppColors.primary,
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
              backgroundColor: AppColors.error,
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
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        shape: const Border(
          bottom: BorderSide(
            color: AppColors.border,
            width: 1.0,
          ),
        ),
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Manage Stalls',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                'Ligao City Public Market',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onPressed: () => context.push(RouteNames.adminAddStall),
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
        label: Text(
          'Add Stall',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              Container(
                color: AppColors.surface,
                padding: EdgeInsets.fromLTRB(
                  isDesktop ? 24 : 16,
                  14,
                  isDesktop ? 24 : 16,
                  12,
                ),
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.ink,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search stalls by name, category...',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.inkMuted,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.inkMuted,
                        size: 20,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear_rounded,
                                color: AppColors.inkMuted,
                                size: 18,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.canvas,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                  ),
                ),
              ),
              Container(
                color: AppColors.surface,
                padding: EdgeInsets.fromLTRB(
                  isDesktop ? 24 : 16,
                  0,
                  isDesktop ? 24 : 16,
                  12,
                ),
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
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: _subcategoryRowOpen
                    ? Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 24 : 16,
                          vertical: 8,
                        ),
                        decoration: const BoxDecoration(
                          color: AppColors.canvas,
                          border: Border(
                            bottom: BorderSide(
                              color: AppColors.border,
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
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('stalls')
                      .orderBy('name')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 44, color: AppColors.error),
                            const SizedBox(height: 12),
                            Text(
                              'Error loading stalls',
                              style: GoogleFonts.poppins(color: AppColors.error),
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
                              Icons.storefront_outlined,
                              size: 64,
                              color: AppColors.inkSubtle,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'No stalls yet',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap "+ Add Stall" to add your first stall',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    var allStalls = snapshot.data!.docs
                        .map((doc) => StallModel.fromFirestore(doc))
                        .toList();

                    var stalls = _filterStalls(allStalls);

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
                              Icons.search_off_rounded,
                              size: 56,
                              color: AppColors.inkSubtle,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'No stalls found',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Try a different search term'
                                  : 'No stalls match this category',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            isDesktop ? 24 : 16,
                            12,
                            isDesktop ? 24 : 16,
                            8,
                          ),
                          child: Text(
                            '${stalls.length} stalls registered',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ),
                        
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: () async {
                              await Future.delayed(const Duration(milliseconds: 500));
                            },
                            color: AppColors.primary,
                            child: ListView.builder(
                              padding: EdgeInsets.fromLTRB(
                                isDesktop ? 24 : 16,
                                4,
                                isDesktop ? 24 : 16,
                                80,
                              ),
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
        ),
      ),
    );
  }

  Widget _buildFilterChip(String type) {
    final typeData = _categoryMap[type]!;
    final isSelected = _selectedType == type;
    final hasSubcategories = typeData['hasSubcategories'] as bool;

    return Material(
      color: isSelected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          setState(() {
            if (_selectedType == type) return;

            _selectedType = type;
            _selectedSubcategory = null;
            _selectedTag = null;

            if (hasSubcategories) {
              _subcategoryRowOpen = true;
            } else {
              _subcategoryRowOpen = false;
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                typeData['icon'] as IconData,
                size: 15,
                color: isSelected ? Colors.white : AppColors.inkMuted,
              ),
              const SizedBox(width: 6),
              Text(
                typeData['label'] as String,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.ink,
                ),
              ),
              if (hasSubcategories) ...[
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _subcategoryRowOpen && isSelected ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: isSelected ? Colors.white : AppColors.inkMuted,
                  ),
                ),
              ],
            ],
          ),
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
        Material(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() {
                _selectedSubcategory = label;
                _selectedTag = tag;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: 1,
                ),
              ),
              child: Text(
                label,
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

      if (i < subcategories.length - 1) {
        chips.add(const SizedBox(width: 6));
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  stall.name,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: AppColors.surfaceDim,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    context.push(
                      '${RouteNames.adminStalls}/${stall.stallId}/edit',
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    child: const Icon(
                      Icons.edit_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _deleteStall(
                    context,
                    stall.stallId,
                    stall.name,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDim,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  StallUtils.getCategoryLabel(stall.category),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StallUtils.buildStatusBadge(stall),
            ],
          ),
          
          if (stall.section != null && stall.section!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 13,
                    color: AppColors.inkMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getSectionLabel(stall.section!),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),

          if (stall.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                ...stall.tags.take(3).map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.canvas,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    StallUtils.getTagLabel(tag),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.inkMuted,
                    ),
                  ),
                )),
                if (stall.tags.length > 3)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.canvas,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      '+${stall.tags.length - 3} more',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ],

          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 13,
                color: AppColors.inkMuted,
              ),
              const SizedBox(width: 4),
              Text(
                '${stall.openTime} - ${stall.closeTime}',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.calendar_today_rounded,
                size: 12,
                color: AppColors.inkMuted,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  StallUtils.formatOperatingDays(stall.daysOpen.join(', ')),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.inkMuted,
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
