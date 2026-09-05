import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/router/route_names.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/favorite_provider.dart';
import 'widgets/auth_loading_dialog.dart';

/// Alias for SignInScreen to maintain naming compatibility
typedef SignInScreen = LoginScreen;

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<String?> _getEmailFromUsername(String input) async {
    final trimmed = input.trim();
    if (trimmed.contains('@')) {
      return trimmed;
    }

    final username = trimmed.toLowerCase();
    try {
      final usernameDoc = await FirebaseFirestore.instance
          .collection('usernames')
          .doc(username)
          .get(const GetOptions(source: Source.server));

      if (!usernameDoc.exists) {
        return null;
      }

      final uid = usernameDoc.data()?['uid'] as String?;
      if (uid == null || uid.isEmpty) {
        return null;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server));

      return userDoc.data()?['email'] as String?;
    } catch (e) {
      debugPrint('❌ Error: Username lookup failed: $e');
      return null;
    }
  }

  Future<void> _handleLogin() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = await _getEmailFromUsername(_emailController.text.trim());

      if (email == null) {
        if (mounted) {
          setState(() {
            _errorMessage = _emailController.text.trim().contains('@')
                ? 'Email not found. Please check your email and try again.'
                : 'Username not found. Please check and try again.';
            _isLoading = false;
          });
        }
        return;
      }

      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: _passwordController.text,
      );

      final user = userCredential.user;

      if (user != null && !user.emailVerified) {
        if (mounted) context.go(RouteNames.verifyEmail);
        return;
      }

      if (user != null) {
        await Future.delayed(const Duration(milliseconds: 500));
        await user.getIdToken(true);

        try {
          await ref.read(favoriteProvider.notifier).loadFavorites();
        } catch (e) {
          debugPrint('❌ Error: Favorites load failed: $e');
        }

        final authRepo = ref.read(authRepositoryProvider);
        final userData = await authRepo.getUserData(user.uid);

        if (mounted) {
          final resolvedName = (userData?.fullName.trim().isNotEmpty == true)
              ? userData!.fullName.trim()
              : (userData?.username.trim().isNotEmpty == true ? userData!.username.trim() : null);

          // 3-second frosted loading transition with map.json animation and market phrases
          await AuthLoadingDialog.show(
            context,
            userName: resolvedName,
          );
        }

        if (userData?.role == 'admin') {
          if (mounted) context.go(RouteNames.admin);
        } else {
          if (mounted) context.go(RouteNames.home);
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          if (e.code == 'wrong-password') {
            _errorMessage = 'Incorrect password. Please try again.';
          } else if (e.code == 'user-not-found') {
            _errorMessage = 'Account not found. Please check your credentials.';
          } else if (e.code == 'too-many-requests') {
            _errorMessage = 'Too many failed attempts. Please try again later.';
          } else if (e.code == 'user-disabled') {
            _errorMessage = 'This account has been disabled.';
          } else if (e.code == 'invalid-email') {
            _errorMessage = 'Invalid email address.';
          } else {
            _errorMessage = 'An error occurred during sign in. Please try again.';
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Error: Login failed: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().contains('permission-denied')
              ? 'Login failed due to a network connection issue.'
              : 'An unexpected error occurred. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Top Hero Illustration Header Layer (Top 38% of screen, collapses smoothly when typing)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            top: 0,
            left: 0,
            right: 0,
            height: isKeyboardOpen ? 105.0 : screenHeight * 0.38,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/public_market.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Image.asset(
                    'assets/images/market_scene.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFF1B5E20),
                      child: const Center(
                        child: Icon(Icons.storefront_rounded, size: 80, color: Colors.white24),
                      ),
                    ),
                  ),
                ),
                // Soft gradient scrim for top back button readability
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 110,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black.withValues(alpha: 0.40), Colors.transparent],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                // Top-left Back button inside a frosted circular container
                SafeArea(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.88),
                        shape: const CircleBorder(),
                        elevation: 3,
                        shadowColor: Colors.black26,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go(RouteNames.getStarted);
                            }
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
                              color: Color(0xFF1B5E20),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Floating Bottom Sheet Card Layer (Expands room when keyboard opens to eliminate jitter)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            top: isKeyboardOpen ? 90.0 : screenHeight * 0.33,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, -6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Subtle Drag-Handle Pill
                        Center(
                          child: Container(
                            width: 44,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 22),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        // Title: "Login to Access Your Ligao Market Guide"
                        Text(
                          'Login to Access Your',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E293B),
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Ligao Market Guide',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1B5E20), // Ligao Green
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 26),

                        // Error Banner
                        if (_errorMessage != null) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 18),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFEF4444)),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: Color(0xFFDC2626),
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: const Color(0xFFB91C1C),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Email / Username Field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF0F172A),
                          ),
                          decoration: _buildInputDecoration(
                            hint: 'Enter your email or username',
                            icon: Icons.mail_outline_rounded,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your email or username';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password Field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _handleLogin(),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF0F172A),
                          ),
                          decoration: _buildInputDecoration(
                            hint: 'Enter your password',
                            icon: Icons.lock_outline_rounded,
                            suffix: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Colors.grey.shade500,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your password';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Remember Me & Forgot Password Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: Checkbox(
                                    value: _rememberMe,
                                    activeColor: const Color(0xFF1B5E20),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    onChanged: (val) => setState(() => _rememberMe = val ?? false),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Remember me',
                                  style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: () => context.push(RouteNames.forgotPassword),
                              child: Text(
                                'Forgot password?',
                                style: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  color: const Color(0xFF1B5E20),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Solid Ligao Green Login Button (#1B5E20)
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B5E20),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFF1B5E20).withValues(alpha: 0.6),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 2,
                            shadowColor: const Color(0xFF1B5E20).withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  'Login',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 24),

                        // Footer: Switch to Sign Up
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13),
                            ),
                            GestureDetector(
                              onTap: () {
                                if (context.canPop()) {
                                  context.push(RouteNames.signup);
                                } else {
                                  context.push(RouteNames.signup);
                                }
                              },
                              child: Text(
                                'Create an account',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF1B5E20),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(fontSize: 13.5, color: Colors.grey.shade400),
      prefixIcon: Icon(icon, color: Colors.grey.shade500, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF1B5E20), width: 1.5),
      ),
    );
  }
}

