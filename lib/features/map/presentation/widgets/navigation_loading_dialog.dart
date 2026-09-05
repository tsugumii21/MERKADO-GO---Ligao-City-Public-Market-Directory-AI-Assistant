import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/navigation_models.dart';
import '../../constants/navigation_phrases.dart';

/// Full-screen overlay dialog with road_trip Lottie animation and dynamic phrases
class NavigationLoadingDialog extends StatefulWidget {
  final String stallName;
  final MarketEntryPoint entrance;
  final VoidCallback onCompleted;

  const NavigationLoadingDialog({
    super.key,
    required this.stallName,
    required this.entrance,
    required this.onCompleted,
  });

  /// Displays the 2-second navigation loading screen
  static Future<void> show(
    BuildContext context, {
    required String stallName,
    required MarketEntryPoint entrance,
  }) async {
    final completer = Completer<void>();

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogContext, _, __) {
        return NavigationLoadingDialog(
          stallName: stallName,
          entrance: entrance,
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
  State<NavigationLoadingDialog> createState() => _NavigationLoadingDialogState();
}

class _NavigationLoadingDialogState extends State<NavigationLoadingDialog> {
  Timer? _phraseTimer;
  Timer? _completionTimer;
  late String _currentPhrase;

  @override
  void initState() {
    super.initState();
    _currentPhrase = NavigationPhrases.getRandomPhrase(
      stallName: widget.stallName,
      entranceName: 'Gate ${widget.entrance.entranceId}',
    );

    // Rotate phrase halfway through 2-second transition
    _phraseTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _currentPhrase = NavigationPhrases.getRandomPhrase(
            stallName: widget.stallName,
            entranceName: 'Gate ${widget.entrance.entranceId}',
          );
        });
      }
    });

    // Complete exactly after 2.0 seconds
    _completionTimer = Timer(const Duration(milliseconds: 2000), () {
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

            // Centered Floating Animation & Navigation Typography
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Free-floating Road Trip Lottie Animation
                    SizedBox(
                      width: 260,
                      height: 190,
                      child: Lottie.asset(
                        'assets/animations/road_trip.json',
                        fit: BoxFit.contain,
                        repeat: true,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(
                              Icons.directions_walk_rounded,
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
                      'Directing to ${widget.stallName}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        letterSpacing: -0.3,
                      ),
                      textAlign: TextAlign.center,

                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // Gate to Stall Route Tag
                    Text(
                      'Gate ${widget.entrance.entranceId}  →  ${widget.stallName}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),

                    // Dynamic Rotating Wayfinding Phrase
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
