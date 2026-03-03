import 'package:cloud_firestore/cloud_firestore.dart';
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
}

class FirestoreStallRepository implements StallRepository {
  final FirebaseFirestore _firestore;
  static const String _collection = 'stalls';

  FirestoreStallRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<StallModel>> getAllStalls() {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => StallModel.fromFirestore(doc)).toList());
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
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => StallModel.fromFirestore(doc))
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
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => StallModel.fromFirestore(doc))
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
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => StallModel.fromFirestore(doc)).toList());
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
