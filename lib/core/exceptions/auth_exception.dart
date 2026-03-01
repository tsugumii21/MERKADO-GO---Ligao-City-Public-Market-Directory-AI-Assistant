class AuthException implements Exception {
  final String code;
  final String message;
  final String messageFil;

  AuthException({
    required this.code,
    required this.message,
    required this.messageFil,
  });

  factory AuthException.fromFirebase(String code) {
    switch (code) {
      case 'user-not-found':
        return AuthException(
          code: code,
          message: 'No user found with this email or username.',
          messageFil: 'Walang user na nahanap sa email o username na ito.',
        );
      case 'wrong-password':
        return AuthException(
          code: code,
          message: 'Incorrect password. Please try again.',
          messageFil: 'Maling password. Subukan ulit.',
        );
      case 'email-already-in-use':
        return AuthException(
          code: code,
          message: 'This email is already registered.',
          messageFil: 'Ang email na ito ay naka-rehistro na.',
        );
      case 'invalid-email':
        return AuthException(
          code: code,
          message: 'Invalid email format.',
          messageFil: 'Hindi wastong format ng email.',
        );
      case 'weak-password':
        return AuthException(
          code: code,
          message: 'Password is too weak. Use at least 6 characters.',
          messageFil: 'Ang password ay mahina. Gumamit ng hindi bababa sa 6 na character.',
        );
      case 'username-already-taken':
        return AuthException(
          code: code,
          message: 'This username is already taken.',
          messageFil: 'Ang username na ito ay ginagamit na.',
        );
      case 'username-not-found':
        return AuthException(
          code: code,
          message: 'Username not found.',
          messageFil: 'Hindi nahanap ang username.',
        );
      case 'email-not-verified':
        return AuthException(
          code: code,
          message: 'Please verify your email before logging in.',
          messageFil: 'Mangyaring i-verify ang iyong email bago mag-login.',
        );
      case 'too-many-requests':
        return AuthException(
          code: code,
          message: 'Too many attempts. Please try again later.',
          messageFil: 'Masyadong maraming pagsubok. Subukan mamaya.',
        );
      case 'network-request-failed':
        return AuthException(
          code: code,
          message: 'Network error. Please check your internet connection.',
          messageFil: 'May problema sa network. Pakisuri ang iyong koneksyon sa internet.',
        );
      default:
        return AuthException(
          code: code,
          message: 'An error occurred. Please try again.',
          messageFil: 'May nangyaring error. Subukan ulit.',
        );
    }
  }

  @override
  String toString() => message;
}
