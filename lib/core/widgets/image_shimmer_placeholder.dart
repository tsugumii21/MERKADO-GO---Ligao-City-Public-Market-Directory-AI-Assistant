import 'package:flutter/material.dart';

/// Lightweight, high-performance shimmer placeholder for image loading states.
class ImageShimmerPlaceholder extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? baseColor;
  final Color? highlightColor;
  final IconData? centerIcon;

  const ImageShimmerPlaceholder({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.baseColor,
    this.highlightColor,
    this.centerIcon,
  });

  @override
  State<ImageShimmerPlaceholder> createState() => _ImageShimmerPlaceholderState();
}

class _ImageShimmerPlaceholderState extends State<ImageShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.baseColor ?? const Color(0xFFF1F5F9);
    final highlight = widget.highlightColor ?? const Color(0xFFE2E8F0);
    final prefersReducedMotion = MediaQuery.of(context).disableAnimations;

    Widget content = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: prefersReducedMotion
                ? LinearGradient(colors: [base, base])
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: [
                      (_controller.value - 0.3).clamp(0.0, 1.0),
                      _controller.value,
                      (_controller.value + 0.3).clamp(0.0, 1.0),
                    ],
                    colors: [
                      base,
                      highlight,
                      base,
                    ],
                  ),
          ),
          child: widget.centerIcon != null
              ? Center(
                  child: Icon(
                    widget.centerIcon,
                    size: 32,
                    color: const Color(0xFFCBD5E1),
                  ),
                )
              : null,
        );
      },
    );

    if (widget.borderRadius != null) {
      content = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: content,
      );
    }

    return content;
  }
}
