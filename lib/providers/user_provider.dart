import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import 'auth_provider.dart';

// Stream provider for current user data from Firestore
final userDataStreamProvider = StreamProvider<UserModel?>((ref) {
  // Watch the auth state
  final authState = ref.watch(currentUserProvider);
  
  // Get the user from auth state
  final user = authState.when(
    data: (u) => u,
    loading: () => null,
    error: (_, __) => null,
  );
  
  // Return null stream if no user
  if (user == null) {
    return Stream.value(null);
  }
  
  // Return the Firestore stream
  // The token is already refreshed in currentUserProvider so this is safe
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) {
        if (!doc.exists) return null;
        return UserModel.fromFirestore(doc);
      })
      .handleError((e) {
        debugPrint('⚠️ User stream error: $e');
      });
});

// Provider for favorite count
final favoriteCountProvider = Provider<int>((ref) {
  final userData = ref.watch(userDataStreamProvider).value;
  return userData?.favoriteStalls.length ?? 0;
});
