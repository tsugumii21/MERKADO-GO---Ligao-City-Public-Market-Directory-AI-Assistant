import 'package:cloud_firestore/cloud_firestore.dart';

class StallModel {
  final String stallId;
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
  final DateTime updatedAt;
  final List<String> tags;

  StallModel({
    required this.stallId,
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
    required this.updatedAt,
    this.tags = const [],
  }) : categories = categories ?? [category];

  // Create StallModel from Firestore document
  factory StallModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Backward compatibility: if no categories array, use single category field
    final categoriesList = data['categories'] != null
        ? List<String>.from(data['categories'] as List)
        : [data['category'] as String? ?? ''];
    
    return StallModel(
      stallId: doc.id,
      name: data['name'] as String? ?? '',
      category: data['category'] as String? ?? '',
      categories: categoriesList,
      products: List<String>.from(data['products'] as List<dynamic>? ?? []),
      address: data['address'] as String? ?? '',
      photoUrls: List<String>.from(data['photoUrls'] as List<dynamic>? ?? []),
      openTime: data['openTime'] as String? ?? '6:00 AM',
      closeTime: data['closeTime'] as String? ?? '6:00 PM',
      daysOpen: List<String>.from(data['daysOpen'] as List<dynamic>? ?? []),
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      isActive: data['isActive'] as bool? ?? true,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      tags: data['tags'] != null 
          ? List<String>.from(data['tags'] as List) 
          : const [],
    );
  }

  // Convert StallModel to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'category': category,
      'categories': categories, // Multi-category array
      'products': products,
      'address': address,
      'photoUrls': photoUrls,
      'openTime': openTime,
      'closeTime': closeTime,
      'daysOpen': daysOpen,
      'latitude': latitude,
      'longitude': longitude,
      'isActive': isActive,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'tags': tags,
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
    double? latitude,
    double? longitude,
    bool? isActive,
    DateTime? updatedAt,
    List<String>? tags,
  }) {
    return StallModel(
      stallId: stallId ?? this.stallId,
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
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
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
      other.name == name &&
      other.category == category;
  }

  @override
  int get hashCode {
    return stallId.hashCode ^
      name.hashCode ^
      category.hashCode;
  }
}
