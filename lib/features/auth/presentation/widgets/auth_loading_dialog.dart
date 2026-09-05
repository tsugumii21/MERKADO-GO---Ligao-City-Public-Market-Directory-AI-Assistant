import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/theme/app_colors.dart';
import '../../constants/auth_loading_phrases.dart';

/// Full-screen frosted-glass loading dialog displayed for 3 seconds after successful login.
/// Uses the map.json Lottie animation and rotating authentic market phrases.
class AuthLoadingDialog extends StatefulWidget {
  final String? userName;
  final VoidCallback onCompleted;

  const AuthLoadingDialog({
    super.key,
    this.userName,
    required this.onCompleted,
  });

  /// Displays the 3-second frosted auth loading screen
  static Future<void> show(
    BuildContext context, {
    String? userName,
  }) async {
    final completer = Completer<void>();

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogContext, _, __) {
        return AuthLoadingDialog(
          userName: userName,
          onCompleted: () {
            if (Navigator.of(dialogContext, rootNavigator: true).canPop()) {
              Navigator.of(dialogContext, rootNavigator: true).pop();
            }
            if (!completer.isCompleted) {
              completer.complete();
            }
          },
        );
      },
      transitionBuilder: (context, anim, _, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          child: child,
        );
      },
    );

    return completer.future;
  }

  @override
  State<AuthLoadingDialog> createState() => _AuthLoadingDialogState();
}

class _AuthLoadingDialogState extends State<AuthLoadingDialog> {
  Timer? _phraseTimer;
  Timer? _completionTimer;
  late String _currentPhrase;

  @override
  void initState() {
    super.initState();
    _currentPhrase = AuthLoadingPhrases.getRandomPhrase(
      userName: widget.userName,
    );

    // Rotate phrase at 1.5 seconds during the 3.0s transition
    _phraseTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _currentPhrase = AuthLoadingPhrases.getRandomPhrase(
            userName: widget.userName,
          );
        });
      }
    });

    // Complete transition after exactly 3.0 seconds
    _completionTimer = Timer(const Duration(milliseconds: 3000), () {
      if (mounted) {
        widget.onCompleted();
      }
    });
  }

  @override
  void dispose() {
    _phraseTimer?.cancel();
    _completionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Full-screen Frosted Glass Blur Overlay
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
                child: Container(
                  color: Colors.white.withValues(alpha: 0.68),
                ),
              ),
            ),

            // Centered Floating Animation & Welcome Typography
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Free-floating map.json Lottie Animation
                    SizedBox(
                      width: 250,
                      height: 200,
                      child: Lottie.asset(
                        'assets/animations/map.json',
                        fit: BoxFit.contain,
                        repeat: true,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(
                              Icons.map_rounded,
                              size: 72,
                              color: AppColors.primary,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Primary Title
                    Text(
                      widget.userName != null && widget.userName!.trim().isNotEmpty
                          ? 'Welcome Back, ${widget.userName!.trim()}!'
                          : 'Welcome Back!',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        letterSpacing: -0.4,
                      ),

                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // Market Tag
                    Text(
                      'Ligao City Public Market',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),

                    // Dynamic Rotating Market Phrase
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _currentPhrase,
                        key: ValueKey<String>(_currentPhrase),
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                          color: AppColors.inkMuted,
                          height: 1.35,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
