import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/router/route_names.dart';
import 'widgets/auth_layout.dart';

// ─── Design constants (Rule 11) ───────────────────────────────────────────────
const _kLogoPath = 'assets/icons/MerkadoGo_Transparent Logo.png';
const _kPrimary = Color(0xFF1B5E20);
const _kRed = Color(0xFFE53935);
const _kInkMuted = Color(0xFF667066);
const _kLogoContainerSizeMobile = 120.0; // mobile single-column
const _kLogoContainerRadius = 20.0;
const _kButtonHeight = 56.0;
const _kButtonRadius = 12.0;

class GetStartedScreen extends StatelessWidget {
  const GetStartedScreen({super.key});

  // ── Shared: two-tone "Merkado Go" RichText ──────────────────────────────────
  // Replicates exact typography from splash_screen.dart.
  // [whiteVariant] = true → white "Merkado" (for green left panel)
  //                = false → brand-green "Merkado" (for white mobile bg)
  static Widget _buildBrandText({
    required bool whiteVariant,
    double fontSize = 36,
  }) {
    final merkadoColor = whiteVariant ? Colors.white : _kPrimary;

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        children: [
          TextSpan(
            text: 'Merkado',
            style: GoogleFonts.poppins(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: merkadoColor,
              letterSpacing: -0.5,
            ),
          ),
          TextSpan(
            text: 'Go',
            style: GoogleFonts.poppins(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: _kRed,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared: logo inside a white rounded-square container ────────────────────
  // White container ensures contrast on both green (desktop) and white (mobile) BGs.
  static Widget _buildLogoContainer({required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kLogoContainerRadius),
        boxShadow: const [], // flat — no elevation
      ),
      padding: const EdgeInsets.all(12),
      child: Image.asset(
        _kLogoPath,
        fit: BoxFit.contain,
      ),
    );
  }

  // ── Mobile view ─────────────────────────────────────────────────────────────
  Widget _buildMobileView(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 1),

              // Logo — white rounded-square container
              _buildLogoContainer(size: _kLogoContainerSizeMobile),

              const SizedBox(height: 28),

              // "MerkadoGo" two-tone — green/red on white background
              _buildBrandText(whiteVariant: false, fontSize: 32),

              const SizedBox(height: 8),

              // Subtitle
              Text(
                'Ligao City\'s market, simplified.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: _kInkMuted,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 1),

              // Primary CTA — Sign In
              SizedBox(
                width: double.infinity,
                height: _kButtonHeight,
                child: ElevatedButton(
                  onPressed: () => context.push(RouteNames.login),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_kButtonRadius),
                    ),
                  ),
                  child: Text(
                    'Sign In',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Secondary CTA — Create Account
              SizedBox(
                width: double.infinity,
                height: _kButtonHeight,
                child: OutlinedButton(
                  onPressed: () => context.push(RouteNames.signup),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kPrimary,
                    side: const BorderSide(color: _kPrimary, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_kButtonRadius),
                    ),
                  ),
                  child: Text(
                    'Create Account',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  // ── Desktop right-panel form content ────────────────────────────────────────
  Widget _buildDesktopForm(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // "MerkadoGo" two-tone — green/red on white right panel
        _buildBrandText(whiteVariant: false, fontSize: 28),

        const SizedBox(height: 6),

        Text(
          'Ligao City\'s market, simplified.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: _kInkMuted,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 40),

        // Primary CTA — Sign In
        SizedBox(
          width: double.infinity,
          height: _kButtonHeight,
          child: ElevatedButton(
            onPressed: () => context.push(RouteNames.login),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_kButtonRadius),
              ),
            ),
            child: Text(
              'Sign In',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Secondary CTA — Create Account
        SizedBox(
          width: double.infinity,
          height: _kButtonHeight,
          child: OutlinedButton(
            onPressed: () => context.push(RouteNames.signup),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kPrimary,
              side: const BorderSide(color: _kPrimary, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_kButtonRadius),
              ),
            ),
            child: Text(
              'Create Account',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  // ── Left-panel hero title override ──────────────────────────────────────────
  // Passed to AuthLayout.heroTitleWidget so only this screen gets two-tone text.
  // All other screens leave heroTitleWidget null → standard DM Sans title.
  static Widget _buildHeroTitleWidget() {
    return _buildBrandText(whiteVariant: true, fontSize: 32);
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      mobileBody: _buildMobileView(context),
      desktopFormContent: _buildDesktopForm(context),
      // heroTitle is unused when heroTitleWidget is provided — kept for fallback safety.
      heroTitle: 'MerkadoGo',
      // Custom two-tone title replaces the plain DM Sans text on the left panel.
      heroTitleWidget: _buildHeroTitleWidget(),
      // Subtitle uses the divider-line style from the splash screen.
      heroSubtitle: 'Your Ligao City Public Market Guide & Navigation Helper',
      // Logo is rendered via _BrandIconCluster in AuthLayout.
      // heroIcon is required by the constructor; it is unused visually since
      // _BrandIconCluster now renders Image.asset universally.
      heroIcon: Icons.storefront_rounded,
    );
  }
}
