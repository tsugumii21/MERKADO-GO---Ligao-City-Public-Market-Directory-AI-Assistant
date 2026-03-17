// Part 8: Rebuilt Sort & Filter System - 3 Options (Alphabetical, Time Range, Day+Status)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/stall_model.dart';
import '../../../providers/stall_provider.dart';
import '../../../providers/favorite_provider.dart';
import 'stall_detail_sheet.dart';
import '../../../core/utils/stall_utils.dart';

class StallListScreen extends ConsumerStatefulWidget {
  const StallListScreen({super.key});

  @override
  ConsumerState<StallListScreen> createState() => StallListScreenState();
}

class StallListScreenState extends ConsumerState<StallListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  String _selectedType = 'all';
  String? _selectedSubLabel;
  String? _selectedTag; // for product-level filtering (sari_sari only)
  bool _subcategoryRowVisible = false;
  String _searchQuery = '';
  List<StallModel> _allStalls = [];
  List<StallModel> _searchResults = [];
  bool _showDropdown = false;
  bool _isSearching = false;
  List<String> _recentlyViewedIds = [];

  // Sort/Filter state variables
  String? sortAlpha; // 'az' | 'za' | null
  TimeOfDay? filterOpenTime;
  TimeOfDay? filterCloseTime;
  String? selectedDay; // 'Mon'|'Tue'|...|null
  bool showOpenOnDay = true;
  bool _filterOpenOnly = false; // Filter to show only currently open stalls
  Timer? _statusTimer;

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
            'fresh','seafood','fish',
            'meat','beef','pork','karne',
            'poultry','chicken','manok',
            'vegetables','gulay',
            'fruits','prutas',
          ],
        },
        {
          'label': 'Seafood',
          'tag': null,
          'categories': [
            'seafood','fish'],
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
        'frozen','frozen_goods',
        'processed','processed_foods',
        'spices','pampalasa',
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
        'rice_dealer','bigas',
        'dried_fish','bulad','daing',
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
            'eatery','carinderia',
            'cooked','cooked_food',
            'bakery','kakanin',
            'snack_stand','lutong_ulam',
          ],
        },
        {
          'label': 'Carinderia',
          'tag': 'carinderia',
          'categories': [
            'eatery','carinderia',
            'cooked','cooked_food',
            'bakery','kakanin',
            'snack_stand','lutong_ulam',
          ],
        },
        {
          'label': 'Bakery',
          'tag': 'bakery',
          'categories': [
            'eatery','carinderia',
            'cooked','cooked_food',
            'bakery','kakanin',
            'snack_stand','lutong_ulam',
          ],
        },
        {
          'label': 'Kakanin',
          'tag': 'kakanin',
          'categories': [
            'eatery','carinderia',
            'cooked','cooked_food',
            'bakery','kakanin',
            'snack_stand','lutong_ulam',
          ],
        },
        {
          'label': 'Snack Stand',
          'tag': 'snack_stand',
          'categories': [
            'eatery','carinderia',
            'cooked','cooked_food',
            'bakery','kakanin',
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
            'retail','clothing',
            'ukay_ukay','ukay-ukay',
            'ukay','tailor','tailor_shop',
          ],
        },
        {
          'label': 'Ukay-Ukay',
          'tag': 'ukay_ukay',
          'categories': [
            'retail','clothing',
            'ukay_ukay','ukay-ukay',
            'ukay','tailor','tailor_shop',
          ],
        },
        {
          'label': 'Tailor Shop',
          'tag': 'tailor_shop',
          'categories': [
            'retail','clothing',
            'ukay_ukay','ukay-ukay',
            'ukay','tailor','tailor_shop',
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
        'hardware_tools',
        'school_supplies','school',
        'home_supplies','home',
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

  final List<String> filterChipKeys = [
    'all',
    'favorites',
    'fresh',
    'processed',
    'dry_goods',
    'cooked',
    'sari_sari',
    'retail',
    'general',
    'services',
  ];

  final Map<String, List<String>> dayMapping = {
    'Mon': ['monday', 'mon'],
    'Tue': ['tuesday', 'tue'],
    'Wed': ['wednesday', 'wed'],
    'Thu': ['thursday', 'thu'],
    'Fri': ['friday', 'fri'],
    'Sat': ['saturday', 'sat'],
    'Sun': ['sunday', 'sun'],
  };

  // Reset UI state when user leaves this tab
  void resetUI() {
    if (!mounted) return;

    // Scroll to top with animation
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    // Close subcategory row
    setState(() {
      _selectedSubLabel = null;
      _selectedTag = null;
      _subcategoryRowVisible = false;
    });

    // Clear search
    _searchController.clear();
    setState(() => _searchQuery = '');

    // Close any open bottom sheets (filter sheet)
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    // DO NOT reset: _selectedType (filter chip), favorites
  }

  void showFavoritesView() {
    if (!mounted) return;

    _searchFocusNode.unfocus();
    _searchController.clear();

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    setState(() {
      _selectedType = 'favorites';
      _selectedSubLabel = null;
      _selectedTag = null;
      _subcategoryRowVisible = false;
      _searchQuery = '';
      _searchResults = [];
      _showDropdown = false;
      _isSearching = false;
    });

    ref.read(favoriteProvider.notifier).loadFavorites();
  }

  @override
  void initState() {
    super.initState();
    
    // Reset all filter and search state to initial values
    _selectedType = 'all';
    _selectedSubLabel = null;
    _selectedTag = null;
    _subcategoryRowVisible = false;
    _searchQuery = '';
    _searchController.clear();
    
    // Reset sort/filter state
    sortAlpha = null;
    filterOpenTime = null;
    filterCloseTime = null;
    selectedDay = null;
    showOpenOnDay = true;
    _filterOpenOnly = false;
    
    _loadRecentlyViewed();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(favoriteProvider.notifier).loadFavorites();
    });

    _searchFocusNode.addListener(() {
      if (!mounted) return;
      setState(() {
        _showDropdown = _searchFocusNode.hasFocus && _searchQuery.isNotEmpty;
      });
    });
    
    // Refresh open/closed status every 60 seconds
    _statusTimer = Timer.periodic(
      const Duration(seconds: 60), 
      (_) {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChangedLive(String query) {
    final trimmedQuery = query.trim();

    setState(() {
      _searchQuery = trimmedQuery;
      _isSearching = trimmedQuery.isNotEmpty;
    });

    if (trimmedQuery.isEmpty) {
      setState(() {
        _searchResults = [];
        _showDropdown = false;
      });
      return;
    }

    final q = trimmedQuery.toLowerCase();
    final matches = _allStalls.where((s) {
      if (s.name.toLowerCase().contains(q)) return true;
      if (s.category.toLowerCase().contains(q)) return true;
      if (s.categories.any((c) => c.toLowerCase().contains(q))) return true;
      if (s.tags.any((t) =>
          t.toLowerCase().contains(q) ||
          StallUtils.getTagLabel(t).toLowerCase().contains(q))) {
        return true;
      }
      if (s.products.any((p) => p.toLowerCase().contains(q))) return true;
      if (s.section != null && s.section!.toLowerCase().contains(q)) {
        return true;
      }
      return false;
    }).take(8).toList();

    setState(() {
      _searchResults = matches;
      _showDropdown = _searchFocusNode.hasFocus && _searchQuery.isNotEmpty;
    });
  }

  void _onStallSelectedFromSearch(StallModel stall) {
    _searchFocusNode.unfocus();
    setState(() {
      _showDropdown = false;
      _searchController.text = stall.name;
      _searchQuery = stall.name;
    });

    _openStallDetail(stall);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _searchResults = [];
      _showDropdown = false;
      _isSearching = false;
    });
    _searchFocusNode.unfocus();
  }

  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty) {
      return Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF212121),
        ),
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final matchIndex = lowerText.indexOf(lowerQuery);

    if (matchIndex == -1) {
      return Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF212121),
        ),
      );
    }

    return RichText(
      text: TextSpan(
        children: [
          if (matchIndex > 0)
            TextSpan(
              text: text.substring(0, matchIndex),
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF212121),
              ),
            ),
          TextSpan(
            text: text.substring(matchIndex, matchIndex + query.length),
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1B5E20),
              backgroundColor: const Color(0xFFE8F5E9),
            ),
          ),
          if (matchIndex + query.length < text.length)
            TextSpan(
              text: text.substring(matchIndex + query.length),
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF212121),
              ),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  String? _getMatchedProduct(StallModel stall) {
    final q = _searchQuery.toLowerCase();
    if (q.isEmpty) return null;
    try {
      return stall.products.firstWhere((p) => p.toLowerCase().contains(q));
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadRecentlyViewed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentIds = prefs.getStringList('recently_viewed_stalls') ?? [];
      if (mounted) {
        setState(() {
          _recentlyViewedIds = recentIds.take(5).toList();
        });
      }
    } catch (e) {
      debugPrint('❌ Error: Failed to load recently viewed stalls: $e');
    }
  }

  Future<void> _saveRecentlyViewed(String stallId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> recentIds =
          prefs.getStringList('recently_viewed_stalls') ?? [];

      recentIds.remove(stallId);
      recentIds.insert(0, stallId);

      if (recentIds.length > 5) {
        recentIds = recentIds.sublist(0, 5);
      }

      await prefs.setStringList('recently_viewed_stalls', recentIds);

      if (mounted) {
        setState(() {
          _recentlyViewedIds = recentIds;
        });
      }
    } catch (e) {
      debugPrint('❌ Error: Failed to save recently viewed stalls: $e');
    }
  }

  Future<void> _clearRecentlyViewed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('recently_viewed_stalls');
      if (mounted) {
        setState(() {
          _recentlyViewedIds = [];
        });
      }
    } catch (e) {
      debugPrint('❌ Error: Failed to clear recently viewed stalls: $e');
    }
  }

  TimeOfDay parseTime(String timeStr) {
    timeStr = timeStr.trim().toUpperCase();
    bool isPM = timeStr.contains('PM');
    bool isAM = timeStr.contains('AM');
    timeStr = timeStr.replaceAll('AM', '').replaceAll('PM', '').trim();
    final parts = timeStr.split(':');
    int hour = int.parse(parts[0]);
    int minute = int.parse(parts[1]);
    if (isPM && hour != 12) hour += 12;
    if (isAM && hour == 12) hour = 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  bool stallOpenOnDay(StallModel stall, String day) {
    final dayVariants = dayMapping[day] ?? [day];
    return stall.daysOpen.any((d) =>
        dayVariants.any((v) => d.toLowerCase().contains(v.toLowerCase())));
  }

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

  void _onSubcategorySelected(Map<String, dynamic> subcategory) {
    try {
      setState(() {
        _selectedSubLabel = subcategory['label'] as String?;
        _selectedTag = subcategory['tag'] as String?;
      });
    } catch (e) {
      debugPrint('❌ Subcategory select error: $e');
      setState(() {
        _selectedSubLabel = null;
        _selectedTag = null;
      });
    }
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

  List<StallModel> applyFilters(List<StallModel> stalls, List<String> favoriteIds) {
    try {
      if (stalls.isEmpty) return [];

      final favoriteSet = favoriteIds.toSet();
      var result = List<StallModel>.from(stalls);

      if (_searchQuery.isNotEmpty) {
        final queryLower = _searchQuery.toLowerCase().trim();
        result = result.where((s) {
          try {
            final nameMatch = s.name.toLowerCase().contains(queryLower);
            final productMatch = s.products.any(
              (p) => p.toLowerCase().contains(queryLower),
            );
            return nameMatch || productMatch;
          } catch (_) {
            return false;
          }
        }).toList();
      }

      if (_selectedType == 'favorites') {
        result = result.where((s) {
          try {
            return favoriteSet.contains(s.stallId);
          } catch (_) {
            return false;
          }
        }).toList();
      } else if (_selectedType != 'all') {
        final typeData = _categoryMap[_selectedType];
        if (typeData != null) {
          final rawCats = typeData['categories'];
          final baseCats = rawCats is List
              ? rawCats
                  .map((c) => (c ?? '').toString().toLowerCase().trim())
                  .where((c) => c.isNotEmpty)
                  .toList()
              : <String>[];

          var activeCats = List<String>.from(baseCats);
          if (_selectedSubLabel != null) {
            final subcategories = (typeData['subcategories'] is List)
                ? (typeData['subcategories'] as List)
                    .whereType<Map>()
                    .toList()
                : <Map>[];
            final selectedSubcat = subcategories.where(
              (sub) => sub['label'] == _selectedSubLabel,
            );
            if (selectedSubcat.isNotEmpty && selectedSubcat.first['categories'] is List) {
              activeCats = (selectedSubcat.first['categories'] as List)
                  .map((c) => (c ?? '').toString().toLowerCase().trim())
                  .where((c) => c.isNotEmpty)
                  .toList();
            }
          }

          if (activeCats.isNotEmpty) {
            result = result.where((s) {
              try {
                final singleCat = s.category.toLowerCase().trim();
                final stallCats = s.categories
                    .map((c) => c.toLowerCase().trim())
                    .where((c) => c.isNotEmpty)
                    .toList();

                if (activeCats.contains(singleCat) ||
                    stallCats.any((c) => activeCats.contains(c))) {
                  return true;
                }

                return _matchesSellingData(s, activeCats);
              } catch (_) {
                return false;
              }
            }).toList();
          }
        }
      }

      if (_selectedTag != null && _selectedTag!.isNotEmpty) {
        final selectedTag = _selectedTag!.toLowerCase().trim();
        result = result.where((s) {
          try {
            final stallTags = s.tags
                .map((t) => t.toLowerCase().trim())
                .where((t) => t.isNotEmpty)
                .toList();
            final tagMatch = stallTags.contains(selectedTag);
            return tagMatch || _matchesSellingData(s, <String>[selectedTag]);
          } catch (_) {
            return false;
          }
        }).toList();
      }

      if (filterOpenTime != null && filterCloseTime != null) {
        result = result.where((s) {
          try {
            final stallOpen = parseTime(s.openTime);
            final stallClose = parseTime(s.closeTime);
            final toMinutes = (TimeOfDay t) => t.hour * 60 + t.minute;

            final stallOpenMinutes = toMinutes(stallOpen);
            final stallCloseMinutes = toMinutes(stallClose);
            final selectedOpenMinutes = toMinutes(filterOpenTime!);
            final selectedCloseMinutes = toMinutes(filterCloseTime!);

            return stallOpenMinutes <= selectedOpenMinutes &&
                stallCloseMinutes >= selectedCloseMinutes;
          } catch (_) {
            return false;
          }
        }).toList();
      }

      if (selectedDay != null) {
        result = result.where((s) {
          try {
            final isOpen = stallOpenOnDay(s, selectedDay!);
            return showOpenOnDay ? isOpen : !isOpen;
          } catch (_) {
            return false;
          }
        }).toList();
      }

      if (_filterOpenOnly) {
        result = result.where((s) {
          try {
            return StallUtils.isStallOpenNow(s);
          } catch (_) {
            return false;
          }
        }).toList();
      }

      if (sortAlpha == 'az') {
        result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      } else if (sortAlpha == 'za') {
        result.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
      }

      return result;
    } catch (e) {
      debugPrint('❌ Filter error: $e');
      return List<StallModel>.from(stalls);
    }
  }

  int getActiveFilterCount() {
    int count = 0;
    if (sortAlpha != null) count++;
    if (filterOpenTime != null && filterCloseTime != null) count++;
    if (selectedDay != null) count++;
    if (_filterOpenOnly) count++;
    return count;
  }

  void resetAllFilters() {
    setState(() {
      sortAlpha = null;
      filterOpenTime = null;
      filterCloseTime = null;
      selectedDay = null;
      showOpenOnDay = true;
      _filterOpenOnly = false;
    });
  }

  void removeFilter(String filterType) {
    setState(() {
      switch (filterType) {
        case 'alpha':
          sortAlpha = null;
          break;
        case 'time':
          filterOpenTime = null;
          filterCloseTime = null;
          break;
        case 'day':
          selectedDay = null;
          break;
      }
    });
  }

  List<StallModel> _getRecentlyViewedStalls(List<StallModel> allStalls) {
    return _recentlyViewedIds
        .map((id) {
          try {
            return allStalls.firstWhere((stall) => stall.stallId == id);
          } catch (e) {
            return null;
          }
        })
        .whereType<StallModel>()
        .take(5)
        .toList();
  }

  void _openStallDetail(StallModel stall) {
    _saveRecentlyViewed(stall.stallId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StallDetailSheet(
        stall: stall,
        onClose: () {
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: false,
      builder: (context) => _FilterBottomSheet(
        currentSortAlpha: sortAlpha,
        currentFilterOpenTime: filterOpenTime,
        currentFilterCloseTime: filterCloseTime,
        currentSelectedDay: selectedDay,
        currentShowOpenOnDay: showOpenOnDay,
        currentFilterOpenOnly: _filterOpenOnly,
        onApply: (newSortAlpha, newOpenTime, newCloseTime, newDay, newShowOpen, newOpenOnly) {
          setState(() {
            sortAlpha = newSortAlpha;
            filterOpenTime = newOpenTime;
            filterCloseTime = newCloseTime;
            selectedDay = newDay;
            showOpenOnDay = newShowOpen;
            _filterOpenOnly = newOpenOnly;
          });
        },
        onReset: resetAllFilters,
        parseTime: parseTime,
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    // For individual stall categories displayed in stall cards
    switch (category.toLowerCase().replaceAll(' ', '_')) {
      case 'seafood':
      case 'fish':
        return Icons.water_outlined;
      case 'pork':
      case 'baboy':
      case 'beef':
      case 'baka':
      case 'meat':
      case 'karne':
        return Icons.set_meal_outlined;
      case 'poultry':
      case 'manok':
        return Icons.egg_outlined;
      case 'vegetables':
      case 'gulay':
        return Icons.eco_outlined;
      case 'fruits':
      case 'prutas':
        return Icons.energy_savings_leaf_outlined;
      case 'rice':
      case 'bigas':
        return Icons.grain_rounded;
      case 'sari_sari':
      case 'sarisari':
      case 'sari-sari':
        return Icons.store_rounded;
      case 'dry_goods':
      case 'drygoods':
        return Icons.shopping_bag_outlined;
      case 'spices':
      case 'pampalasa':
        return Icons.grass_outlined;
      case 'ukay_ukay':
      case 'ukay-ukay':
      case 'ukayukay':
      case 'ukay':
      case 'clothing':
        return Icons.checkroom_rounded;
      case 'eatery':
      case 'carinderia':
      case 'cooked':
      case 'cooked_food':
      case 'lutong_ulam':
        return Icons.restaurant_rounded;
      case 'frozen':
      case 'frozen_goods':
      case 'processed':
      case 'processed_foods':
        return Icons.kitchen_rounded;
      default:
        return Icons.storefront_outlined;
    }
  }

  String _getCategoryDisplayName(String category) {
    // For individual stall categories - just return as is with proper casing
    return category;
  }

  String _getGroupDisplayName(String groupKey) {
    // For filter chip group labels
    final typeData = _categoryMap[groupKey];
    if (typeData != null && typeData['label'] != null) {
      return typeData['label'] as String;
    }
    return groupKey; // Fallback
  }

  String _getDisplayNameForCount() {
    // Returns the display name for stall count text
    if (_searchQuery.isNotEmpty) {
      return 'Search Results';
    }
    
    if (_selectedSubLabel != null) {
      // For dry_goods, cooked, retail, general, and services with tag filtering, show "Tag - Type" format
      if (_selectedTag != null) {
        if (_selectedType == 'dry_goods') {
          return '$_selectedSubLabel - Dry Goods';
        } else if (_selectedType == 'cooked') {
          return '$_selectedSubLabel - Cooked Food';
        } else if (_selectedType == 'retail') {
          return '$_selectedSubLabel - Retail';
        } else if (_selectedType == 'general') {
          return '$_selectedSubLabel - General Merchandise';
        } else if (_selectedType == 'services') {
          return '$_selectedSubLabel - Services';
        }
      }
      return _selectedSubLabel!;
    }
    
    return _getGroupDisplayName(_selectedType);
  }

  String formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final stallsAsync = ref.watch(allStallsProvider);
    final favoriteState = ref.watch(favoriteProvider);
    final activeFilterCount = getActiveFilterCount();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Text(
          'Stalls Directory',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: Builder(
        builder: (context) {
          try {
            return stallsAsync.when(
        data: (allStalls) {
          _allStalls = allStalls;
          final filteredStalls = applyFilters(allStalls, favoriteState.favoriteIds);
          final recentlyViewed = _getRecentlyViewedStalls(allStalls);

          return Column(
            children: [
              // Search bar
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  children: [
                    Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: _showDropdown
                            ? const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              )
                            : BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE0E0E0),
                          width: 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          Icon(
                            Icons.search_rounded,
                            color: const Color(0xFF9E9E9E),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: const Color(0xFF212121),
                                fontWeight: FontWeight.w400,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search stalls, products...',
                                hintStyle: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: const Color(0xFFBDBDBD),
                                  fontWeight: FontWeight.w400,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                filled: true,
                                fillColor: Colors.white,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                counterText: '',
                                helperText: null,
                              ),
                              onChanged: _onSearchChangedLive,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) {
                                if (_searchResults.isNotEmpty) {
                                  _onStallSelectedFromSearch(_searchResults.first);
                                }
                              },
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            GestureDetector(
                              onTap: _clearSearch,
                              child: const Padding(
                                padding: EdgeInsets.all(10),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: Color(0xFF9E9E9E),
                                  size: 16,
                                ),
                              ),
                            )
                          else
                            const SizedBox(width: 12),
                        ],
                      ),
                    ),
                    if (_showDropdown)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 320),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                          border: Border.all(
                            color: const Color(0xFFE0E0E0),
                            width: 1.5,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0A000000),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              height: 1,
                              color: const Color(0xFFE0E0E0),
                              margin: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            if (_searchResults.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  'No stalls found for "$_searchQuery"',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: const Color(0xFF9E9E9E),
                                  ),
                                ),
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                itemCount: _searchResults.length,
                                itemBuilder: (_, i) {
                                  final stall = _searchResults[i];
                                  final isOpen = StallUtils.isStallOpenNow(stall);
                                  final matchedProduct = _getMatchedProduct(stall);

                                  return GestureDetector(
                                    onTap: () => _onStallSelectedFromSearch(stall),
                                    child: Container(
                                      color: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE8F5E9),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: stall.photoUrls.isNotEmpty
                                                ? ClipRRect(
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: CachedNetworkImage(
                                                      imageUrl: stall.photoUrls.first,
                                                      fit: BoxFit.cover,
                                                      errorWidget: (_, __, ___) => const Icon(
                                                        Icons.store_rounded,
                                                        color: Color(0xFF4CAF50),
                                                        size: 20,
                                                      ),
                                                    ),
                                                  )
                                                : const Icon(
                                                    Icons.store_rounded,
                                                    color: Color(0xFF4CAF50),
                                                    size: 20,
                                                  ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                _buildHighlightedText(stall.name, _searchQuery),
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        StallUtils.getCategoryLabel(stall.category),
                                                        style: GoogleFonts.poppins(
                                                          fontSize: 11,
                                                          color: const Color(0xFF666666),
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      width: 3,
                                                      height: 3,
                                                      decoration: const BoxDecoration(
                                                        color: Color(0xFF9E9E9E),
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      isOpen ? 'Open' : 'Closed',
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 11,
                                                        color: isOpen
                                                            ? const Color(0xFF2E7D32)
                                                            : const Color(0xFFC62828),
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (matchedProduct != null)
                                                  Text(
                                                    'Sells: $matchedProduct',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 10,
                                                      color: const Color(0xFF1B5E20),
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                              ],
                                            ),
                                          ),
                                          if (stall.latitude != 0.0 || stall.longitude != 0.0)
                                            const Icon(
                                              Icons.location_on_rounded,
                                              size: 16,
                                              color: Color(0xFF9E9E9E),
                                            ),
                                        ],
                                      ),
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

              Expanded(
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    // Category chips
                    SliverToBoxAdapter(
                      child: Container(
                        height: 50,
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filterChipKeys.length,
                          itemBuilder: (context, index) {
                            final chipKey = filterChipKeys[index];
                            final typeData = _categoryMap[chipKey];
                            final isFavoritesChip = chipKey == 'favorites';
                            final chipLabel = isFavoritesChip
                                ? 'Favorites'
                                : (typeData?['label'] ?? chipKey) as String;
                            final chipIcon = isFavoritesChip
                                ? Icons.favorite_rounded
                                : (typeData?['icon'] ?? Icons.store_rounded) as IconData;
                            final isSelected = _selectedType == chipKey;
                            final hasSubcategories = !isFavoritesChip &&
                                ((typeData?['hasSubcategories'] ?? false) as bool);
                            final isSubcategoryOpen =
                                isSelected && hasSubcategories && _subcategoryRowVisible;

                            final selectedBgColor = isFavoritesChip
                                ? const Color(0xFFE53935)
                                : const Color(0xFF1B5E20);
                            final unselectedTextColor = isFavoritesChip
                                ? const Color(0xFFE53935)
                                : const Color(0xFF1B5E20);
                            final borderColor = isFavoritesChip
                                ? const Color(0xFFE53935)
                                : const Color(0xFF1B5E20);

                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedType = chipKey;
                                    _selectedSubLabel = null;
                                    _selectedTag = null;
                                    _subcategoryRowVisible = hasSubcategories;
                                  });
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? selectedBgColor
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: borderColor,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        chipIcon,
                                        size: 14,
                                        color: isSelected
                                            ? Colors.white
                                            : unselectedTextColor,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        chipLabel,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: isSelected
                                              ? Colors.white
                                              : unselectedTextColor,
                                        ),
                                      ),
                                      if (hasSubcategories) ...[
                                        const SizedBox(width: 4),
                                        AnimatedRotation(
                                          turns: isSubcategoryOpen ? 0.5 : 0,
                                          duration: const Duration(milliseconds: 250),
                                          child: Icon(
                                            Icons.keyboard_arrow_down,
                                            size: 14,
                                            color: isSelected
                                                ? Colors.white
                                                : unselectedTextColor,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // Subcategory chips row (Level 2)
                    SliverToBoxAdapter(
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        child: () {
                            final typeData = _categoryMap[_selectedType];
                          final hasSubcategories = (typeData?['hasSubcategories'] ?? false) as bool;
                          final subcategories = (typeData?['subcategories'] as List<Map>?) ?? [];
                          
                          return hasSubcategories && _selectedType != 'all' && _subcategoryRowVisible
                            ? Container(
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF8F9FA),
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Color(0xFFE0E0E0),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                child: SizedBox(
                                  height: 36,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    itemCount: subcategories.length,
                                    itemBuilder: (context, index) {
                                      final subcat = subcategories[index];
                                      final subcatLabel =
                                          subcat['label'] as String;
                                      final isSelected =
                                          _selectedSubLabel == subcatLabel ||
                                            (_selectedSubLabel == null &&
                                                  index == 0);

                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8),
                                        child: InkWell(
                                          onTap: () {
                                            if (index == 0) {
                                              setState(() {
                                                _selectedSubLabel = null;
                                                _selectedTag = null;
                                              });
                                            } else {
                                              _onSubcategorySelected(
                                                Map<String, dynamic>.from(subcat),
                                              );
                                            }
                                          },
                                          borderRadius:
                                              BorderRadius.circular(18),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? const Color(0xFF1B5E20)
                                                  : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              border: Border.all(
                                                color: const Color(0xFF1B5E20),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              subcatLabel,
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: isSelected
                                                    ? Colors.white
                                                    : const Color(0xFF1B5E20),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              )
                            : const SizedBox.shrink();
                        }(),
                      ),
                    ),

                    // Active filter chips
                    if (activeFilterCount > 0)
                      SliverToBoxAdapter(
                        child: Container(
                          height: 40,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              if (sortAlpha != null)
                                _buildActiveFilterChip(
                                  sortAlpha == 'az' ? 'A → Z' : 'Z → A',
                                  () => removeFilter('alpha'),
                                ),
                              if (filterOpenTime != null &&
                                  filterCloseTime != null)
                                _buildActiveFilterChip(
                                  '${formatTimeOfDay(filterOpenTime!)} - ${formatTimeOfDay(filterCloseTime!)}',
                                  () => removeFilter('time'),
                                ),
                              if (selectedDay != null)
                                _buildActiveFilterChip(
                                  '${showOpenOnDay ? "Open" : "Closed"} on $selectedDay',
                                  () => removeFilter('day'),
                                ),
                            ],
                          ),
                        ),
                      ),

                    // Recently Viewed
                    if (recentlyViewed.isNotEmpty && _searchQuery.isEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.history_rounded,
                                    size: 16,
                                    color: Color(0xFF9E9E9E),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Recently Viewed',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF424242),
                                    ),
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: _clearRecentlyViewed,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Clear',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: const Color(0xFF9E9E9E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 150,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: recentlyViewed.length,
                            itemBuilder: (context, index) {
                              return _buildRecentStallCard(
                                  recentlyViewed[index]);
                            },
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    ],

                    // Section header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_getDisplayNameForCount()} Stalls (${filteredStalls.length})',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF424242),
                              ),
                            ),
                            InkWell(
                              onTap: _showFilterBottomSheet,
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      activeFilterCount > 0
                                          ? Icons.filter_list_rounded
                                          : Icons.filter_list_outlined,
                                      size: 18,
                                      color: activeFilterCount > 0
                                          ? const Color(0xFF1B5E20)
                                          : const Color(0xFF757575),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      activeFilterCount > 0
                                          ? 'Filter ($activeFilterCount)'
                                          : 'Filter',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: activeFilterCount > 0
                                            ? const Color(0xFF1B5E20)
                                            : const Color(0xFF757575),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Stall list or empty state
                    if (filteredStalls.isEmpty)
                      SliverFillRemaining(
                        child: _buildEmptyState(),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              try {
                                final stall = filteredStalls[index];
                                return _buildStallCard(stall);
                              } catch (_) {
                                return const SizedBox.shrink();
                              }
                            },
                            childCount: filteredStalls.length,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF1B5E20),
          ),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 64,
                  color: Color(0xFFE53935),
                ),
                const SizedBox(height: 16),
                Text(
                  'Error Loading Stalls',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF212121),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFF757575),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
          } catch (e) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: Color(0xFFE53935),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Something went wrong',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedType = 'all';
                        _selectedSubLabel = null;
                        _selectedTag = null;
                        _subcategoryRowVisible = false;
                      });
                    },
                    child: Text(
                      'Reset filters',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF1B5E20),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildActiveFilterChip(String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        border: Border.all(color: const Color(0xFF1B5E20)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: const Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close_rounded,
              size: 12,
              color: Color(0xFF1B5E20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentStallCard(StallModel stall) {
    return GestureDetector(
      onTap: () => _openStallDetail(stall),
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFF0F0F0),
          ),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 64,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8E9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: stall.photoUrls.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: stall.photoUrls.first,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                        errorWidget: (context, url, error) => const Center(
                          child: Icon(
                            Icons.storefront_outlined,
                            size: 28,
                            color: Color(0xFF81C784),
                          ),
                        ),
                      ),
                    )
                  : const Center(
                      child: Icon(
                        Icons.storefront_outlined,
                        size: 28,
                        color: Color(0xFF81C784),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              stall.name,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF212121),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                StallUtils.getCategoryLabel(stall.category),
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  color: const Color(0xFF2E7D32),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStallCard(StallModel stall) {
    try {
      final name = stall.name.trim().isNotEmpty ? stall.name : 'Unknown Stall';
      final categoryValue = stall.category.trim();
      final category = categoryValue.isNotEmpty
          ? StallUtils.getCategoryLabel(categoryValue)
          : 'Uncategorized';
      final photoUrls = stall.photoUrls;
      final address = stall.address.trim().isNotEmpty ? stall.address : 'Location unavailable';

      return GestureDetector(
      onTap: () => _openStallDetail(stall),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFF0F0F0),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 80,
                height: 80,
                color: const Color(0xFFF1F8E9),
                child: photoUrls.isNotEmpty
                    ? CachedNetworkImage(
                    imageUrl: photoUrls.first,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.storefront_outlined,
                          size: 32,
                          color: Color(0xFF81C784),
                        ),
                      )
                    : const Icon(
                        Icons.storefront_outlined,
                        size: 32,
                        color: Color(0xFF81C784),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1B5E20),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Consumer(
                        builder: (context, ref, child) {
                          final favState = ref.watch(favoriteProvider);
                          final isFav = favState.isFavorite(stall.stallId);

                          return GestureDetector(
                            onTap: () async {
                              await ref
                                  .read(favoriteProvider.notifier)
                                  .toggleFavorite(stall.stallId);
                            },
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              transitionBuilder: (child, animation) {
                                return ScaleTransition(
                                  scale: Tween<double>(
                                    begin: 0.7,
                                    end: 1.0,
                                  ).animate(
                                    CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.elasticOut,
                                    ),
                                  ),
                                  child: child,
                                );
                              },
                              child: Icon(
                                isFav
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                key: ValueKey(isFav),
                                color: isFav
                                    ? const Color(0xFFE53935)
                                    : const Color(0xFFBDBDBD),
                                size: 22,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          category,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      StallUtils.buildStatusBadge(stall),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_outlined,
                        size: 12,
                        color: Color(0xFF9E9E9E),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final isOpen = StallUtils.isStallOpenNow(stall);
                            return Text(
                              '${stall.openTime} - ${stall.closeTime}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: isOpen
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFF9E9E9E),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 12,
                        color: Color(0xFF9E9E9E),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          address,
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
            ),
          ],
        ),
      ),
    );
    } catch (e) {
      debugPrint('❌ Card build error: $e');
      return const SizedBox.shrink();
    }
  }

  Widget _buildEmptyState() {
    final isFavoritesEmpty = _selectedType == 'favorites';
    final isSearchEmpty = _searchQuery.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFF5F5F5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFavoritesEmpty
                    ? Icons.favorite_border_rounded
                    : Icons.search_off_rounded,
                size: 56,
                color: const Color(0xFFBDBDBD),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isFavoritesEmpty
                  ? 'No favorites yet'
                  : isSearchEmpty
                      ? 'No stalls found'
                      : 'No stalls available',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF424242),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isFavoritesEmpty
                  ? 'Tap the heart icon on any stall to save it here'
                  : isSearchEmpty
                      ? 'Try searching with different keywords'
                      : 'No stalls available in this category',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF9E9E9E),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Filter Bottom Sheet Widget
