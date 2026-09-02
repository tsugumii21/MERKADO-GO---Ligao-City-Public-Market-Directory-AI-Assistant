import 'package:flutter/material.dart';
import '../constants/market_categories.dart';

/// Custom Painter for a raw butcher cut / pork chop with bone marrow
class RawMeatPainter extends CustomPainter {
  final Color color;

  const RawMeatPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Steak / Pork chop meat silhouette
    final path = Path();
    path.moveTo(w * 0.28, h * 0.15);
    // top curve
    path.cubicTo(w * 0.45, h * 0.08, w * 0.72, h * 0.10, w * 0.85, h * 0.25);
    // right curve
    path.cubicTo(w * 0.98, h * 0.40, w * 0.95, h * 0.65, w * 0.80, h * 0.82);
    // bottom curve
    path.cubicTo(w * 0.65, h * 0.95, w * 0.40, h * 0.92, w * 0.22, h * 0.80);
    // left indentation & tail
    path.cubicTo(w * 0.08, h * 0.70, w * 0.05, h * 0.45, w * 0.15, h * 0.30);
    path.cubicTo(w * 0.18, h * 0.22, w * 0.22, h * 0.18, w * 0.28, h * 0.15);
    path.close();

    canvas.drawPath(path, paint);

    // Bone outline / marrow ring
    final bonePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawCircle(Offset(w * 0.44, h * 0.45), w * 0.12, bonePaint);

    final marrowPaint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(Offset(w * 0.44, h * 0.45), w * 0.055, marrowPaint);
  }

  @override
  bool shouldRepaint(covariant RawMeatPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Unified Category Icon widget that handles custom vector illustrations (e.g. Raw Meat/Pork)
/// and standard Material icons for all other 16 market categories.
class MarketCategoryIcon extends StatelessWidget {
  final String category;
  final IconData? fallbackIcon;
  final double size;
  final Color? color;

  const MarketCategoryIcon({
    super.key,
    required this.category,
    this.fallbackIcon,
    this.size = 20,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final catLower = category.trim().toLowerCase();
    final isMeat = catLower == 'meat' ||
        catLower == 'meat (pork & beef)' ||
        (catLower.contains('pork') && !catLower.contains('bbq')) ||
        (catLower.contains('beef') && !catLower.contains('bbq')) ||
        catLower == 'baboy' ||
        catLower == 'orig' ||
        catLower == 'karneng urig';

    final effectiveColor =
        color ?? MarketCategories.getVisuals(category).outline;

    if (isMeat) {
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          size: Size(size, size),
          painter: RawMeatPainter(color: effectiveColor),
        ),
      );
    }

    final iconData =
        fallbackIcon ?? MarketCategories.getVisuals(category).icon;
    return Icon(
      iconData,
      size: size,
      color: effectiveColor,
    );
  }
}
