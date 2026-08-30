import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/router/route_names.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/favorite_provider.dart';

/// Alias for SignInScreen to maintain naming compatibility
typedef SignInScreen = LoginScreen;

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

  static const _logoImage = ResizeImage(
    AssetImage('assets/icons/MerkadoGo_Transparent Logo.png'),
    width: 250,
    height: 250,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(_logoImage, context);
  }

  @override
  void dispose() {
    _usernameOrEmailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<String?> _getEmailFromUsername(String input) async {
    final trimmed = input.trim();

    // If input is already an email, return directly
    if (trimmed.contains('@')) {
      return trimmed;
    }

    final username = trimmed.toLowerCase();

    try {
      // Step 1: Query usernames collection
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

      // Step 2: Read users collection to retrieve associated email
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
      final email = await _getEmailFromUsername(
        _usernameOrEmailController.text.trim(),
      );

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
        // Allow auth token to propagate before reading user role
        await Future.delayed(const Duration(milliseconds: 500));
        await user.getIdToken(true);

        try {
          await ref.read(favoriteProvider.notifier).loadFavorites();
        } catch (e) {
          debugPrint('❌ Error: Favorites load failed: $e');
        }

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
            _errorMessage =
                'Account not found. Please check your credentials.';
          } else if (e.code == 'too-many-requests') {
            _errorMessage =
                'Too many failed attempts. Please try again later.';
          } else if (e.code == 'user-disabled') {
            _errorMessage = 'This account has been disabled.';
          } else if (e.code == 'invalid-email') {
            _errorMessage = 'Invalid email address.';
          } else {
            _errorMessage =
                'An error occurred during sign in. Please try again.';
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
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      body: Stack(
        children: [
          // 1. Base Gradient Background (Deep Emerald transitioning to Soft Light Canvas)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF1B5E20),
                    Color(0xFF2E7D32),
                    Color(0xFFF8FAF8),
                  ],
                  stops: [0.0, 0.36, 0.78],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // 2. Vector Street Lines & Route Map Canvas
          const Positioned.fill(
            child: CustomPaint(
              painter: MapLinesPainter(),
            ),
          ),

          // 3. Main Scrollable Content
          SafeArea(
            child: Column(
              children: [
                // Top Navigation Bar with Back Button
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go(RouteNames.getStarted);
                            }
                          },
                          tooltip: 'Back',
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // App Logo in White Square Container with Curved Edges (Enlarged)
                          Container(
                            width: 82,
                            height: 82,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.16),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Image(
                              image: _logoImage,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Branding Title (Matching Welcome / Get Started Screen)
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Merkado',
                                  style: GoogleFonts.poppins(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                TextSpan(
                                  text: 'Go',
                                  style: GoogleFonts.poppins(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFE53935),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Sign in to navigate Ligao Public Market stalls & finds',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.90),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Floating Elevated Form Card
                          Container(
                            constraints: const BoxConstraints(maxWidth: 480),
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 28,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Welcome Back',
                                    style: GoogleFonts.outfit(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1B5E20),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Enter your account details below',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: const Color(0xFF6B7280),
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Email / Username Input
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
                                        color: const Color(0xFF6B7280),
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.pin_drop_outlined,
                                        color: Color(0xFF1B5E20),
                                        size: 22,
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFFF9FAFB),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 16,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFE5E7EB),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFE5E7EB),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFE53935),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Please enter your email or username';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Password Input
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
                                        color: const Color(0xFF6B7280),
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.lock_outline,
                                        color: Color(0xFF1B5E20),
                                        size: 22,
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          color: const Color(0xFF6B7280),
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _obscurePassword =
                                                !_obscurePassword;
                                          });
                                        },
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFFF9FAFB),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 16,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFE5E7EB),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFE5E7EB),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFE53935),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _handleLogin(),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Please enter your password';
                                      }
                                      return null;
                                    },
                                  ),

                                  // Forgot Password Link
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () => context.push(
                                        RouteNames.forgotPassword,
                                      ),
                                      child: Text(
                                        'Forgot Password?',
                                        style: GoogleFonts.poppins(
                                          color: const Color(0xFF1B5E20),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),

                                  // Error Banner
                                  if (_errorMessage != null) ...[
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 14),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEE2E2),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFFEF4444),
                                        ),
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

                                  // Action CTA: Solid Deep Ligao Forest Green Button (#1B5E20)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1B5E20),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF1B5E20)
                                              .withValues(alpha: 0.3),
                                          blurRadius: 12,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed:
                                          _isLoading ? null : _handleLogin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        disabledBackgroundColor:
                                            Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              height: 22,
                                              width: 22,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(Colors.white),
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  'Sign In',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                const Icon(
                                                  Icons.arrow_forward_rounded,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Footer: Switch Mode Prompt
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Don't have an account? ",
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF4B5563),
                                  fontSize: 14,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => context.push(RouteNames.signup),
                                child: Text(
                                  'Sign Up',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF1B5E20),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Subtle, Minimalist Vector Map Background Painter
