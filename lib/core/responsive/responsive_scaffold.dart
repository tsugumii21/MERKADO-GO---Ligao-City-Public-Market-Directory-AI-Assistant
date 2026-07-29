import 'package:flutter/material.dart';
import 'responsive_breakpoints.dart';

/// Wraps page content with a centered max-width constraint on wider desktop screens.
class ResponsiveScaffold extends StatelessWidget {
  final Widget body;
  final double maxWidth;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;

  const ResponsiveScaffold({
    super.key,
    required this.body,
    this.maxWidth = 960,
    this.appBar,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isWebDesktop = AppBreakpoints.isDesktop(context);

    Widget content = body;
    if (isWebDesktop) {
      content = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: body,
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: appBar,
      body: content,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
