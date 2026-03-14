// Planned: Implement Auth Controller (Riverpod)
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController() : super(const AsyncValue.data(null));

  // Planned: Implement auth methods
  Future<void> signIn(String usernameOrEmail, String password) async {
    // Planned
  }
  
  Future<void> signUp(String username, String email, String password) async {
    // Planned
  }
  
  Future<void> signOut() async {
    // Planned
  }
}