class MapLinesPainter extends CustomPainter {
  const MapLinesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Soft Arterial Road Curves (Low opacity, non-distracting)
    final mainRoadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 24
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final secondaryRoadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // 2. Refined Dashed Route Path (Ligao Red)
    final redDashPaint = Paint()
      ..color = const Color(0xFFE53935).withValues(alpha: 0.32)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    // 3. Waypoint Nodes & Subtle Glow Dots
    final nodePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    final nodeGlowPaint = Paint()
      ..color = const Color(0xFFE53935).withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;

    // ─── A. ELEGANT SWEEPING ARTERIAL CURVES ─────────────────────────────
    // Top-to-bottom gentle highway curve
    final highway = Path()
      ..moveTo(size.width * 0.12, -20)
      ..cubicTo(
        size.width * 0.45,
        size.height * 0.30,
        size.width * 0.55,
        size.height * 0.65,
        size.width * 0.88,
        size.height + 20,
      );
    canvas.drawPath(highway, mainRoadPaint);

    // Upper sweeping boulevard curve
    final upperBoulevard = Path()
      ..moveTo(-20, size.height * 0.22)
      ..cubicTo(
        size.width * 0.35,
        size.height * 0.16,
        size.width * 0.65,
        size.height * 0.36,
        size.width + 20,
        size.height * 0.28,
      );
    canvas.drawPath(upperBoulevard, mainRoadPaint);

    // Lower subtle connecting arc
    final lowerArc = Path()
      ..moveTo(size.width + 20, size.height * 0.70)
      ..cubicTo(
        size.width * 0.60,
        size.height * 0.78,
        size.width * 0.30,
        size.height * 0.58,
        -20,
        size.height * 0.82,
      );
    canvas.drawPath(lowerArc, secondaryRoadPaint);

    // ─── B. CLEAN DASHED WAYPOINT NAVIGATION ROUTE ───────────────────────
    final navRoute = Path()
      ..moveTo(size.width * 0.18, size.height * 0.08)
      ..cubicTo(
        size.width * 0.32,
        size.height * 0.26,
        size.width * 0.52,
        size.height * 0.48,
        size.width * 0.80,
        size.height * 0.90,
      );
    _drawDashedPath(canvas, navRoute, redDashPaint);

    // ─── C. WAYPOINT GLOW NODES ──────────────────────────────────────────
    void drawWaypoint(Offset pos) {
      canvas.drawCircle(pos, 10, nodeGlowPaint);
      canvas.drawCircle(pos, 5, nodePaint);
    }

    drawWaypoint(Offset(size.width * 0.18, size.height * 0.08));
    drawWaypoint(Offset(size.width * 0.42, size.height * 0.38));
    drawWaypoint(Offset(size.width * 0.80, size.height * 0.90));
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashWidth = 8.0;
    const dashSpace = 6.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final currentDashWidth = math.min(dashWidth, metric.length - distance);
        canvas.drawPath(
          metric.extractPath(distance, distance + currentDashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