class _FilterBottomSheet extends StatefulWidget {
  final String? currentSortAlpha;
  final TimeOfDay? currentFilterOpenTime;
  final TimeOfDay? currentFilterCloseTime;
  final String? currentSelectedDay;
  final bool currentShowOpenOnDay;
  final bool currentFilterOpenOnly;
  final Function(String?, TimeOfDay?, TimeOfDay?, String?, bool, bool) onApply;
  final VoidCallback onReset;
  final TimeOfDay Function(String) parseTime;

  const _FilterBottomSheet({
    required this.currentSortAlpha,
    required this.currentFilterOpenTime,
    required this.currentFilterCloseTime,
    required this.currentSelectedDay,
    required this.currentShowOpenOnDay,
    required this.currentFilterOpenOnly,
    required this.onApply,
    required this.onReset,
    required this.parseTime,
  });

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  String? _tempSortAlpha;
  TimeOfDay? _tempFilterOpenTime;
  TimeOfDay? _tempFilterCloseTime;
  String? _tempSelectedDay;
  bool _tempShowOpenOnDay = true;
  bool _tempFilterOpenOnly = false;

  final List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _tempSortAlpha = widget.currentSortAlpha;
    _tempFilterOpenTime = widget.currentFilterOpenTime;
    _tempFilterCloseTime = widget.currentFilterCloseTime;
    _tempSelectedDay = widget.currentSelectedDay;
    _tempShowOpenOnDay = widget.currentShowOpenOnDay;
    _tempFilterOpenOnly = widget.currentFilterOpenOnly;
  }

  Future<void> _pickTime(bool isOpenTime) async {
    final initialTime = isOpenTime
        ? (_tempFilterOpenTime ?? const TimeOfDay(hour: 6, minute: 0))
        : (_tempFilterCloseTime ?? const TimeOfDay(hour: 18, minute: 0));

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      initialEntryMode: TimePickerEntryMode.input,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: false,
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        if (isOpenTime) {
          _tempFilterOpenTime = picked;
        } else {
          _tempFilterCloseTime = picked;
        }
      });
    }
  }

  String formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  int getActiveFilterCount() {
    int count = 0;
    if (_tempSortAlpha != null) count++;
    if (_tempFilterOpenTime != null && _tempFilterCloseTime != null) count++;
    if (_tempSelectedDay != null) count++;
    if (_tempFilterOpenOnly) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.80,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sort & Filter',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF212121),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _tempSortAlpha = null;
                      _tempFilterOpenTime = null;
                      _tempFilterCloseTime = null;
                      _tempSelectedDay = null;
                      _tempShowOpenOnDay = true;
                      _tempFilterOpenOnly = false;
                    });
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Reset All',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF9E9E9E),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF0F0F0)),

          // SCROLLABLE CONTENT
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SECTION 1: Alphabetical
                  _buildSectionHeader('01  Alphabetical'),
                  Row(
                    children: [
                      Expanded(
                        child: _buildAlphaOption('A to Z', 'az', Icons.sort_by_alpha_rounded),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildAlphaOption('Z to A', 'za', Icons.sort_by_alpha_rounded),
                      ),
                    ],
                  ),

                  // SECTION 2: Time Range
                  _buildSectionHeader('02  Time Range'),
                  Text(
                    'Filter by Operating Hours',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Show stalls open during this time range',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF9E9E9E),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTimePicker(
                          'Opens From',
                          _tempFilterOpenTime,
                          Icons.wb_sunny_outlined,
                          () => _pickTime(true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTimePicker(
                          'Closes By',
                          _tempFilterCloseTime,
                          Icons.nights_stay_outlined,
                          () => _pickTime(false),
                        ),
                      ),
                    ],
                  ),
                  if (_tempFilterOpenTime != null && _tempFilterCloseTime != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: Color(0xFF2E7D32),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Showing stalls open: ${formatTimeOfDay(_tempFilterOpenTime!)} - ${formatTimeOfDay(_tempFilterCloseTime!)}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF2E7D32),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _tempFilterOpenTime = null;
                                _tempFilterCloseTime = null;
                              });
                            },
                            child: const Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: Color(0xFF9E9E9E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Quick Filter: Open Now Toggle
                  _buildSectionHeader('03  Quick Filter'),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Open Now Only',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF212121),
                      ),
                    ),
                    subtitle: Text(
                      'Show only currently open stalls',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF9E9E9E),
                      ),
                    ),
                    value: _tempFilterOpenOnly,
                    activeColor: const Color(0xFF1B5E20),
                    onChanged: (val) => setState(() => _tempFilterOpenOnly = val),
                  ),

                  // SECTION 4: Day & Status
                  _buildSectionHeader('04  Day & Status'),
                  Text(
                    'Filter by Day & Status',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Find stalls open or closed on a specific day',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF9E9E9E),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Select Day',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF9E9E9E),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: days.map((day) => _buildDayChip(day)).toList(),
                  ),
                  if (_tempSelectedDay != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Show stalls that are:',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF9E9E9E),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatusOption(
                            'Open on this day',
                            true,
                            Icons.check_circle_outline_rounded,
                            const Color(0xFF2E7D32),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatusOption(
                            'Closed on this day',
                            false,
                            Icons.cancel_outlined,
                            const Color(0xFFE53935),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // FIXED BOTTOM BUTTON - Always visible
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              border: Border(
                top: BorderSide(
                  color: Color(0xFFF0F0F0),
                  width: 1,
                ),
              ),
            ),
            child: Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x401B5E20),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  widget.onApply(
                    _tempSortAlpha,
                    _tempFilterOpenTime,
                    _tempFilterCloseTime,
                    _tempSelectedDay,
                    _tempShowOpenOnDay,
                    _tempFilterOpenOnly,
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  getActiveFilterCount() > 0
                      ? 'Apply Filters (${getActiveFilterCount()})'
                      : 'Apply Filters',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFF1B5E20),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF9E9E9E),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlphaOption(String label, String value, IconData icon) {
    final isSelected = _tempSortAlpha == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _tempSortAlpha = isSelected ? null : value;
        });
      },
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F5E9) : const Color(0xFFF5F5F5),
          border: Border.all(
            color: isSelected ? const Color(0xFF1B5E20) : const Color(0xFFE0E0E0),
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: isSelected ? const Color(0xFF1B5E20) : const Color(0xFF757575),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? const Color(0xFF1B5E20) : const Color(0xFF757575),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Positioned(
                top: 6,
                right: 6,
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: Color(0xFF1B5E20),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker(String label, TimeOfDay? time, IconData icon, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: const Color(0xFF9E9E9E),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: time != null ? const Color(0xFF1B5E20) : const Color(0xFFE0E0E0),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: const Color(0xFF1B5E20),
                ),
                const SizedBox(width: 6),
                Text(
                  time != null ? formatTimeOfDay(time) : '--:-- --',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF212121),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDayChip(String day) {
    final isSelected = _tempSelectedDay == day;

    return GestureDetector(
      onTap: () {
        setState(() {
          _tempSelectedDay = isSelected ? null : day;
        });
      },
      child: Container(
        width: 56,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1B5E20) : const Color(0xFFF5F5F5),
          border: isSelected ? null : Border.all(color: const Color(0xFFE0E0E0)),
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  const BoxShadow(
                    color: Color(0x301B5E20),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            day,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF757575),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusOption(String label, bool value, IconData icon, Color color) {
    final isSelected = _tempShowOpenOnDay == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _tempShowOpenOnDay = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? (value ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE))
              : const Color(0xFFF5F5F5),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE0E0E0),
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? color : const Color(0xFF757575),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? color : const Color(0xFF757575),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
