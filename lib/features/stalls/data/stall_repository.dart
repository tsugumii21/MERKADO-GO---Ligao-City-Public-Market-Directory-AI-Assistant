import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/stall_model.dart';

abstract class StallRepository {
  Stream<List<StallModel>> getAllStalls();
  Future<StallModel?> getStallById(String stallId);
  Stream<List<StallModel>> searchStallsByName(String query);
  Stream<List<StallModel>> searchStallsByProduct(String ingredient);
  Stream<List<StallModel>> getStallsByCategory(String category);
  Future<void> addStall(StallModel stall);
  Future<void> updateStall(String stallId, Map<String, dynamic> updates);
  Future<void> deleteStall(String stallId);
  Future<List<StallModel>> getOfflineCachedStalls();
}

class FirestoreStallRepository implements StallRepository {
  final FirebaseFirestore _firestore;
  static const String _collection = 'stalls';
  static const String _offlineCacheKey = 'offline_cached_stalls';

  FirestoreStallRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> _saveOfflineCache(List<StallModel> stalls) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = stalls.map((s) {
        final map = s.toFirestore();
        map['stallId'] = s.stallId;
        return jsonEncode(map);
      }).toList();
      await prefs.setStringList(_offlineCacheKey, list);
    } catch (_) {}
  }

  @override
  Future<List<StallModel>> getOfflineCachedStalls() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_offlineCacheKey);
      if (rawList != null && rawList.isNotEmpty) {
        return rawList
            .map((str) {
              try {
                final map = jsonDecode(str) as Map<String, dynamic>;
                return StallModel(
                  stallId: map['stallId'] as String? ?? map['id'] as String? ?? '',
                  name: map['name'] as String? ?? '',
                  category: map['category'] as String? ?? '',
                  categories: List<String>.from(map['categories'] as List? ?? []),
                  products: List<String>.from(map['products'] as List? ?? []),
                  address: map['address'] as String? ?? '',
                  photoUrls: List<String>.from(map['photoUrls'] as List? ?? []),
                  openTime: map['openTime'] as String? ?? '5:00 AM',
                  closeTime: map['closeTime'] as String? ?? '6:00 PM',
                  daysOpen: List<String>.from(map['daysOpen'] as List? ?? []),
                  latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
                  longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
                  isActive: map['isActive'] as bool? ?? true,
                  status: map['status'] as String? ?? 'open',
                  section: map['section'] as String?,
                  stallNumber: map['stallNumber'] as String?,
                  updatedAt: DateTime.now(),
                  tags: List<String>.from(map['tags'] as List? ?? []),
                );
              } catch (_) {
                return null;
              }
            })
            .whereType<StallModel>()
            .toList();
      }
    } catch (_) {}
    return [];
  }

  @override
  Stream<List<StallModel>> getAllStalls() {
    return _firestore
        .collection(_collection)
        .orderBy('name')
        .snapshots()
        .handleError((error) {
          debugPrint('❌ Error: Stalls query failed: $error');
        })
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) {
                try {
                  return StallModel.fromFirestore(doc);
                } catch (_) {
                  return null;
                }
              })
              .whereType<StallModel>()
              .where((stall) => stall.isActive != false)
              .toList();
          _saveOfflineCache(list);
          return list;
        });
  }

  @override
  Future<StallModel?> getStallById(String stallId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(stallId).get();
      if (doc.exists) {
        return StallModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Error fetching stall: $e');
    }
  }

  @override
  Stream<List<StallModel>> searchStallsByName(String query) {
    if (query.isEmpty) {
      return getAllStalls();
    }

    final queryLower = query.toLowerCase();
    
    return _firestore
        .collection(_collection)
        .orderBy('name')
        .snapshots()
        .handleError((error) {
          debugPrint('❌ Error: Search by name failed: $error');
        })
        .map((snapshot) {
      return snapshot.docs
          .map((doc) {
            try {
              return StallModel.fromFirestore(doc);
            } catch (_) {
              return null;
            }
          })
          .whereType<StallModel>()
          .where((stall) => stall.isActive != false)
          .where((stall) => stall.name.toLowerCase().contains(queryLower))
          .toList();
    });
  }

  @override
  Stream<List<StallModel>> searchStallsByProduct(String ingredient) {
    if (ingredient.isEmpty) {
      return getAllStalls();
    }

    final ingredientLower = ingredient.toLowerCase();
    
    return _firestore
        .collection(_collection)
        .orderBy('name')
        .snapshots()
        .handleError((error) {
          debugPrint('❌ Error: Search by product failed: $error');
        })
        .map((snapshot) {
      return snapshot.docs
          .map((doc) {
            try {
              return StallModel.fromFirestore(doc);
            } catch (_) {
              return null;
            }
          })
          .whereType<StallModel>()
          .where((stall) => stall.isActive != false)
          .where((stall) => stall.products.any(
              (product) => product.toLowerCase().contains(ingredientLower)))
          .toList();
    });
  }

  @override
  Stream<List<StallModel>> getStallsByCategory(String category) {
    return _firestore
        .collection(_collection)
        .where('category', isEqualTo: category)
        .snapshots()
        .handleError((error) {
          debugPrint('❌ Error: Category query failed: $error');
        })
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                try {
                  return StallModel.fromFirestore(doc);
                } catch (_) {
                  return null;
                }
              })
              .whereType<StallModel>()
              .where((stall) => stall.isActive != false)
              .toList();
        });
  }

  @override
  Future<void> addStall(StallModel stall) async {
    try {
      await _firestore.collection(_collection).add(stall.toFirestore());
    } catch (e) {
      throw Exception('Error adding stall: $e');
    }
  }

  @override
  Future<void> updateStall(String stallId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = Timestamp.now();
      await _firestore.collection(_collection).doc(stallId).update(updates);
    } catch (e) {
      throw Exception('Error updating stall: $e');
    }
  }

  @override
  Future<void> deleteStall(String stallId) async {
    try {
      // Soft delete by setting isActive to false
      await _firestore.collection(_collection).doc(stallId).update({
        'isActive': false,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Error deleting stall: $e');
    }
  }
}
