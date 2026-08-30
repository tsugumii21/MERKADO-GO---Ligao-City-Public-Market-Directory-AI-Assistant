import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/router/route_names.dart';

/// Alias for WelcomeLandingScreen to maintain naming compatibility
typedef WelcomeLandingScreen = GetStartedScreen;

/// Welcome / Landing screen for Merkado Go with modern map-themed design system
class GetStartedScreen extends StatefulWidget {
  const GetStartedScreen({super.key});

  @override
  State<GetStartedScreen> createState() => _GetStartedScreenState();
}

class _GetStartedScreenState extends State<GetStartedScreen> {
  final int _currentPage = 0;
  static const _logoImage = ResizeImage(
    AssetImage('assets/icons/MerkadoGo_Transparent Logo.png'),
    width: 300,
    height: 300,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(_logoImage, context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D3310),
      body: Stack(
        children: [
          // 1. Deep Green Gradient Background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF1B5E20),
                    Color(0xFF144D18),
                    Color(0xFF0D3310),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // 2. Procedural Map & Navigation Linework
          const Positioned.fill(
            child: CustomPaint(
              painter: MapLinesPainter(),
            ),
          ),

          // 3. Main Content Layout
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const SizedBox(height: 16),

                // Location Tag Pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.18)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 14,
                        color: Color(0xFFE53935),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Ligao City Public Market',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // MerkadoGo Logo Container (Curved White Square)
                Container(
                  width: 104,
                  height: 104,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
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
                const SizedBox(height: 18),

                // Brand Title (Crisp White + Ligao Red)
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: GoogleFonts.poppins(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                    children: const [
                      TextSpan(
                        text: 'Merkado',
                        style: TextStyle(color: Colors.white),
                      ),
                      TextSpan(
                        text: 'Go',
                        style: TextStyle(color: Color(0xFFE53935)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36.0),
                  child: Text(
                    'Your guide to Ligao City Public Market — stalls, hours, and directions in one place.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.90),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Carousel Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    final bool isActive = index == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 6,
                      width: isActive ? 22 : 6,
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),

                const Spacer(),

                // 4. Elevated Bottom Action Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 25,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Sign in or create an account to continue',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF4B5563),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Sign In Solid Button
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B5E20),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1B5E20)
                                  .withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () => context.push(RouteNames.login),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Sign in',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 20,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Create Account Outlined Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => context.push(RouteNames.signup),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(
                              color: Color(0xFF1B5E20),
                              width: 1.6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Create account',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1B5E20),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Terms Caption
                      Text(
                        'By continuing you agree to our terms',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
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

/// Subtle Procedural Map Linework & Waypoint Painter
class MapLinesPainter extends CustomPainter {
  const MapLinesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 26
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dashPaint = Paint()
      ..color = const Color(0xFFE53935).withValues(alpha: 0.28)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final nodePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    // 1. Major Road Pathways
    final mainRoad = Path()
      ..moveTo(0, size.height * 0.16)
      ..cubicTo(
        size.width * 0.40,
        size.height * 0.12,
        size.width * 0.65,
        size.height * 0.28,
        size.width,
        size.height * 0.22,
      );
    canvas.drawPath(mainRoad, roadPaint);

    final crossRoad = Path()
      ..moveTo(size.width * 0.12, 0)
      ..lineTo(size.width * 0.88, size.height * 0.75);
    canvas.drawPath(crossRoad, roadPaint);

    final secondaryRoad = Path()
      ..moveTo(size.width, size.height * 0.52)
      ..cubicTo(
        size.width * 0.60,
        size.height * 0.58,
        size.width * 0.30,
        size.height * 0.45,
        0,
        size.height * 0.65,
      );
    canvas.drawPath(secondaryRoad, roadPaint);

    // 2. Dashed Navigation Route
    final dashedPath = Path()
      ..moveTo(size.width * 0.18, size.height * 0.08)
      ..lineTo(size.width * 0.50, size.height * 0.38)
      ..lineTo(size.width * 0.82, size.height * 0.65);
    _drawDashedPath(canvas, dashedPath, dashPaint);

    // 3. Waypoint Map Nodes
    canvas.drawCircle(
      Offset(size.width * 0.18, size.height * 0.08),
      6,
      nodePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.50, size.height * 0.38),
      8,
      nodePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.65),
      6,
      nodePaint,
    );
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
