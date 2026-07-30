import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/responsive/responsive_breakpoints.dart';

/// Responsive split-panel container for Auth screens (Login, Signup, GetStarted, ForgotPassword).
/// On Mobile (<600px): Returns [mobileBody] as-is.
/// On Desktop (>=600px): Returns a split view with a flat emerald branding panel on the left
/// and a centered, width-constrained form container on the right.
class AuthLayout extends StatelessWidget {
  final Widget mobileBody;
  final Widget desktopFormContent;
  final String heroTitle;
  final String heroSubtitle;
  final String? illustrationPath;

  const AuthLayout({
    super.key,
    required this.mobileBody,
    required this.desktopFormContent,
    this.heroTitle = 'MERKADO GO',
    this.heroSubtitle = 'Your Ligao City Public Market Guide & Navigation Helper',
    this.illustrationPath = 'assets/images/onboarding_illustration.png',
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= AppBreakpoints.mobile;

    if (!isDesktop) {
      return mobileBody;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // Left Hero Branding Panel (Desktop — Flat Solid Emerald)
          Expanded(
            flex: 5,
            child: Container(
              color: const Color(0xFF1B5E20),
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 64),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Location Pill Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'LIGAO CITY PUBLIC MARKET',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Illustration (Clean borderless, NO dark box shadow)
                  if (illustrationPath != null)
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 380),
                        child: Image.asset(
                          illustrationPath!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 280,
                            width: 380,
                            color: Colors.white.withValues(alpha: 0.1),
                            child: const Icon(
                              Icons.storefront_rounded,
                              size: 100,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Hero Title
                  Text(
                    heroTitle,
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 12),

                  // Hero Subtitle
                  Text(
                    heroSubtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.85),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // Right Form Panel (Desktop)
          Expanded(
            flex: 6,
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: desktopFormContent,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
