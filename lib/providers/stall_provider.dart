// TODO: Implement Stall Provider (Riverpod)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Stalls stream provider
final stallsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('stalls')
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
});

// Stalls by category provider
final stallsByCategoryProvider = Provider.family<List<Map<String, dynamic>>, String>((ref, category) {
  final stalls = ref.watch(stallsProvider).value ?? [];
  return stalls.where((stall) => stall['category'] == category).toList();
});

// Favorite stalls provider
// TODO: Implement favorite stalls provider
