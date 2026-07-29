import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/responsive/responsive_breakpoints.dart';

/// Responsive split-panel container for Auth screens (Login, Signup, GetStarted).
/// On Mobile (<600px): Returns [mobileBody] as-is.
/// On Desktop (>=600px): Returns a split view with a hero branding panel on the left
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
          // Left Hero Branding Panel (Desktop)
          Expanded(
            flex: 5,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (illustrationPath != null)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 320),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          illustrationPath!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 240,
                            width: 320,
                            color: Colors.white12,
                            child: const Icon(
                              Icons.storefront_rounded,
                              size: 80,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 36),
                  Text(
                    heroTitle,
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    heroSubtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: Colors.white70,
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
                    constraints: const BoxConstraints(maxWidth: 460),
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
