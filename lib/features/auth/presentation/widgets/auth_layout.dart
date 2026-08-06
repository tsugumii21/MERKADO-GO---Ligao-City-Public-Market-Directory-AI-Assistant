import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/responsive/responsive_breakpoints.dart';

/// Responsive split-panel container for Auth screens (Login, Signup, GetStarted, ForgotPassword, EmailVerify).
/// On Mobile (<600px): Returns [mobileBody] as-is.
/// On Desktop (>=600px): Returns a split view with a flat emerald branding panel on the left
/// and a centered, width-constrained form container on the right.
///
/// The left panel displays a consistent [_BrandIconPanel] across all auth screens
/// instead of per-screen stock illustrations, ensuring visual cohesion.
class AuthLayout extends StatelessWidget {
  final Widget mobileBody;
  final Widget desktopFormContent;
  final String heroTitle;
  final String heroSubtitle;

  /// Optional override for the hero title widget on the left panel.
  /// When provided, replaces the default [Text] title — use this for
  /// screens that need custom typography (e.g. two-tone RichText on Get Started).
  /// All other screens leave this null and get the standard DM Sans heading.
  final Widget? heroTitleWidget;

  /// Path to a per-screen illustration asset to show on the left panel
  /// in place of the default rounded-square logo cluster.
  /// When null, the logo is shown (Get Started behaviour).
  final String? illustrationPath;

  /// The Material icon to display in the left-panel brand icon cluster.
  /// Each auth screen provides its own contextually appropriate icon.
  final IconData heroIcon;

  const AuthLayout({
    super.key,
    required this.mobileBody,
    required this.desktopFormContent,
    this.heroTitle = 'MERKADO GO',
    this.heroSubtitle = 'Your Ligao City Public Market Guide & Navigation Helper',
    this.heroIcon = Icons.storefront_rounded,
    this.heroTitleWidget,
    this.illustrationPath,
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
          // ── Left Hero Branding Panel ───────────────────────────────────
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

                  const SizedBox(height: 48),

                  // Brand Icon Cluster — shows per-screen illustration when provided,
                  // falls back to the rounded-square logo (Get Started default).
                  _BrandIconCluster(
                    icon: heroIcon,
                    illustrationPath: illustrationPath,
                  ),

                  const SizedBox(height: 48),

                  // Hero Title — uses heroTitleWidget override when provided (e.g. two-tone
                  // RichText on Get Started), otherwise falls back to DM Sans plain text.
                  heroTitleWidget ??
                      Text(
                        heroTitle,
                        style: GoogleFonts.dmSans(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),

                  const SizedBox(height: 12),

                  // Hero Subtitle — Poppins body
                  Text(
                    heroSubtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.85),
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // ── Right Form Panel ───────────────────────────────────────────
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

// ─── Design constants ──────────────────────────────────────────────────────────
// Illustration display sizes on the left panel (desktop only).
// Square illustrations (500×500 source) → 220×220 display.
// Landscape illustration (612×408 source) → unconstrained height, width 260,
// BoxFit.contain preserves aspect ratio.
const _kIllustrationSquareSize = 220.0;
const _kIllustrationLandscapeWidth = 260.0;
const _kLogoClusterSize = 160.0;
const _kLogoClusterRadius = 20.0;
const _kLogoPadding = 16.0;

/// Left-panel visual cluster.
/// Renders a per-screen [illustrationPath] image when provided;
/// falls back to the rounded-square app logo otherwise.
class _BrandIconCluster extends StatelessWidget {
  // icon parameter kept for API compatibility with all call sites
  // ignore: unused_field
  final IconData icon;

  /// Optional illustration asset path. When non-null the illustration is
  /// displayed instead of the logo. Square images are rendered at
  /// [_kIllustrationSquareSize]; landscape images at [_kIllustrationLandscapeWidth]
  /// with unconstrained height and BoxFit.contain.
  final String? illustrationPath;

  const _BrandIconCluster({
    required this.icon,
    this.illustrationPath,
  });

  @override
  Widget build(BuildContext context) {
    // ── Illustration mode ────────────────────────────────────────────────────
    if (illustrationPath != null) {
      // Detect landscape vs square by checking the known landscape asset path.
      // Only email_verification_illustration is landscape (612×408).
      final isLandscape = illustrationPath!.contains('email_verification');

      if (isLandscape) {
        return SizedBox(
          width: _kIllustrationLandscapeWidth,
          child: Image.asset(
            illustrationPath!,
            fit: BoxFit.contain,
          ),
        );
      }

      // Square illustrations (sign-in, signup, forgot_password) — 220×220.
      return SizedBox(
        width: _kIllustrationSquareSize,
        height: _kIllustrationSquareSize,
        child: Image.asset(
          illustrationPath!,
          fit: BoxFit.contain,
        ),
      );
    }

    // ── Logo mode (default — Get Started) ────────────────────────────────────
    return Container(
      width: _kLogoClusterSize,
      height: _kLogoClusterSize,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kLogoClusterRadius),
      ),
      padding: const EdgeInsets.all(_kLogoPadding),
      child: Image.asset(
        'assets/icons/MerkadoGo_Transparent Logo.png',
        fit: BoxFit.contain,
      ),
    );
  }
}
