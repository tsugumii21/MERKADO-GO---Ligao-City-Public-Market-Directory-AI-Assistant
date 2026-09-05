import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/router/route_names.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/exceptions/auth_exception.dart';

/// Alias for SignUpScreen to maintain naming compatibility
typedef SignUpScreen = SignupScreen;

/// Create Account / Sign Up Screen with modern map-themed design system
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final username = _usernameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.signUp(
        email: email,
        password: password,
        username: username,
        fullName: username,
      );

      if (mounted) {
        context.go(RouteNames.verifyEmail);
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          if (e.code == 'email-already-in-use') {
            _errorMessage = 'An account already exists with this email address.';
          } else if (e.code == 'invalid-email') {
            _errorMessage = 'Invalid email address.';
          } else if (e.code == 'weak-password') {
            _errorMessage = 'Password must be at least 6 characters.';
          } else {
            _errorMessage = e.message ?? 'Sign up failed. Please try again.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred. Please try again.';
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

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Top Hero Header Layer (Top 34% of screen)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: screenHeight * 0.34,
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
                              context.go(RouteNames.login);
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

          // 2. Floating Bottom Sheet Card Layer (Overlaps hero header)
          Positioned(
            top: screenHeight * 0.28,
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
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        // Title: "Create Account to Explore Ligao Market"
                        Text(
                          'Create Account to',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E293B),
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Explore Ligao Market',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1B5E20),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 22),

                        // Error Banner
                        if (_errorMessage != null) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
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

                        // 1. Full Name / Username Field
                        TextFormField(
                          controller: _usernameController,
                          textInputAction: TextInputAction.next,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF0F172A),
                          ),
                          decoration: _buildInputDecoration(
                            hint: 'Full Name / Username',
                            icon: Icons.person_outline_rounded,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a name or username';
                            }
                            if (value.trim().length < 3) {
                              return 'Name must be at least 3 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // 2. Email Address Field
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
                            hint: 'Enter your email',
                            icon: Icons.mail_outline_rounded,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!value.contains('@')) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // 3. Password Field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF0F172A),
                          ),
                          decoration: _buildInputDecoration(
                            hint: 'Create password',
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
                              return 'Please enter a password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // 4. Confirm Password Field
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _handleSignup(),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF0F172A),
                          ),
                          decoration: _buildInputDecoration(
                            hint: 'Confirm password',
                            icon: Icons.lock_reset_rounded,
                            suffix: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Colors.grey.shade500,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Sign Up Primary Button (Solid Ligao Green)
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleSignup,
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
                                  'Sign Up',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 22),

                        // Footer: Back to Login
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account? ',
                              style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13),
                            ),
                            GestureDetector(
                              onTap: () {
                                if (context.canPop()) {
                                  context.pop();
                                } else {
                                  context.go(RouteNames.login);
                                }
                              },
                              child: Text(
                                'Log In',
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
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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

