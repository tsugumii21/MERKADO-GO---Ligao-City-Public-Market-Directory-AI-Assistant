import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shared_preferences/shared_preferences.dart';

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
  static const String _localPrefsKey = 'guest_favorite_stalls';
  
  String? get _uid => _auth.currentUser?.uid;
  
  Future<void> loadFavorites() async {
    state = state.copyWith(isLoading: true);

    if (_uid == null) {
      // Load guest favorites from SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        final localFavs = prefs.getStringList(_localPrefsKey) ?? [];
        state = state.copyWith(
          favoriteIds: localFavs,
          isLoading: false,
        );
      } catch (e) {
        state = const FavoriteState();
      }
      return;
    }

    try {
      final doc = await _db
          .collection('users')
          .doc(_uid)
          .get();
      
      if (!doc.exists) {
        state = state.copyWith(
          favoriteIds: [],
          isLoading: false,
        );
        return;
      }
      
      final data = doc.data() ?? {};
      
      if (!data.containsKey('favoriteStalls')) {
        state = state.copyWith(
          favoriteIds: [],
          isLoading: false,
        );
        return;
      }
      
      final favField = data['favoriteStalls'];
      final favs = List<String>.from(favField ?? []);

      state = state.copyWith(
        favoriteIds: favs,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('❌ Error: Failed to load favorites: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
  
  Future<void> toggleFavorite(String stallId) async {
    if (stallId.isEmpty) return;

    final isFav = state.isFavorite(stallId);

    // Optimistic UI update
    final updatedList = isFav
        ? state.favoriteIds.where((id) => id != stallId).toList()
        : [...state.favoriteIds, stallId];

    state = state.copyWith(favoriteIds: updatedList);

    // If guest user, persist to SharedPreferences
    if (_uid == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(_localPrefsKey, updatedList);
      } catch (e) {
        debugPrint('❌ Error: Failed to save guest favorites: $e');
      }
      return;
    }
    
    try {
      // Use set with merge:true to handle missing field in Firestore
      await _db
          .collection('users')
          .doc(_uid)
          .set({
        'favoriteStalls': isFav
            ? FieldValue.arrayRemove([stallId])
            : FieldValue.arrayUnion([stallId]),
      }, SetOptions(merge: true));

    } catch (e) {
      debugPrint('❌ Error: Failed to update favorites: $e');
      
      // Revert optimistic update on failure
      final revertedList = isFav
          ? [...state.favoriteIds, stallId]
          : state.favoriteIds.where((id) => id != stallId).toList();
      
      state = state.copyWith(
        favoriteIds: revertedList,
        error: e.toString(),
      );
    }
  }
  
  void clearFavorites() {
    state = const FavoriteState();
  }
}

final favoriteProvider = StateNotifierProvider<FavoriteNotifier, FavoriteState>((ref) {
  final notifier = FavoriteNotifier();
  notifier.loadFavorites();
  return notifier;
});
