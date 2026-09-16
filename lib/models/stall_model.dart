import 'package:cloud_firestore/cloud_firestore.dart';

class StallModel {
  final String stallId;
  final String? documentId;
  final String? physicalStallId;
  final bool? explicitHasMapLocation;
  final String name;
  final String category;
  final List<String> categories; // Multi-category support
  final List<String> products;
  final String address;
  final List<String> photoUrls;
  final String openTime;
  final String closeTime;
  final List<String> daysOpen;
  final double latitude;
  final double longitude;
  final bool isActive;
  final String status;
  final String? section;
  final String? stallNumber;
  final DateTime updatedAt;
  final List<String> tags;
  final List<String> subcategories;

  StallModel({
    required this.stallId,
    this.documentId,
    this.physicalStallId,
    this.explicitHasMapLocation,
    required this.name,
    required this.category,
    List<String>? categories,
    required this.products,
    required this.address,
    required this.photoUrls,
    required this.openTime,
    required this.closeTime,
    required this.daysOpen,
    required this.latitude,
    required this.longitude,
    required this.isActive,
    this.status = 'open',
    this.section,
    this.stallNumber,
    required this.updatedAt,
    this.tags = const [],
    List<String>? subcategories,
  })  : categories = categories ?? [category],
        subcategories = subcategories ?? const [];

  /// Returns the physical slot / stall ID for vector map rendering and hit-testing.
  /// Returns empty string if this stall has no physical slot on the map.
  String get mapStallId {
    if (explicitHasMapLocation == false) {
      return '';
    }
    if (physicalStallId != null && physicalStallId!.trim().isNotEmpty) {
      return physicalStallId!.trim();
    }
    if (stallId.startsWith('id_') || stallId.startsWith('slot_')) {
      return stallId;
    }
    return '';
  }

  /// Whether this stall is mapped to a physical location on the vector SVG map
  bool get hasMapLocation => explicitHasMapLocation ?? mapStallId.isNotEmpty;

  /// Resolves the primary stall photo URL from explicitly saved photoUrls.
  /// Returns empty string if no photos have been uploaded by admin.
  String get primaryPhotoUrl {
    if (photoUrls.isNotEmpty && photoUrls.first.trim().isNotEmpty) {
      return photoUrls.first.trim();
    }
    return '';
  }

