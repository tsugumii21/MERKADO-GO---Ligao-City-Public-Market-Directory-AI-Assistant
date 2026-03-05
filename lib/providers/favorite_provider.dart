import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FavoriteState {
  final List<String> favoriteIds;
  final bool isLoading;
  final String? error;
  
  const FavoriteState({
    this.favoriteIds = const [],
    this.isLoading = false,
    this.error,
  });
  
  FavoriteState copyWith({
    List<String>? favoriteIds,
    bool? isLoading,
    String? error,
  }) {
    return FavoriteState(
      favoriteIds: favoriteIds ?? this.favoriteIds,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
  
  bool isFavorite(String stallId) => favoriteIds.contains(stallId);
}

class FavoriteNotifier extends StateNotifier<FavoriteState> {
  FavoriteNotifier() : super(const FavoriteState());
  
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  
  String? get _uid => _auth.currentUser?.uid;
  
  Future<void> loadFavorites() async {
    print('=== LOAD FAVORITES CALLED ===');
    
    if (_uid == null) {
      print('❌ ERROR: uid is null — user not logged in');
      state = const FavoriteState();
      return;
    }
    
    print('✅ Current UID: $_uid');
    state = state.copyWith(isLoading: true);
    
    try {
      print('📥 Fetching user document from Firestore...');
      final doc = await _db
          .collection('users')
          .doc(_uid)
          .get();
      
      if (!doc.exists) {
        print('⚠️  User document does not exist');
        state = state.copyWith(
          favoriteIds: [],
          isLoading: false,
        );
        return;
      }
      
      final data = doc.data() ?? {};
      print('📄 User document data keys: ${data.keys.toList()}');
      
      if (!data.containsKey('favoriteStalls')) {
        print('⚠️  favoriteStalls field does not exist in user document');
        print('   This is normal for new users. Field will be created on first favorite.');
        state = state.copyWith(
          favoriteIds: [],
          isLoading: false,
        );
        return;
      }
      
      final favField = data['favoriteStalls'];
      print('📋 favoriteStalls field type: ${favField.runtimeType}');
      print('📋 favoriteStalls raw value: $favField');
      
      final favs = List<String>.from(favField ?? []);
      
      print('✅ Favorites loaded successfully: $favs');
      print('✅ Total favorites count: ${favs.length}');
      
      state = state.copyWith(
        favoriteIds: favs,
        isLoading: false,
      );
    } catch (e, stackTrace) {
      print('❌ ERROR loading favorites: $e');
      print('❌ Error type: ${e.runtimeType}');
      print('❌ Stack trace: $stackTrace');
      
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
  
  Future<void> toggleFavorite(String stallId) async {
    print('\n=== TOGGLE FAVORITE CALLED ===');
    print('📍 StallId: "$stallId"');
    
    // Validate stallId
    if (stallId.isEmpty) {
      print('❌ ERROR: stallId is EMPTY');
      return;
    }
    
    // Validate user is logged in
    if (_uid == null) {
      print('❌ ERROR: uid is null — user not logged in');
      return;
    }
    
    print('✅ Current UID: $_uid');
    
    final isFav = state.isFavorite(stallId);
    print('📊 Is currently favorite: $isFav');
    print('📊 Current favorites list: ${state.favoriteIds}');
    
    // Optimistic UI update
    final updatedList = isFav
        ? state.favoriteIds.where((id) => id != stallId).toList()
        : [...state.favoriteIds, stallId];
    
    print('🔄 Optimistic update - new list: $updatedList');
    state = state.copyWith(favoriteIds: updatedList);
    
    try {
      print('📝 Writing to Firestore...');
      print('   Collection: users');
      print('   Document: $_uid');
      print('   Field: favoriteStalls');
      print('   Operation: ${isFav ? 'arrayRemove' : 'arrayUnion'}');
      print('   Value: [$stallId]');
      
      // Use set with merge:true to handle missing field
      await _db
          .collection('users')
          .doc(_uid)
          .set({
        'favoriteStalls': isFav
            ? FieldValue.arrayRemove([stallId])
            : FieldValue.arrayUnion([stallId]),
      }, SetOptions(merge: true));
      
      print('✅ Firestore write SUCCESS!');
      print('✅ Favorite ${isFav ? 'removed' : 'added'}: $stallId');
      print('✅ Updated favorites: ${state.favoriteIds}');
      
      // Verify write by reading back
      final doc = await _db.collection('users').doc(_uid).get();
      final verifyFavs = List<String>.from(doc.data()?['favoriteStalls'] ?? []);
      print('✅ Verification read from Firestore: $verifyFavs');
      
    } catch (e, stackTrace) {
      print('❌ ERROR writing to Firestore: $e');
      print('❌ Error type: ${e.runtimeType}');
      print('❌ Stack trace: $stackTrace');
      
      // Revert optimistic update on failure
      final revertedList = isFav
          ? [...state.favoriteIds, stallId]
          : state.favoriteIds.where((id) => id != stallId).toList();
      
      print('🔙 Reverting optimistic update to: $revertedList');
      
      state = state.copyWith(
        favoriteIds: state.favoriteIds,
        error: e.toString(),
      );
    }
    
    print('=== TOGGLE FAVORITE COMPLETE ===\n');
  }
  
  void clearFavorites() {
    print('🗑️  Clearing all favorites (user logged out)');
    state = const FavoriteState();
  }
}

final favoriteProvider = StateNotifierProvider<FavoriteNotifier, FavoriteState>((ref) {
  print('🏗️  Creating FavoriteNotifier instance');
  final notifier = FavoriteNotifier();
  notifier.loadFavorites();
  return notifier;
});
