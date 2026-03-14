import 'dart:async';
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
  static const ImageProvider _splashLogoProvider = ResizeImage(
    AssetImage('assets/images/splash_logo.png'),
    width: 320,
  );

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _assetsReady = false;

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

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeOut,
      ),
    );

    _precacheAndStart();
  }

  Future<void> _precacheAndStart() async {
    if (mounted) {
      try {
        await precacheImage(_splashLogoProvider, context);
        if (mounted) {
          setState(() {
            _assetsReady = true;
          });
        }
      } catch (_) {
        // Continue splash flow even if precache fails.
        if (mounted) {
          setState(() {
            _assetsReady = true;
          });
        }
      }
    }

    if (!mounted) return;
    unawaited(_fadeController.forward());
    _startSplashTimer();
  }

  void _startSplashTimer() {
    // Keep existing splash delay and auth redirect flow.
    Future.delayed(const Duration(milliseconds: 3500), () async {
      if (mounted) {
        await _checkAuthAndNavigate();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _checkAuthAndNavigate() async {
    try {
      final authRepo = ref.read(authRepositoryProvider);
      final user = authRepo.currentUser;

      if (user == null) {
        if (mounted) context.go(RouteNames.getStarted);
        return;
      }

      if (!user.emailVerified) {
        if (mounted) context.go(RouteNames.verifyEmail);
        return;
      }

      final userData = await authRepo.getUserData(user.uid);

      if (mounted) {
        if (userData?.role == 'admin') {
          context.go(RouteNames.admin);
        } else {
          context.go(RouteNames.home);
        }
      }
    } catch (e) {
      debugPrint('❌ Error: Splash auth check failed: $e');
      if (mounted) {
        context.go(RouteNames.getStarted);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      body: Stack(
        children: [
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            top: 80,
            left: 24,
            child: _buildDotGrid(
              rows: 4,
              cols: 4,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            bottom: 120,
            right: 24,
            child: _buildDotGrid(
              rows: 4,
              cols: 4,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CustomPaint(
              size: Size(size.width, 160),
              painter: _WavePainter(),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 8,
                  child: Center(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(32),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 30,
                                    offset: const Offset(0, 12),
                                  ),
                                  BoxShadow(
                                    color: const Color(0xFF4CAF50)
                                        .withValues(alpha: 0.3),
                                    blurRadius: 40,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(16),
                              child: _assetsReady
                                  ? Image(
                                      image: _splashLogoProvider,
                                      fit: BoxFit.contain,
                                      filterQuality: FilterQuality.medium,
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            const SizedBox(height: 28),
                            RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Merkado',
                                    style: GoogleFonts.poppins(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'Go',
                                    style: GoogleFonts.poppins(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFFE53935),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(width: 30, height: 1, color: Colors.white30),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Your Ligao City Public Market Guide',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.white60,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(width: 30, height: 1, color: Colors.white30),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      const _AnimatedDots(),
                      const SizedBox(height: 10),
                      Text(
                        'LOADING...',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.white38,
                          letterSpacing: 3,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDotGrid({
    required int rows,
    required int cols,
    required Color color,
  }) {
    return Column(
      children: List.generate(
        rows,
        (r) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              cols,
              (c) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.5);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.2,
      size.width * 0.5,
      size.height * 0.45,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.7,
      size.width,
      size.height * 0.4,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);

    final paint2 = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;

    final path2 = Path();
    path2.moveTo(0, size.height * 0.7);
    path2.quadraticBezierTo(
      size.width * 0.3,
      size.height * 0.4,
      size.width * 0.6,
      size.height * 0.65,
    );
    path2.quadraticBezierTo(
      size.width * 0.8,
      size.height * 0.8,
      size.width,
      size.height * 0.6,
    );
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) => false;
}

class _AnimatedDots extends StatefulWidget {
  const _AnimatedDots();

  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots>
    with TickerProviderStateMixin {
  final List<AnimationController> _controllers = [];
  final List<Animation<double>> _animations = [];

  @override
  void initState() {
    super.initState();

    for (int i = 0; i < 3; i++) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );

      _controllers.add(ctrl);
      _animations.add(
        Tween<double>(begin: 0, end: -8).animate(
          CurvedAnimation(
            parent: ctrl,
            curve: Curves.easeInOut,
          ),
        ),
      );

      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) {
          ctrl.repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (i) => AnimatedBuilder(
          animation: _animations[i],
          builder: (_, __) => Transform.translate(
            offset: Offset(0, _animations[i].value),
            child: Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white38,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
