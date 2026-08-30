import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/router/route_names.dart';
import '../../../providers/auth_provider.dart';

/// Feedback types for verification actions
enum FeedbackType { success, warning, error }

/// Modern Map-Themed Email Verification Screen for Merkado Go
class EmailVerifyScreen extends ConsumerStatefulWidget {
  const EmailVerifyScreen({super.key});

  @override
  ConsumerState<EmailVerifyScreen> createState() => _EmailVerifyScreenState();
}

class _EmailVerifyScreenState extends ConsumerState<EmailVerifyScreen>
    with SingleTickerProviderStateMixin {
  bool _isCheckingVerification = false;
  bool _isResending = false;
  bool _canResend = true;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;
  String? _feedbackMessage;
  FeedbackType? _feedbackType;

  late AnimationController _contentController;
  late Animation<double> _contentOpacity;

  @override
  void initState() {
    super.initState();

    _contentController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _contentOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOutCubic),
    );

    _contentController.forward();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _checkEmailVerified() async {
    setState(() {
      _isCheckingVerification = true;
      _feedbackMessage = null;
      _feedbackType = null;
    });
    await HapticFeedback.lightImpact();

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final isVerified = await authRepo.checkEmailVerified();

      if (mounted) {
        if (isVerified) {
          setState(() {
            _feedbackMessage = 'Email successfully verified! Redirecting...';
            _feedbackType = FeedbackType.success;
          });
          await Future.delayed(const Duration(milliseconds: 800));
          if (mounted) {
            context.go(RouteNames.home);
          }
        } else {
          setState(() {
            _feedbackMessage =
                'Email not verified yet. Please check your inbox and click the verification link.';
            _feedbackType = FeedbackType.warning;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _feedbackMessage =
              'Error checking verification status. Please try again.';
          _feedbackType = FeedbackType.error;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingVerification = false;
        });
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (!_canResend || _isResending) return;

    setState(() {
      _isResending = true;
      _feedbackMessage = null;
      _feedbackType = null;
    });
    await HapticFeedback.lightImpact();

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.sendVerificationEmail();

      if (mounted) {
        setState(() {
          _feedbackMessage =
              'Verification email sent! Please check your inbox.';
          _feedbackType = FeedbackType.success;
        });
        _startCooldown();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _feedbackMessage = 'Failed to send email. Please try again.';
          _feedbackType = FeedbackType.error;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  void _startCooldown() {
    setState(() {
      _canResend = false;
      _resendCooldown = 60;
    });

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown > 0) {
        setState(() {
          _resendCooldown--;
        });
      } else {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  Future<void> _showSignOutDialog() async {
    unawaited(HapticFeedback.selectionClick());
    if (!mounted) return;
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Sign Out?',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1B5E20),
          ),
        ),
        content: Text(
          'You will be signed out and can register with a different email.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: const Color(0xFF757575),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF9E9E9E),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Sign Out',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFB71C1C),
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldSignOut == true) {
      await _handleSignOut();
    }
  }

  Future<void> _handleSignOut() async {
    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.signOut();
      if (mounted) {
        context.go(RouteNames.getStarted);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _feedbackMessage = 'Failed to sign out. Please try again.';
          _feedbackType = FeedbackType.error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    final email = user?.email ?? 'your email address';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      body: Stack(
        children: [
          // 1. Base Gradient Background (Matches SignUp & Login exactly)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF1B5E20),
                    Color(0xFF2E7D32),
                    Color(0xFFF8FAF8),
                  ],
                  stops: [0.0, 0.28, 0.70],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // 2. Procedural Map Linework
          const Positioned.fill(
            child: CustomPaint(
              painter: MapLinesPainter(),
            ),
          ),

          // 3. Main Content Flow
          SafeArea(
            child: Column(
              children: [
                // Top Navigation Bar with Back Button & Brand Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
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
                          onPressed: _showSignOutDialog,
                          tooltip: 'Back to Sign In',
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Brand Logo Container
                      Container(
                        width: 34,
                        height: 34,
                        padding: const EdgeInsets.all(4.5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.14),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/icons/MerkadoGo_Transparent Logo.png',
                          cacheWidth: 100,
                          cacheHeight: 100,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Brand Text
                      RichText(
                        text: TextSpan(
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
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
                    ],
                  ),
                ),

                // Scrollable Body Content
                Expanded(
                  child: FadeTransition(
                    opacity: _contentOpacity,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: math.max(0, constraints.maxHeight - 20),
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 440),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(height: 12),

                                    // Mail Verification Badge
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFFE53935),
                                          width: 2.0,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.14),
                                            blurRadius: 16,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.mark_email_read_rounded,
                                          size: 32,
                                          color: Color(0xFF1B5E20),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Title & Subtitle
                                    Text(
                                      'Verify Your Email',
                                      style: GoogleFonts.poppins(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'One last step — confirm your email address to activate your account.',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: const Color(0xFFE8F5E9),
                                        height: 1.4,
                                      ),
                                    ),

                                    const SizedBox(height: 24),

                                    // Elevated Form Card
                                    Container(
                                      padding: const EdgeInsets.fromLTRB(
                                        20,
                                        24,
                                        20,
                                        24,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(28),
                                        border: Border.all(
                                          color: const Color(0xFFE5E7EB),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.08),
                                            blurRadius: 24,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                            'We sent a verification link to:',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              color: const Color(0xFF6B7280),
                                            ),
                                          ),
                                          const SizedBox(height: 10),

                                          // Email Pill Box
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF0FDF4),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color:
                                                    const Color(0xFF86EFAC),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const Icon(
                                                  Icons.mail_outline_rounded,
                                                  size: 18,
                                                  color: Color(0xFF16A34A),
                                                ),
                                                const SizedBox(width: 8),
                                                Flexible(
                                                  child: Text(
                                                    email,
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: const Color(
                                                          0xFF15803D),
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          const SizedBox(height: 12),

                                          // Subtitle helper
                                          Text(
                                            'Please check your inbox and spam folder, then click the link to confirm.',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.poppins(
                                              fontSize: 12.5,
                                              color: const Color(0xFF9CA3AF),
                                              height: 1.4,
                                            ),
                                          ),

                                          if (_feedbackMessage != null) ...[
                                            const SizedBox(height: 16),
                                            _buildFeedbackBanner(),
                                          ],

                                          const SizedBox(height: 20),

                                          // Primary CTA: "I Have Verified My Email" (Unclipped Text)
                                          SizedBox(
                                            width: double.infinity,
                                            height: 52,
                                            child: ElevatedButton.icon(
                                              onPressed:
                                                  _isCheckingVerification
                                                      ? null
                                                      : _checkEmailVerified,
                                              icon: _isCheckingVerification
                                                  ? const SizedBox.shrink()
                                                  : const Icon(
                                                      Icons
                                                          .check_circle_outline_rounded,
                                                      size: 20,
                                                      color: Colors.white,
                                                    ),
                                              label: _isCheckingVerification
                                                  ? const SizedBox(
                                                      height: 20,
                                                      width: 20,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2.2,
                                                        valueColor:
                                                            AlwaysStoppedAnimation<
                                                                Color>(
                                                          Colors.white,
                                                        ),
                                                      ),
                                                    )
                                                  : Text(
                                                      'I Have Verified My Email',
                                                      style: GoogleFonts
                                                          .poppins(
                                                        fontSize: 14.5,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                        height: 1.2,
                                                      ),
                                                    ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFF1B5E20),
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 16),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                disabledBackgroundColor:
                                                    const Color(0xFF1B5E20)
                                                        .withValues(alpha: 0.6),
                                              ),
                                            ),
                                          ),

                                          const SizedBox(height: 12),

                                          // Resend Button with Cooldown (Unclipped Text)
                                          SizedBox(
                                            width: double.infinity,
                                            height: 48,
                                            child: OutlinedButton.icon(
                                              onPressed: _canResend
                                                  ? _resendVerificationEmail
                                                  : null,
                                              icon: _isResending
                                                  ? const SizedBox.shrink()
                                                  : Icon(
                                                      Icons.refresh_rounded,
                                                      size: 18,
                                                      color: _canResend
                                                          ? const Color(
                                                              0xFF1B5E20)
                                                          : const Color(
                                                              0xFF9CA3AF),
                                                    ),
                                              label: _isResending
                                                  ? const SizedBox(
                                                      width: 18,
                                                      height: 18,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color:
                                                            Color(0xFF1B5E20),
                                                      ),
                                                    )
                                                  : Text(
                                                      _canResend
                                                          ? 'Resend Verification Email'
                                                          : 'Resend in ${_resendCooldown}s',
                                                      style: GoogleFonts
                                                          .poppins(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: _canResend
                                                            ? const Color(
                                                                0xFF1B5E20)
                                                            : const Color(
                                                                0xFF9CA3AF),
                                                        height: 1.2,
                                                      ),
                                                    ),
                                              style: OutlinedButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 16),
                                                side: BorderSide(
                                                  color: _canResend
                                                      ? const Color(0xFF1B5E20)
                                                      : const Color(0xFFE5E7EB),
                                                  width: 1.2,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 24),

                                    // Sign Out Option Footer
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Wrong email address? ',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            color: const Color(0xFF4B5563),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: _showSignOutDialog,
                                          child: Text(
                                            'Sign Out',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF1B5E20),
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 24),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
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

  Widget _buildFeedbackBanner() {
    Color bg;
    Color border;
    Color text;
    IconData icon;

    switch (_feedbackType) {
      case FeedbackType.success:
        bg = const Color(0xFFF0FDF4);
        border = const Color(0xFF86EFAC);
        text = const Color(0xFF15803D);
        icon = Icons.check_circle_rounded;
        break;
      case FeedbackType.warning:
        bg = const Color(0xFFFFFBEB);
        border = const Color(0xFFFDE68A);
        text = const Color(0xFFB45309);
        icon = Icons.warning_amber_rounded;
        break;
      case FeedbackType.error:
      default:
        bg = const Color(0xFFFEF2F2);
        border = const Color(0xFFFECACA);
        text = const Color(0xFFB91C1C);
        icon = Icons.error_outline_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: text),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _feedbackMessage ?? '',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Subtle Procedural Map Background Painter (Matches SignUpScreen exactly)
class MapLinesPainter extends CustomPainter {
  const MapLinesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 24
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dashPaint = Paint()
      ..color = const Color(0xFFE53935).withValues(alpha: 0.28)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final nodePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    // Major road curves
    final mainRoad = Path()
      ..moveTo(0, size.height * 0.18)
      ..cubicTo(
        size.width * 0.35,
        size.height * 0.12,
        size.width * 0.65,
        size.height * 0.30,
        size.width,
        size.height * 0.22,
      );
    canvas.drawPath(mainRoad, roadPaint);

    final crossRoad = Path()
      ..moveTo(size.width * 0.15, 0)
      ..lineTo(size.width * 0.90, size.height);
    canvas.drawPath(crossRoad, roadPaint);

    final secondaryRoad = Path()
      ..moveTo(size.width, size.height * 0.70)
      ..cubicTo(
        size.width * 0.50,
        size.height * 0.75,
        size.width * 0.20,
        size.height * 0.55,
        0,
        size.height * 0.85,
      );
    canvas.drawPath(secondaryRoad, roadPaint);

    // Dashed path
    final dashedPath = Path()
      ..moveTo(size.width * 0.20, size.height * 0.08)
      ..lineTo(size.width * 0.50, size.height * 0.42)
      ..lineTo(size.width * 0.82, size.height * 0.88);
    _drawDashedPath(canvas, dashedPath, dashPaint);

    // Waypoint nodes
    canvas.drawCircle(
      Offset(size.width * 0.20, size.height * 0.08),
      6,
      nodePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.50, size.height * 0.42),
      8,
      nodePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.88),
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
