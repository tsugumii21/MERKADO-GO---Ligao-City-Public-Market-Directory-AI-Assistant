import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import 'widgets/auth_layout.dart';

/// GetStartedScreen immersed in the cohesive green theme via AuthLayout.
class GetStartedScreen extends StatelessWidget {
  const GetStartedScreen({super.key});

  /// Action form (Headings, Primary CTA, Secondary CTA, Terms Caption).
  Widget _buildActionsForm(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isDesktop) ...[
          Text(
            'Welcome to MerkadoGo',
            style: GoogleFonts.dmSans(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
        ],

        // Subheading
        Text(
          'Sign in or create an account to continue',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.inkMuted,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Primary Button — Sign In
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () => context.push(RouteNames.login),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              'Sign in',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Secondary Button — Create Account
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: () => context.push(RouteNames.signup),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              backgroundColor: Colors.white,
              side: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              'Create account',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Terms Caption
        Text(
          'By continuing you agree to our terms',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppColors.inkSubtle,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      showBackButton: false,
      heroTitleWidget: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          children: [
            TextSpan(
              text: 'Merkado',
              style: GoogleFonts.poppins(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            TextSpan(
              text: 'Go',
              style: GoogleFonts.poppins(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: AppColors.error,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
      heroSubtitle:
          'Your guide to Ligao City Public Market — stalls, hours, and directions in one place.',
      formContent: _buildActionsForm(context),
    );
  }
}
