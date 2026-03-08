import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/router/route_names.dart';
import '../../../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoOpacity;
  late Animation<double> _logoScale;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _loadingOpacity;

  int _activeDot = 0;

  @override
  void initState() {
    super.initState();

    // Set system UI
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Single animation controller
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Logo animations
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
      ),
    );

    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOutBack),
      ),
    );

    // Text animations
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.875, curve: Curves.easeOut),
      ),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.875, curve: Curves.easeOut),
      ),
    );

    // Loading dots animation
    _loadingOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.625, 1.0, curve: Curves.easeIn),
      ),
    );

    // Start animations
    _controller.forward();

    // Animated dots cycling
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _startDotsAnimation();
      }
    });

    // Check auth and navigate
    Future.delayed(const Duration(milliseconds: 3500), () async {
      if (mounted) {
        await _checkAuthAndNavigate();
      }
    });
  }

  void _startDotsAnimation() {
    Future.doWhile(() async {
      if (!mounted) return false;
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        setState(() {
          _activeDot = (_activeDot + 1) % 3;
        });
        return true;
      }
      return false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _checkAuthAndNavigate() async {
    try {
      debugPrint('🔍 Checking auth status...');
      final authRepo = ref.read(authRepositoryProvider);
      final user = authRepo.currentUser;

      if (user == null) {
        debugPrint('✅ No user, going to GetStarted');
        if (mounted) context.go(RouteNames.getStarted);
        return;
      }

      if (!user.emailVerified) {
        debugPrint('✅ User not verified, going to VerifyEmail');
        if (mounted) context.go(RouteNames.verifyEmail);
        return;
      }

      debugPrint('🔍 Fetching user data...');
      final userData = await authRepo.getUserData(user.uid);

      if (mounted) {
        if (userData?.role == 'admin') {
          debugPrint('✅ Admin user, going to Dashboard');
          context.go(RouteNames.adminDashboard);
        } else {
          debugPrint('✅ Regular user, going to Home');
          context.go(RouteNames.home);
        }
      }
    } catch (e, stack) {
      debugPrint('🔴 Error in _checkAuthAndNavigate: $e');
      debugPrint('🔴 STACK: $stack');
      if (mounted) {
        context.go(RouteNames.getStarted);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      return Scaffold(
        backgroundColor: const Color(0xFF1A5C20),
        body: Stack(
        children: [
          // Subtle decorative elements
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF2E7D32).withOpacity(0.15),
                    const Color(0xFF1A5C20).withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF0D3F13).withOpacity(0.3),
                    const Color(0xFF1A5C20).withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 100,
            left: 30,
            child: FadeTransition(
              opacity: _logoOpacity,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.05),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 150,
            right: 40,
            child: FadeTransition(
              opacity: _textOpacity,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // Logo
                FadeTransition(
                  opacity: _logoOpacity,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x30000000),
                            blurRadius: 20,
                            spreadRadius: 0,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(12.5),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 65,
                          height: 65,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // App Name & Tagline
                FadeTransition(
                  opacity: _textOpacity,
                  child: AnimatedBuilder(
                    animation: _textSlide,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _textSlide.value.dy),
                        child: child,
                      );
                    },
                    child: Column(
                      children: [
                        // App Name
                        Text(
                          'Merkado Go',
                          style: GoogleFonts.poppins(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 8),

                        // Tagline
                        Text(
                          'Your Ligao City Public Market Guide',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: const Color(0x99FFFFFF),
                            letterSpacing: 0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // Loading Section
                FadeTransition(
                  opacity: _loadingOpacity,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 50),
                    child: Column(
                      children: [
                        // Animated Dots
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(3, (index) {
                            final isActive = index == _activeDot;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: isActive ? 8 : 6,
                              height: isActive ? 8 : 6,
                              margin: EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: isActive ? 0 : 1,
                              ),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? const Color(0xFFFFFFFF)
                                    : const Color(0x80FFFFFF),
                                borderRadius: BorderRadius.circular(
                                  isActive ? 4 : 3,
                                ),
                              ),
                            );
                          }),
                        ),

                        const SizedBox(height: 10),

                        // Loading Text
                        Text(
                          'LOADING...',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: const Color(0x70FFFFFF),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    } catch (e, stack) {
      debugPrint('🔴 Error in SplashScreen build: $e');
      debugPrint('🔴 STACK: $stack');
      return Scaffold(
        backgroundColor: const Color(0xFF1A5C20),
        body: Center(
          child: Text(
            'Error: $e',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
  }
}
