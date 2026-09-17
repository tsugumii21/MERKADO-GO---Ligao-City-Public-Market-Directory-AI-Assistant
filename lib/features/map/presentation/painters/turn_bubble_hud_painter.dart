import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Renders the floating, upright Speech Bubble HUD directly above the avatar's cap.
/// Features dynamic pill width, downward triangular pointer tail, and vector arrival pin icon.
class TurnBubbleHudPainter extends CustomPainter {
  final String text;
  final bool isArrival;

  const TurnBubbleHudPainter({
    required this.text,
    this.isArrival = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textSpan = TextSpan(
      text: text,
      style: const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1B5E20),
        letterSpacing: 0.2,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    // Compute dynamic width clamped with minimum 72px
    final double contentWidth =
        isArrival ? (textPainter.width + 36.0) : (textPainter.width + 24.0);
    final double pillWidth = math.max(72.0, math.min(contentWidth, 160.0));
    const double pillHeight = 24.0;
    const double bubbleY = -41.0; // Anchored above the cap button (y = -24.2)

    final bubbleRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: const Offset(0, bubbleY),
        width: pillWidth,
        height: pillHeight,
      ),
      const Radius.circular(12.0),
    );

    // 1. Drop shadow
    canvas.drawShadow(
      Path()..addRRect(bubbleRRect),
      Colors.black.withValues(alpha: 0.25),
      3.0,
      false,
    );

    // 2. White pill background & 1.5px hairline border
    canvas.drawRRect(bubbleRRect, Paint()..color = Colors.white);
    canvas.drawRRect(
      bubbleRRect,
      Paint()
        ..color = const Color(0xFF1B5E20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // 3. Downward triangular pointer tail pointing at cap button
    final tailPath = Path()
      ..moveTo(-4, bubbleY + pillHeight / 2)
      ..lineTo(4, bubbleY + pillHeight / 2)
      ..lineTo(0, bubbleY + pillHeight / 2 + 5.0)
      ..close();
    canvas.drawPath(tailPath, Paint()..color = const Color(0xFF1B5E20));

    // 4. Vector Destination Pin Icon (Arrival state only - zero unicode emojis!)
    double textOffsetX = -textPainter.width / 2;
    if (isArrival) {
      textOffsetX += 8.0;
      final pinCenter = Offset(-pillWidth / 2 + 14.0, bubbleY);
      // Red teardrop pin
      final Path pinPath = Path()
        ..moveTo(pinCenter.dx, pinCenter.dy - 6)
        ..cubicTo(
          pinCenter.dx - 4,
          pinCenter.dy - 6,
          pinCenter.dx - 4,
          pinCenter.dy - 1,
          pinCenter.dx,
          pinCenter.dy + 4,
        )
        ..cubicTo(
          pinCenter.dx + 4,
          pinCenter.dy - 1,
          pinCenter.dx + 4,
          pinCenter.dy - 6,
          pinCenter.dx,
          pinCenter.dy - 6,
        )
        ..close();
      canvas.drawPath(pinPath, Paint()..color = const Color(0xFFE53935));
      // Inner white center dot
      canvas.drawCircle(
        Offset(pinCenter.dx, pinCenter.dy - 3),
        1.2,
        Paint()..color = Colors.white,
      );
    }

    // 5. Text paint
    textPainter.paint(
      canvas,
      Offset(textOffsetX, bubbleY - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant TurnBubbleHudPainter oldDelegate) =>
      oldDelegate.text != text || oldDelegate.isArrival != isArrival;
}
