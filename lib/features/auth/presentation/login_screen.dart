import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/router/route_names.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/favorite_provider.dart';
import 'widgets/auth_layout.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameOrEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameOrEmailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<String?> _getEmailFromUsername(String input) async {
    final trimmed = input.trim();
    
    // If input is email, return directly
    if (trimmed.contains('@')) {
      return trimmed;
    }
    
    final username = trimmed.toLowerCase();
    
    try {
      // STEP 1: Read usernames collection
      // This collection allows public read so no auth needed
      
      final usernameDoc = await FirebaseFirestore.instance
          .collection('usernames')  // ← MUST be usernames
          .doc(username)
          .get(const GetOptions(source: Source.server));
      
      
      if (!usernameDoc.exists) {
        return null;
      }
      
      final uid = usernameDoc.data()?['uid'] as String?;
      
      if (uid == null || uid.isEmpty) {
        return null;
      }
      
      // STEP 2: Read users collection to get email
      // This also allows public read for the email field lookup
      
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server));
      
      
      final email = userDoc.data()?['email'] as String?;
      
      return email;
      
    } catch (e) {
      debugPrint('❌ Error: Username lookup failed: $e');
      return null;
    }
  }

  Future<void> _handleLogin() async {
    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      
      // Get email (works for both email and username)
      final email = await _getEmailFromUsername(
          _usernameOrEmailController.text.trim());
      
      
      if (email == null) {
        if (mounted) {
          setState(() {
            _errorMessage = _usernameOrEmailController.text.trim().contains('@')
                ? 'Email not found. Please check your email and try again.'
                : 'Username not found or connection issue. Please try again.';
            _isLoading = false;
          });
        }
        return;
      }
      
      // Sign in with email and password
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: email,
            password: _passwordController.text,
          );

      
      final user = userCredential.user;
      
      if (user != null && !user.emailVerified) {
        if (mounted) context.go(RouteNames.verifyEmail);
        return;
      }

      if (user != null) {
        // ⏳ Wait for auth token to propagate to Firestore before reading user data
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Force token refresh to ensure Firestore recognizes the auth state
        await user.getIdToken(true);
        
        // Load favorites after successful login (non-critical)
        try {
          await ref.read(favoriteProvider.notifier).loadFavorites();
        } catch (e) {
          // Non-critical - favorites can load later
          debugPrint('❌ Error: Favorites load failed: $e');
        }
        
        // Now safe to read Firestore
        final authRepo = ref.read(authRepositoryProvider);
        final userData = await authRepo.getUserData(user.uid);
        
        
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
            _errorMessage = 'Account not found. Please check your email and try again.';
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
              ? 'Login failed due to a connection issue. Please try again.'
              : 'An error occurred. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildFormFields(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Welcome Back',
            style: GoogleFonts.dmSans(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A241A),
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),
          TextFormField(
            controller: _usernameOrEmailController,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1A241A),
            ),
            decoration: InputDecoration(
              labelText: 'Email or Username',
              labelStyle: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF667066),
              ),
              prefixIcon: const Icon(
                Icons.person_outline_rounded,
                color: Color(0xFF667066),
                size: 22,
              ),
              filled: true,
              fillColor: const Color(0xFFF6F8F6),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDCE3DC), width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDCE3DC), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1B5E20), width: 2),
              ),
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email or username';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1A241A),
            ),
            decoration: InputDecoration(
              labelText: 'Password',
              labelStyle: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF667066),
              ),
              prefixIcon: const Icon(
                Icons.lock_outline_rounded,
                color: Color(0xFF667066),
                size: 22,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: const Color(0xFF667066),
                  size: 22,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              filled: true,
              fillColor: const Color(0xFFF6F8F6),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDCE3DC), width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDCE3DC), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1B5E20), width: 2),
              ),
            ),
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleLogin(),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.push(RouteNames.forgotPassword),
              child: Text(
                'Forgot Password?',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1B5E20),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
                      'Sign In',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD32F2F)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFD32F2F), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFFD32F2F),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Don't have an account? ",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: const Color(0xFF757575),
                ),
              ),
              TextButton(
                onPressed: () => context.push(RouteNames.signup),
                child: Text(
                  'Sign Up',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1B5E20),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileView(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF1B5E20),
            size: 20,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(RouteNames.getStarted);
            }
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                // App logo — white rounded-square container, transparent logo (consistent with desktop panel)
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Image.asset(
                    'assets/icons/MerkadoGo_Transparent Logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 32),
                _buildFormFields(context),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      mobileBody: _buildMobileView(context),
      desktopFormContent: _buildFormFields(context),
      heroTitle: 'Welcome Back',
      heroSubtitle: 'Ligao City Public Market, at your fingertips.',
      heroIcon: Icons.login_rounded,
      illustrationPath: 'assets/images/sign-in_illustration.png',
    );
  }
}
