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
            'Ligao City Public Market',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.3,
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
    return Scaffold(
      backgroundColor: AppColors.primary,
      resizeToAvoidBottomInset: true,
      appBar: showBackButton
          ? AppBar(
              backgroundColor: AppColors.primary,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: onBack ??
                    () {
                      if (context.canPop()) {
                        context.pop();
                      }
                    },
              ),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      // ── Compact Mobile Brand Header (No duplicate titles) ──
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          showBackButton ? 0 : 16,
                          24,
                          16,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _BrandIconCluster(
                              icon: heroIcon,
                              illustrationPath: illustrationPath,
                              isMobile: true,
                            ),
                            const SizedBox(height: 10),
                            heroTitleWidget ??
                                Text(
                                  heroTitle,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                            if (heroTitleWidget != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                heroSubtitle,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white.withValues(alpha: 0.88),
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),

                      // ── Bottom Form Card (Soft Sage Dim Surface) ──
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceDim,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(24),
                              topRight: Radius.circular(24),
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
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
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
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
        width: iconSize,
        height: iconSize,
        fit: BoxFit.contain,
      ),
    );
  }
}
