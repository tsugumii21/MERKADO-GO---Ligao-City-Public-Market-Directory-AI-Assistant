import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import 'auth_provider.dart';

// Stream provider for current user data from Firestore
final userDataStreamProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(currentUserProvider);

  // Keep profile in loading state while auth is still resolving.
  if (authState.isLoading) {
    return const Stream<UserModel?>.empty();
  }

  final user = authState.asData?.value;

  // No authenticated user, so no profile document should be shown.
  if (user == null) {
    return Stream.value(null);
  }

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .asyncMap((doc) async {
        if (doc.exists) return UserModel.fromFirestore(doc);

        // Handle brief propagation delays after sign-in/token refresh.
        for (var attempt = 0; attempt < 3; attempt++) {
          await Future<void>.delayed(Duration(milliseconds: 250 * (attempt + 1)));
          final retryDoc = await doc.reference.get();
          if (retryDoc.exists) {
            return UserModel.fromFirestore(retryDoc);
          }
        }

        return null;
      })
      .handleError((e) {
        debugPrint('❌ Failed: User stream error: $e');
      });
});

// Provider for favorite count
final favoriteCountProvider = Provider<int>((ref) {
  final userData = ref.watch(userDataStreamProvider).value;
  return userData?.favoriteStalls.length ?? 0;
});
