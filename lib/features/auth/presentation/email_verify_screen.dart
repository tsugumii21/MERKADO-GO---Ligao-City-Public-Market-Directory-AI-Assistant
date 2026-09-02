import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/router/route_names.dart';
import '../../../providers/auth_provider.dart';

/// Feedback types for verification actions
enum FeedbackType { success, warning, error }

/// Modern Email Verification Screen for Merkado Go
class EmailVerifyScreen extends ConsumerStatefulWidget {
  const EmailVerifyScreen({super.key});

  @override
  ConsumerState<EmailVerifyScreen> createState() => _EmailVerifyScreenState();
}

class _EmailVerifyScreenState extends ConsumerState<EmailVerifyScreen> {
  bool _isCheckingVerification = false;
  bool _isResending = false;
  bool _canResend = true;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;
  String? _feedbackMessage;
  FeedbackType? _feedbackType;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
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
          'You will be signed out and can register or sign in with a different email.',
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
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Top Hero Header Layer (Top 38% of screen)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: screenHeight * 0.38,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/email_verification_hero.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Image.asset(
                    'assets/images/email_verification_illustration.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Image.asset(
                      'assets/images/public_market.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFF1B5E20),
                        child: const Center(
                          child: Icon(Icons.mark_email_read_rounded, size: 80, color: Colors.white24),
                        ),
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
                // Top-left Back button inside frosted circular container
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
                          onTap: _showSignOutDialog,
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
            top: screenHeight * 0.33,
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

                      // Title: "Verify Your Email" & "Activate Your Account"
                      Text(
                        'Verify Your Email',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E293B),
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Activate Your Account',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1B5E20), // Ligao Green
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Subtitle
                      Text(
                        'We sent a verification link to:',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Email Pill Box
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFF86EFAC),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
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
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF15803D),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Subtitle helper
                      Text(
                        'Please check your inbox and spam folder, then click the link to confirm.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          color: const Color(0xFF94A3B8),
                          height: 1.45,
                        ),
                      ),

                      if (_feedbackMessage != null) ...[
                        const SizedBox(height: 16),
                        _buildFeedbackBanner(),
                      ],

                      const SizedBox(height: 22),

                      // Primary CTA: "I Have Verified My Email"
                      ElevatedButton(
                        onPressed: _isCheckingVerification ? null : _checkEmailVerified,
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
                        child: _isCheckingVerification
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'I Have Verified My Email',
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 12),

                      // Secondary CTA: Resend Button with Cooldown
                      OutlinedButton.icon(
                        onPressed: _canResend ? _resendVerificationEmail : null,
                        icon: _isResending
                            ? const SizedBox.shrink()
                            : Icon(
                                Icons.refresh_rounded,
                                size: 18,
                                color: _canResend
                                    ? const Color(0xFF1B5E20)
                                    : const Color(0xFF9CA3AF),
                              ),
                        label: _isResending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF1B5E20),
                                ),
                              )
                            : Text(
                                _canResend
                                    ? 'Resend Verification Email'
                                    : 'Resend in ${_resendCooldown}s',
                                style: GoogleFonts.poppins(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: _canResend
                                      ? const Color(0xFF1B5E20)
                                      : const Color(0xFF9CA3AF),
                                ),
                              ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          side: BorderSide(
                            color: _canResend
                                ? const Color(0xFF1B5E20)
                                : const Color(0xFFE2E8F0),
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Sign Out Option Footer
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Wrong email address? ',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          GestureDetector(
                            onTap: _showSignOutDialog,
                            child: Text(
                              'Sign Out',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1B5E20),
                                decoration: TextDecoration.underline,
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

