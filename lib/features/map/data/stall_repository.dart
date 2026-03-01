// TODO: Implement Stall Repository
import 'package:cloud_firestore/cloud_firestore.dart';

class StallRepository {
  final FirebaseFirestore _firestore;

  StallRepository(this._firestore);

  // TODO: Implement stall CRUD methods
  Stream<List<Map<String, dynamic>>> getStalls() {
    // TODO: Get all stalls from Firestore
    throw UnimplementedError();
  }
  
  Future<void> addStall(Map<String, dynamic> stallData) async {
    // TODO: Add new stall
    throw UnimplementedError();
  }
}
