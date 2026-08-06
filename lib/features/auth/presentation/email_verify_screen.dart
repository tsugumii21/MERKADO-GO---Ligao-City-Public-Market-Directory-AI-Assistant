import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../../../core/router/route_names.dart';
import '../../../providers/auth_provider.dart';
import 'widgets/auth_layout.dart';

class EmailVerifyScreen extends ConsumerStatefulWidget {
  const EmailVerifyScreen({super.key});

  @override
  ConsumerState<EmailVerifyScreen> createState() => _EmailVerifyScreenState();
}

class _EmailVerifyScreenState extends ConsumerState<EmailVerifyScreen>
    with SingleTickerProviderStateMixin {
  bool _isCheckingVerification = false;
  bool _canResend = true;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;
  String? _feedbackMessage;
  FeedbackType? _feedbackType;

  // Single animation controller — purposeful state-change entry only.
  // Continuous pulse removed (decorative — violates motion rules).
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

    // Fade-in communicates: "this screen has loaded" — purposeful state change.
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

  /// The form content shown on the right panel (desktop) and in the
  /// single-column mobile view.
  Widget _buildFormContent(BuildContext context) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    final email = user?.email ?? 'your email';

    return FadeTransition(
      opacity: _contentOpacity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Brand icon — mobile only (desktop uses left panel)
          // Displayed inline in mobile single-column layout
          const _MobileVerifyIcon(),

          const SizedBox(height: 32),

          // Heading — DM Sans display font, ink colour (not brand emerald)
          Text(
            'Check Your Email',
            style: GoogleFonts.dmSans(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A241A),
              letterSpacing: -0.5,
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

          // Primary Button — flat solid, no gradient, no shadow (matches all other screens)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isCheckingVerification ? null : _checkEmailVerified,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: const Color(0xFF1B5E20).withValues(alpha: 0.6),
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
            const SizedBox(height: 14),
            _buildFeedbackContainer(),
          ],

          const SizedBox(height: 14),

          // Resend Button — text label swaps to communicate cooldown state (no animation)
          TextButton(
            onPressed: _canResend ? _resendVerificationEmail : null,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _canResend ? Icons.refresh_rounded : Icons.timer_outlined,
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

          Center(
            child: SizedBox(
              width: 200,
              child: const Divider(
                color: Color(0xFFEEEEEE),
                height: 1,
                thickness: 1,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Wrong email section
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

          Center(
            child: TextButton(
              onPressed: _showSignOutDialog,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      heroIcon: Icons.mark_email_read_outlined,
      heroTitle: 'Verify Email',
      heroSubtitle: 'One last step — confirm your email address to activate your account.',
      mobileBody: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
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
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: _buildFormContent(context),
          ),
        ),
      ),
      desktopFormContent: _buildFormContent(context),
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
          color: textColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 20),
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

/// Brand icon shown at the top of the mobile single-column layout only.
/// On desktop, this role is filled by the left-panel `_BrandIconCluster` in `AuthLayout`.
class _MobileVerifyIcon extends StatelessWidget {
  const _MobileVerifyIcon();

  @override
  Widget build(BuildContext context) {
    // On desktop, AuthLayout provides the left panel — we don't render the icon.
    // On mobile, this widget is visible inside the scrollable Scaffold body.
    final isDesktop =
        MediaQuery.sizeOf(context).width >= 600;
    if (isDesktop) return const SizedBox.shrink();

    return Center(
      child: Container(
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
    );
  }
}

enum FeedbackType {
  success,
  warning,
  error,
}
