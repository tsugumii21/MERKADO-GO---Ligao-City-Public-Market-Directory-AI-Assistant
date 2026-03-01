import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../../../core/router/route_names.dart';
import '../../../providers/auth_provider.dart';

class EmailVerifyScreen extends ConsumerStatefulWidget {
  const EmailVerifyScreen({super.key});

  @override
  ConsumerState<EmailVerifyScreen> createState() => _EmailVerifyScreenState();
}

class _EmailVerifyScreenState extends ConsumerState<EmailVerifyScreen>
    with TickerProviderStateMixin {
  bool _isCheckingVerification = false;
  bool _canResend = true;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;
  String? _feedbackMessage;
  FeedbackType? _feedbackType;

  late AnimationController _iconController;
  late AnimationController _contentController;
  late AnimationController _buttonController;
  late AnimationController _pulseController;

  late Animation<double> _iconScale;
  late Animation<double> _iconOpacity;

  late Animation<double> _contentOpacity;
  late Animation<Offset> _contentSlide;

  late Animation<double> _buttonOpacity;
  late Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();

    // Icon animation
    _iconController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _iconScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.elasticOut),
    );
    _iconOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.easeOut),
    );

    // Content animation
    _contentController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _contentOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOutCubic),
    );
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOutCubic),
    );

    // Button animation
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _buttonOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeIn),
    );

    // Pulse animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start animations in sequence
    _iconController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _contentController.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _buttonController.forward();
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _iconController.dispose();
    _contentController.dispose();
    _buttonController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkEmailVerified() async {
    setState(() {
      _isCheckingVerification = true;
      _feedbackMessage = null;
      _feedbackType = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final isVerified = await authRepo.checkEmailVerified();

      if (mounted) {
        if (isVerified) {
          setState(() {
            _feedbackMessage = 'Email verified! Redirecting...';
            _feedbackType = FeedbackType.success;
          });
          await Future.delayed(const Duration(milliseconds: 800));
          if (mounted) {
            context.go(RouteNames.home);
          }
        } else {
          setState(() {
            _feedbackMessage = 'Email not verified yet. Please check your inbox.';
            _feedbackType = FeedbackType.warning;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _feedbackMessage = 'Error checking verification status. Please try again.';
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
    if (!_canResend) return;

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.sendVerificationEmail();

      if (mounted) {
        setState(() {
          _feedbackMessage = 'Verification email sent! Please check your inbox.';
          _feedbackType = FeedbackType.success;
        });
        _startCooldown();
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _feedbackMessage = null;
              _feedbackType = null;
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _feedbackMessage = 'Failed to send email. Please try again.';
          _feedbackType = FeedbackType.error;
        });
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
    final email = user?.email ?? 'your email';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Verify Email',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1B5E20),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Illustration Section
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.35,
                child: Center(
                  child: FadeTransition(
                    opacity: _iconOpacity,
                    child: ScaleTransition(
                      scale: _iconScale,
                      child: Image.asset(
                        'assets/images/email_verification_illustration.png',
                        height: 240,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),

                  // Content Section
                  FadeTransition(
                    opacity: _contentOpacity,
                    child: SlideTransition(
                      position: _contentSlide,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          children: [
                            const SizedBox(height: 32),

                            // Title
                            Text(
                              'Check Your Email!',
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1B5E20),
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 10),

                            // Subtitle
                            Text(
                              'We sent a verification link to',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF757575),
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 8),

                            // Email Address Box
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F8E9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFA5D6A7),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                email,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF2E7D32),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Description
                            Text(
                              'Please check your inbox and spam folder,\nthen click the verification link.',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF9E9E9E),
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Buttons Section
                  FadeTransition(
                    opacity: _buttonOpacity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        children: [
                          // Primary Button
                          Container(
                            width: double.infinity,
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF2E7D32),
                                  Color(0xFF1B5E20),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x401B5E20),
                                  blurRadius: 12,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isCheckingVerification
                                  ? null
                                  : _checkEmailVerified,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isCheckingVerification
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      'I Have Verified My Email',
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),

                          // Feedback Message
                          if (_feedbackMessage != null) ...[
                            const SizedBox(height: 16),
                            _buildFeedbackContainer(),
                          ],

                          const SizedBox(height: 16),

                          // Resend Button
                          TextButton(
                            onPressed: _canResend
                                ? _resendVerificationEmail
                                : null,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _canResend
                                      ? Icons.refresh_rounded
                                      : Icons.timer_outlined,
                                  size: 16,
                                  color: _canResend
                                      ? const Color(0xFF1B5E20)
                                      : const Color(0xFF9E9E9E),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _canResend
                                      ? 'Resend Verification Email'
                                      : 'Resend in ${_resendCooldown}s',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: _canResend
                                        ? const Color(0xFF1B5E20)
                                        : const Color(0xFF9E9E9E),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Divider
                          Center(
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width * 0.6,
                              child: const Divider(
                                color: Color(0xFFEEEEEE),
                                height: 1,
                                thickness: 1,
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Wrong Email Section
                          Text(
                            'Wrong email address?',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF9E9E9E),
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 8),

                          TextButton(
                            onPressed: _showSignOutDialog,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                            ),
                            child: Text(
                              'Sign Out and Try Again',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1B5E20),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildFeedbackContainer() {
    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (_feedbackType) {
      case FeedbackType.success:
        backgroundColor = const Color(0xFFE8F5E9);
        textColor = const Color(0xFF2E7D32);
        icon = Icons.check_circle_outline_rounded;
        break;
      case FeedbackType.warning:
        backgroundColor = const Color(0xFFFFF8E1);
        textColor = const Color(0xFFE65100);
        icon = Icons.warning_amber_rounded;
        break;
      case FeedbackType.error:
        backgroundColor = const Color(0xFFFFEBEE);
        textColor = const Color(0xFFB71C1C);
        icon = Icons.error_outline_rounded;
        break;
      default:
        backgroundColor = const Color(0xFFE8F5E9);
        textColor = const Color(0xFF2E7D32);
        icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: textColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: textColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _feedbackMessage!,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum FeedbackType {
  success,
  warning,
  error,
}