  // Create StallModel from Firestore document
  factory StallModel.fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};

      final category = (data['category'] as String? ?? '').trim();
      final categories = data['categories'] is List
          ? (data['categories'] as List)
              .map((e) => (e ?? '').toString().trim())
              .where((e) => e.isNotEmpty)
              .toList()
          : (category.isNotEmpty ? <String>[category] : <String>[]);

      final explicitHasMapLocation = data['has_map_location'] as bool? ??
          data['hasMapLocation'] as bool?;

      final rawPhysicalSlot = (data['physical_stall_id'] as String? ??
              data['physicalStallId'] as String?)
          ?.trim();

      String? physicalSlot;
      if (explicitHasMapLocation == false) {
        physicalSlot = null;
      } else if (rawPhysicalSlot != null && rawPhysicalSlot.isNotEmpty) {
        physicalSlot = rawPhysicalSlot;
      } else {
        final legacySlot = (data['stall_id'] as String? ??
                data['stallId'] as String?)
            ?.trim();
        if (legacySlot != null &&
            (legacySlot.startsWith('id_') || legacySlot.startsWith('slot_'))) {
          physicalSlot = legacySlot;
        }
      }

      final resolvedStallId =
          (physicalSlot != null && physicalSlot.isNotEmpty)
              ? physicalSlot
              : doc.id;

      final products = data['products'] is List
          ? (data['products'] as List)
              .map((e) => (e ?? '').toString().trim())
              .where((e) => e.isNotEmpty)
              .toList()
          : <String>[];

      final productSetLower = products.map((p) => p.toLowerCase().trim()).toSet();

      final rawSubcategories = data['subcategories'] is List
          ? (data['subcategories'] as List)
              .map((e) => (e ?? '').toString().trim())
              .where((e) => e.isNotEmpty)
              .toList()
          : <String>[];

      final rawTags = data['tags'] is List
          ? (data['tags'] as List)
              .map((e) => (e ?? '').toString().trim())
              .where((e) => e.isNotEmpty)
              .toList()
          : <String>[];

      // Products are never subcategories - ensure complete separation
      final resolvedSubcategories = (rawSubcategories.isNotEmpty
              ? rawSubcategories
              : rawTags)
          .where((s) => !productSetLower.contains(s.toLowerCase().trim()))
          .toList();

      return StallModel(
        stallId: resolvedStallId,
        documentId: doc.id,
        physicalStallId: physicalSlot,
        explicitHasMapLocation: explicitHasMapLocation,
        name: (data['name'] as String? ?? '').trim(),
        category: category,
        categories: categories,
        products: products,
        address: (data['address'] as String? ?? '').trim(),
        photoUrls: data['photoUrls'] is List
            ? (data['photoUrls'] as List)
                .map((e) => (e ?? '').toString().trim())
                .where((e) => e.isNotEmpty)
                .toList()
            : (data['photo_urls'] is List
                ? (data['photo_urls'] as List)
                    .map((e) => (e ?? '').toString().trim())
                    .where((e) => e.isNotEmpty)
                    .toList()
                : <String>[]),
        openTime: (data['openTime'] as String? ??
                data['open_time'] as String? ??
                data['opening_time'] as String? ??
                '5:00 AM')
            .trim(),
        closeTime: (data['closeTime'] as String? ??
                data['close_time'] as String? ??
                data['closing_time'] as String? ??
                '6:00 PM')
            .trim(),
        daysOpen: data['daysOpen'] is List
            ? (data['daysOpen'] as List)
                .map((e) => (e ?? '').toString().trim())
                .where((e) => e.isNotEmpty)
                .toList()
            : (data['days_open'] is List
                ? (data['days_open'] as List)
                    .map((e) => (e ?? '').toString().trim())
                    .where((e) => e.isNotEmpty)
                    .toList()
                : <String>[]),
        latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
        isActive: data['isActive'] as bool? ??
            data['isOpen'] as bool? ??
            ((data['status'] as String?) == 'open'),
        status: data['status'] as String? ??
            ((data['isOpen'] == true || data['isActive'] == true)
                ? 'open'
                : 'closed'),
        section: (data['section'] as String? ??
                data['building_or_section'] as String?)
            ?.trim(),
        stallNumber: (data['stallNumber'] as String? ??
                data['stall_number'] as String?)
            ?.trim(),
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        tags: rawTags,
        subcategories: resolvedSubcategories,
      );
    } catch (e) {
      return StallModel(
        stallId: doc.id,
        name: 'Error loading stall',
        category: '',
        categories: const <String>[],
        products: const <String>[],
        address: '',
        photoUrls: const <String>[],
        openTime: '5:00 AM',
        closeTime: '6:00 PM',
        daysOpen: const <String>[],
        latitude: 0.0,
        longitude: 0.0,
        isActive: false,
        status: 'closed',
        section: '',
        stallNumber: '',
        updatedAt: DateTime.now(),
        tags: const <String>[],
        subcategories: const <String>[],
      );
    }
  }

  // Convert StallModel to Firestore document
  Map<String, dynamic> toFirestore() {
    final hasLoc = physicalStallId != null && physicalStallId!.trim().isNotEmpty;
    final physicalKey = hasLoc ? physicalStallId!.trim() : null;
    return {
      'id': stallId,
      'stallId': stallId,
      'stall_id': stallId,
      if (hasLoc) ...{
        'physical_stall_id': physicalKey,
        'physicalStallId': physicalKey,
        'has_map_location': true,
      } else ...{
        'has_map_location': false,
      },
      'name': name,
      'category': category,
      'categories': categories, // Multi-category array
      'products': products,
      'address': address,
      'photoUrls': photoUrls,
      'photo_urls': photoUrls,
      'openTime': openTime,
      'open_time': openTime,
      'closeTime': closeTime,
      'close_time': closeTime,
      'daysOpen': daysOpen,
      'days_open': daysOpen,
      'latitude': latitude,
      'longitude': longitude,
      'isActive': isActive,
      'isOpen': status == 'open',
      'status': status,
      'section': section ?? '',
      'building_or_section': section ?? '',
      'stallNumber': stallNumber ?? '',
      'stall_number': stallNumber ?? '',
      'updatedAt': Timestamp.fromDate(updatedAt),
      'tags': tags,
      'subcategories': subcategories,
    };
  }

  // Create a copy with updated fields
  StallModel copyWith({
    String? stallId,
    String? name,
    String? category,
    List<String>? categories,
    List<String>? products,
    String? address,
    List<String>? photoUrls,
    String? openTime,
    String? closeTime,
    List<String>? daysOpen,
    String? documentId,
    String? physicalStallId,
    bool clearPhysicalStallId = false,
    bool? explicitHasMapLocation,
    double? latitude,
    double? longitude,
    bool? isActive,
    String? status,
    String? section,
    String? stallNumber,
    DateTime? updatedAt,
    List<String>? tags,
    List<String>? subcategories,
  }) {
    return StallModel(
      stallId: stallId ?? this.stallId,
      documentId: documentId ?? this.documentId,
      physicalStallId: clearPhysicalStallId
          ? null
          : (physicalStallId ?? this.physicalStallId),
      explicitHasMapLocation: clearPhysicalStallId
          ? false
          : (explicitHasMapLocation ?? this.explicitHasMapLocation),
      name: name ?? this.name,
      category: category ?? this.category,
      categories: categories ?? this.categories,
      products: products ?? this.products,
      address: address ?? this.address,
      photoUrls: photoUrls ?? this.photoUrls,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
      daysOpen: daysOpen ?? this.daysOpen,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
      section: section ?? this.section,
      stallNumber: stallNumber ?? this.stallNumber,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
      subcategories: subcategories ?? this.subcategories,
    );
  }

  @override
  String toString() {
    return 'StallModel(stallId: $stallId, name: $name, category: $category, products: $products)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is StallModel &&
        other.stallId == stallId &&
        other.documentId == documentId &&
        other.physicalStallId == physicalStallId &&
        other.explicitHasMapLocation == explicitHasMapLocation &&
        other.name == name &&
        other.category == category &&
        other.isActive == isActive;
  }

  @override
  int get hashCode {
    return stallId.hashCode ^
        documentId.hashCode ^
        physicalStallId.hashCode ^
        explicitHasMapLocation.hashCode ^
        name.hashCode ^
        category.hashCode ^
        isActive.hashCode;
  }
}
