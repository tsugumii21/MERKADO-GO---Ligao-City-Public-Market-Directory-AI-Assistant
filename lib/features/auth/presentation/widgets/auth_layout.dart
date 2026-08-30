import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/responsive/responsive_breakpoints.dart';
import '../../../../core/theme/app_colors.dart';

/// Unified AuthLayout for all authentication screens with responsive mobile adaptation:
/// - Desktop (>=600px): 50/50 horizontal split with Forest Green hero panel ([AppColors.primary])
///   on the left and soft sage green form panel ([AppColors.surfaceDim]) on the right.
/// - Mobile (<600px): Compact Forest Green hero header ([AppColors.primary], ~120-140px)
///   with a single clear title and compact icon, transitioning into a soft sage form card ([AppColors.surfaceDim]).
class AuthLayout extends StatelessWidget {
  final Widget formContent;
  final String heroTitle;
  final String heroSubtitle;
  final Widget? heroTitleWidget;
  final String? illustrationPath;
  final IconData heroIcon;
  final bool showBackButton;
  final VoidCallback? onBack;

  const AuthLayout({
    super.key,
    required this.formContent,
    this.heroTitle = 'MERKADO GO',
    this.heroSubtitle = 'Your Ligao City Public Market Guide & Navigation Helper',
    this.heroIcon = Icons.storefront_rounded,
    this.heroTitleWidget,
    this.illustrationPath,
    this.showBackButton = true,
    this.onBack,
  });

  // ── Desktop Left Hero Elements ──────────────────────────────────────────────

  Widget _buildDesktopLocationPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
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
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            'Ligao City Public Market',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 24,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.35),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.35),
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }

  // ── Desktop 50/50 Layout ────────────────────────────────────────────────────

  Widget _buildDesktopView(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDim,
      body: Row(
        children: [
          // ── Left Hero Panel (Deep Forest Green) ──
          Expanded(
            flex: 5,
            child: Container(
              color: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildDesktopLocationPill(),
                      const SizedBox(height: 36),
                      _BrandIconCluster(
                        icon: heroIcon,
                        illustrationPath: illustrationPath,
                        isMobile: false,
                      ),
                      const SizedBox(height: 36),
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
                      const SizedBox(height: 14),
                      Text(
                        heroSubtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.88),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 36),
                      _buildDesktopProgressDots(),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Right Form Panel (Soft Sage Green Surface) ──
          Expanded(
            flex: 6,
            child: Container(
              color: AppColors.surfaceDim,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
              child: Center(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: formContent,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Mobile Compact Header + Form Card Layout ────────────────────────────────

  Widget _buildMobileView(BuildContext context) {
    final isGetStarted = heroTitleWidget != null && !showBackButton;

    if (isGetStarted) {
      return Scaffold(
        backgroundColor: AppColors.primary,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ── Get Started Hero Section (Expands to center & ground brand elements) ──
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildDesktopLocationPill(),
                        const SizedBox(height: 16),
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.4),
                              width: 1.2,
                            ),
                          ),
                          padding: const EdgeInsets.all(10),
                          child: Image.asset(
                            'assets/icons/MerkadoGo_Transparent Logo.png',
                            cacheWidth: 200,
                            cacheHeight: 200,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 14),
                        heroTitleWidget!,
                        const SizedBox(height: 8),
                        Text(
                          heroSubtitle,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        _buildDesktopProgressDots(),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Get Started Action Card (Snug content sizing, no forced empty height) ──
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceDim,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: SafeArea(
                  top: false,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: formContent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Modern Compact Vertically-Centered Auth Sub-Screen ──
    return Scaffold(
      backgroundColor: AppColors.surfaceDim,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: 48x48 Back Button
            if (showBackButton)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, top: 8),
                  child: Semantics(
                    button: true,
                    label: 'Back',
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: onBack ??
                            () {
                              if (context.canPop()) {
                                context.pop();
                              }
                            },
                        child: Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.border,
                                width: 1,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: AppColors.ink,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: 16),

            // Centered Form Content Column (No bottom dead space)
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Brand Icon
                        Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.border,
                                width: 1.2,
                              ),
                            ),
                            padding: const EdgeInsets.all(8),
                            child: Image.asset(
                              'assets/icons/MerkadoGo_Transparent Logo.png',
                              cacheWidth: 200,
                              cacheHeight: 200,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Title
                        Text(
                          heroTitle,
                          style: GoogleFonts.dmSans(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                            letterSpacing: -0.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (heroSubtitle.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            heroSubtitle,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: AppColors.inkMuted,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 24),

                        // Form Fields, Buttons & Links
                        formContent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= AppBreakpoints.mobile;

    if (isDesktop) {
      return _buildDesktopView(context);
    }
    return _buildMobileView(context);
  }
}

// ─── Design Constants & Icon Cluster ──────────────────────────────────────────

const _kIllustrationSquareSize = 200.0;
const _kIllustrationLandscapeWidth = 240.0;
const _kLogoClusterSize = 140.0;
const _kLogoClusterRadius = 20.0;

class _BrandIconCluster extends StatelessWidget {
  final IconData icon;
  final String? illustrationPath;
  final bool isMobile;

  const _BrandIconCluster({
    required this.icon,
    this.illustrationPath,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    // Compact mobile icon size: 48px square container
    final containerSize = isMobile ? 48.0 : _kLogoClusterSize;
    final iconSize = isMobile ? 36.0 : 56.0;

    if (illustrationPath != null) {
      final isLandscape = illustrationPath!.contains('email_verification');

      if (isLandscape) {
        return SizedBox(
          width: isMobile ? 120.0 : _kIllustrationLandscapeWidth,
          child: Image.asset(
            illustrationPath!,
            fit: BoxFit.contain,
          ),
        );
      }

      return SizedBox(
        width: isMobile ? 64.0 : _kIllustrationSquareSize,
        height: isMobile ? 64.0 : _kIllustrationSquareSize,
        child: Image.asset(
          illustrationPath!,
          fit: BoxFit.contain,
        ),
      );
    }

    // App Logo Container
    return Container(
      width: containerSize,
      height: containerSize,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 12 : _kLogoClusterRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      padding: EdgeInsets.all(isMobile ? 4 : 14),
      child: Image.asset(
        'assets/icons/MerkadoGo_Transparent Logo.png',
        cacheWidth: 200,
        cacheHeight: 200,
        width: iconSize,
        height: iconSize,
        fit: BoxFit.contain,
      ),
    );
  }
}
