import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/user_model.dart';
import '../../../core/exceptions/auth_exception.dart';

abstract class AuthRepository {
  Stream<User?> get authStateChanges;
  User? get currentUser;
  
  Future<UserCredential> signUp({
    required String username,
    required String fullName,
    required String address,
    required DateTime birthday,
    required String email,
    required String password,
  });
  
  Future<UserCredential> signIn({
    required String usernameOrEmail,
    required String password,
  });
  
  Future<void> signOut();
  Future<void> sendPasswordReset(String email);
  Future<void> sendVerificationEmail();
  Future<bool> checkEmailVerified();
  Future<UserModel?> getUserData(String uid);
  Future<void> updateUserProfile({
    required String uid,
    String? username,
    String? fullName,
    String? profilePhotoUrl,
  });
}

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  FirebaseAuthRepository(this._auth, this._firestore);

  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Future<UserCredential> signUp({
    required String username,
    required String fullName,
    required String address,
    required DateTime birthday,
    required String email,
    required String password,
  }) async {
    try {
      final usernameDoc = await _firestore
          .collection('usernames')
          .doc(username.toLowerCase())
          .get();

      if (usernameDoc.exists) {
        throw AuthException.fromFirebase('username-already-taken');
      }

      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user!;
      final now = DateTime.now();

      final userModel = UserModel(
        uid: user.uid,
        username: username,
        fullName: fullName,
        email: email,
        address: address,
        birthday: birthday,
        role: 'user',
        createdAt: now,
      );

      await _firestore.collection('users').doc(user.uid).set(userModel.toFirestore());

      await _firestore.collection('usernames').doc(username.toLowerCase()).set({
        'uid': user.uid,
        'createdAt': Timestamp.fromDate(now),
      });

      await user.sendEmailVerification();

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebase(e.code);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(
        code: 'unknown',
        message: 'An error occurred during sign up.',
        messageFil: 'May nangyaring error sa pag-sign up.',
      );
    }
  }

  @override
  Future<UserCredential> signIn({
    required String usernameOrEmail,
    required String password,
  }) async {
    try {
      String email = usernameOrEmail;

      if (!usernameOrEmail.contains('@')) {
        final usernameDoc = await _firestore
            .collection('usernames')
            .doc(usernameOrEmail.toLowerCase())
            .get();

        if (!usernameDoc.exists) {
          throw AuthException.fromFirebase('username-not-found');
        }

        final uid = usernameDoc.data()?['uid'] as String;
        final userDoc = await _firestore.collection('users').doc(uid).get();
        email = userDoc.data()?['email'] as String;
      }

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebase(e.code);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(
        code: 'unknown',
        message: 'An error occurred during sign in.',
        messageFil: 'May nangyaring error sa pag-sign in.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw AuthException(
        code: 'sign-out-failed',
        message: 'Failed to sign out.',
        messageFil: 'Hindi nag-sign out.',
      );
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebase(e.code);
    }
  }

  @override
  Future<void> sendVerificationEmail() async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
    } catch (e) {
      throw AuthException(
        code: 'verification-failed',
        message: 'Failed to send verification email.',
        messageFil: 'Hindi nag-send ng verification email.',
      );
    }
  }

  @override
  Future<bool> checkEmailVerified() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      await user.reload();
      return _auth.currentUser?.emailVerified ?? false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> updateUserProfile({
    required String uid,
    String? username,
    String? fullName,
    String? profilePhotoUrl,
  }) async {
    try {
      final updateData = <String, dynamic>{};

      // Get current user data
      final currentUserDoc = await _firestore.collection('users').doc(uid).get();
      if (!currentUserDoc.exists) {
        throw AuthException(
          code: 'user-not-found',
          message: 'User not found.',
          messageFil: 'Hindi nahanap ang user.',
        );
      }

      final currentUsername = currentUserDoc.data()?['username'] as String;

      // Handle username change
      if (username != null && username != currentUsername) {
        // Check if new username is already taken
        final usernameDoc = await _firestore
            .collection('usernames')
            .doc(username.toLowerCase())
            .get();

        if (usernameDoc.exists) {
          throw AuthException.fromFirebase('username-already-taken');
        }

        // Delete old username document
        await _firestore
            .collection('usernames')
            .doc(currentUsername.toLowerCase())
            .delete();

        // Create new username document
        await _firestore.collection('usernames').doc(username.toLowerCase()).set({
          'uid': uid,
          'createdAt': Timestamp.now(),
        });

        updateData['username'] = username;
      }

      // Handle full name update
      if (fullName != null) {
        updateData['fullName'] = fullName;
      }

      // Handle profile photo URL update
      if (profilePhotoUrl != null) {
        updateData['profilePhotoUrl'] = profilePhotoUrl;
      }

      // Update user document if there are changes
      if (updateData.isNotEmpty) {
        await _firestore.collection('users').doc(uid).update(updateData);
      }
    } on FirebaseException catch (e) {
      throw AuthException.fromFirebase(e.code);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(
        code: 'update-failed',
        message: 'Failed to update profile.',
        messageFil: 'Hindi nag-update ang profile.',
      );
    }
  }
}
