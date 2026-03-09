import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import 'auth_provider.dart';

// Stream provider for current user data from Firestore
final userDataStreamProvider = StreamProvider<UserModel?>((ref) {
  final user = ref.watch(currentUserProvider);
  
  if (user == null) {
    return Stream.value(null);
  }
  
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) {
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  });
});

// Provider for favorite count
final favoriteCountProvider = Provider<int>((ref) {
  final userData = ref.watch(userDataStreamProvider).value;
  return userData?.favoriteStalls.length ?? 0;
});
