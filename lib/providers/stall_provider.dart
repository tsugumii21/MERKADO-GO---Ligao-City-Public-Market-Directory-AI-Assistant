import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/stalls/data/stall_repository.dart';
import '../models/stall_model.dart';
import 'firebase_providers.dart';

// Stall Repository Provider
final stallRepositoryProvider = Provider<StallRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return FirestoreStallRepository(firestore: firestore);
});

// All Stalls Stream Provider
final allStallsProvider = StreamProvider<List<StallModel>>((ref) {
  final repository = ref.watch(stallRepositoryProvider);
  return repository.getAllStalls();
});

// Stalls by Category Stream Provider
final stallsByCategoryProvider =
    StreamProvider.family<List<StallModel>, String>((ref, category) {
  final repository = ref.watch(stallRepositoryProvider);
  return repository.getStallsByCategory(category);
});

// Search Stalls by Name Stream Provider
final searchStallsByNameProvider =
    StreamProvider.family<List<StallModel>, String>((ref, query) {
  final repository = ref.watch(stallRepositoryProvider);
  return repository.searchStallsByName(query);
});

// Search Stalls by Product Stream Provider
final searchStallsByProductProvider =
    StreamProvider.family<List<StallModel>, String>((ref, ingredient) {
  final repository = ref.watch(stallRepositoryProvider);
  return repository.searchStallsByProduct(ingredient);
});

// Get Stall by ID Future Provider
final stallByIdProvider =
    FutureProvider.family<StallModel?, String>((ref, stallId) async {
  final repository = ref.watch(stallRepositoryProvider);
  return repository.getStallById(stallId);
});
