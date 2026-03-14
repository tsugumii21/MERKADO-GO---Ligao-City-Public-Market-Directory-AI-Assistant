// Planned: Implement Stall Repository
import 'package:cloud_firestore/cloud_firestore.dart';

class StallRepository {
  final FirebaseFirestore _firestore;

  StallRepository(this._firestore);

  // Planned: Implement stall CRUD methods
  Stream<List<Map<String, dynamic>>> getStalls() {
    // Planned: Get all stalls from Firestore
    throw UnimplementedError();
  }
  
  Future<void> addStall(Map<String, dynamic> stallData) async {
    // Planned: Add new stall
    throw UnimplementedError();
  }
}
