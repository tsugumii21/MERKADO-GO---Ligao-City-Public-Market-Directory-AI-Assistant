import 'package:flutter/material.dart';
import 'responsive_breakpoints.dart';

/// LayoutBuilder widget that dynamically returns different layouts based on screen width.
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppBreakpoints.tablet) {
          return desktop;
        } else if (constraints.maxWidth >= AppBreakpoints.mobile) {
          return tablet ?? desktop;
        } else {
          return mobile;
        }
      },
    );
  }
}
