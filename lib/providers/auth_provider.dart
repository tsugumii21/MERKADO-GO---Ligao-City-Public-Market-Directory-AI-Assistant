import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/data/auth_repository.dart';
import '../models/user_model.dart';
import 'firebase_providers.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final firestore = ref.watch(firestoreProvider);
  return FirebaseAuthRepository(auth, firestore);
});

final authStateProvider = StreamProvider<User?>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.authStateChanges;
});

// StreamProvider that ensures user has valid token before being returned
final currentUserProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance
      .authStateChanges()
      .asyncMap((user) async {
        if (user == null) return null;
        // Force token refresh to ensure Firestore recognizes auth state
        try {
          await user.getIdToken(true);
          return user;
        } catch (e) {
          debugPrint('⚠️ Token refresh failed: $e');
          return null;
        }
      });
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    data: (user) => user != null,
    loading: () => false,
    error: (_, __) => false,
  );
});

final isEmailVerifiedProvider = Provider<bool>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    data: (user) => user?.emailVerified ?? false,
    loading: () => false,
    error: (_, __) => false,
  );
});

final currentUserDataProvider = FutureProvider<UserModel?>((ref) async {
  final userAsync = ref.watch(currentUserProvider);
  final user = userAsync.when(
    data: (u) => u,
    loading: () => null,
    error: (_, __) => null,
  );
  if (user == null) return null;
  
  final authRepo = ref.watch(authRepositoryProvider);
  return await authRepo.getUserData(user.uid);
});

final userRoleProvider = FutureProvider<String?>((ref) async {
  final userData = await ref.watch(currentUserDataProvider.future);
  return userData?.role;
});
