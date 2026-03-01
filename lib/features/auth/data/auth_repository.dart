// TODO: Implement Firebase Auth repository
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRepository(this._auth, this._firestore);

  // TODO: Implement auth methods
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  Future<void> signUp({
    required String username,
    required String email,
    required String password,
  }) async {
    // TODO: Implement signup with Firestore user creation
    throw UnimplementedError();
  }
  
  Future<void> signIn({
    required String usernameOrEmail,
    required String password,
  }) async {
    // TODO: Implement login (check if username or email)
    throw UnimplementedError();
  }
  
  Future<void> signOut() async {
    // TODO: Implement logout
    throw UnimplementedError();
  }
}
