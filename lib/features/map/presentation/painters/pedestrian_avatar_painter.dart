import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Articulated Civic Shopper Vector Painter for MerkadoGO Map
/// Faithfully reproduces the SVG walking pedestrian avatar with exact geometries,
/// tailored civic polo, market tote bag (bayong), shoes, and dual-mode waving arm.
class PedestrianAvatarPainter extends CustomPainter {
  final double walkCycleProgress; // 0.0 to 1.0 (repeating stride cycle)
  final double arrivalHopProgress; // 0.0 to 1.0 (arrival celebration hop)
  final double waveProgress; // 0.0 to 1.0 (waving arm oscillation)
  final bool isArrived;
  final double facingSign; // +1.0 = Facing Right, -1.0 = Facing Left
  final double scale; // Default 1.8 to 2.2 on mobile

  const PedestrianAvatarPainter({
    required this.walkCycleProgress,
    required this.arrivalHopProgress,
    required this.waveProgress,
    required this.isArrived,
    this.facingSign = 1.0,
    this.scale = 1.8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // Scale container with directional facing
    canvas.scale(facingSign * scale, scale);

    // 1. Soft glowing aura underneath
    final haloPaint = Paint()
      ..color = const Color(0xFF1B5E20).withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(0, -2), 24.0, haloPaint);

    // 2. Dynamic ground contact shadow
    // Shadow pulses in opposition to stride rhythm
    final double stridePhase = walkCycleProgress * 2 * math.pi;
    final double shadowScale = isArrived ? 1.0 : (1.0 + 0.12 * math.cos(stridePhase * 2));
    final shadowPaint = Paint()
      ..color = const Color(0x3F144618)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, 15.5),
        width: 26.0 * shadowScale,
        height: 9.0 * shadowScale,
      ),
      shadowPaint,
    );

    // Torso Bobbing / Arrival Hop calculation
    double bobY = 0.0;
    if (isArrived) {
      // 0.7s arrival hop curve: 0% -> 35% (-6px) -> 70% (-2px) -> 100% (0px)
      final double t = arrivalHopProgress.clamp(0.0, 1.0);
      if (t < 0.35) {
        bobY = -6.0 * math.sin((t / 0.35) * (math.pi / 2));
      } else if (t < 0.70) {
        final double st = (t - 0.35) / 0.35;
        bobY = -6.0 + 4.0 * math.sin(st * (math.pi / 2));
      } else {
        final double st = (t - 0.70) / 0.30;
        bobY = -2.0 + 2.0 * math.sin(st * (math.pi / 2));
      }
    } else {
      // Harmonic walk bobbing: 2x stride frequency, 0 to -2.2px
      bobY = -2.2 * math.sin(stridePhase).abs();
    }

    // Kinematic angles
    final double legAngle = isArrived ? 0.0 : math.sin(stridePhase) * 0.5236; // 30 deg
    final double armAngle = isArrived ? 0.0 : -math.sin(stridePhase) * 0.4189; // 24 deg

    // -------------------------------------------------------------
    // LAYER 1: Left Arm (Back Arm)
    // -------------------------------------------------------------
    canvas.save();
    canvas.translate(-7, -5 + bobY);
    canvas.rotate(armAngle);
    // Left Sleeve
    canvas.drawLine(
      const Offset(1, -2.5),
      const Offset(0, 2),
      Paint()
        ..color = const Color(0xFF1B5E20)
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round,
    );
    // Left Forearm
    canvas.drawLine(
      const Offset(0, 2),
      const Offset(-1.5, 7.5),
      Paint()
        ..color = const Color(0xFFF5D0A9)
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );
    // Left Hand
    canvas.drawCircle(const Offset(-1.5, 7.5), 1.6, Paint()..color = const Color(0xFFF5D0A9));
    canvas.restore();

    // -------------------------------------------------------------
    // LAYER 2: Left Leg (Back Leg)
    // -------------------------------------------------------------
    canvas.save();
    canvas.translate(-4, 2);
    canvas.rotate(legAngle);
    // Left Pants (#143818)
    final Path leftPants = Path()
      ..moveTo(-1, -0.5)
      ..lineTo(-0.5, 9.5)
      ..lineTo(2.5, 9.5)
      ..lineTo(2.0, -0.5)
      ..close();
    canvas.drawPath(leftPants, Paint()..color = const Color(0xFF143818));

    // Left Shoe Upper (#1E293B)
    final Path leftShoeUpper = Path()
      ..moveTo(-1.2, 9.0)
      ..lineTo(2.8, 9.0)
      ..lineTo(4.0, 11.2)
      ..lineTo(-2.0, 11.2)
      ..close();
    canvas.drawPath(leftShoeUpper, Paint()..color = const Color(0xFF1E293B));

    // Left Shoe Sole (#FFFFFF)
    final leftSoleRRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-2.5, 11.2, 6.8, 2.2),
      const Radius.circular(1.0),
    );
    canvas.drawRRect(leftSoleRRect, Paint()..color = Colors.white);
    canvas.drawRRect(
      leftSoleRRect,
      Paint()
        ..color = const Color(0xFFE2E8F0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.4,
    );
    canvas.restore();

    // -------------------------------------------------------------
    // LAYER 3: Body Group (Neck, Polo, Collar, Placket, Buttons)
    // -------------------------------------------------------------
    canvas.save();
    canvas.translate(0, bobY);

    // Neck
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-2, -11.5, 4, 3.5),
        const Radius.circular(1.0),
      ),
      Paint()..color = const Color(0xFFE8BA8A),
    );

    // Civic Polo Torso (#2E7D32)
    final Path torsoPath = Path()
      ..moveTo(-6.5, 1.5)
      ..lineTo(-7.5, -8.5)
      ..cubicTo(-7.5, -10.5, 7.5, -10.5, 7.5, -8.5)
      ..lineTo(6.5, 1.5)
      ..close();
    canvas.drawPath(torsoPath, Paint()..color = const Color(0xFF2E7D32));
    canvas.drawPath(
      torsoPath,
      Paint()
        ..color = const Color(0xFF1B5E20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // Crisp White Collar
    final Path collarPath = Path()
      ..moveTo(-3.2, -9.5)
      ..lineTo(0, -6.0)
      ..lineTo(3.2, -9.5)
      ..lineTo(2.2, -10.8)
      ..lineTo(-2.2, -10.8)
      ..close();
    canvas.drawPath(collarPath, Paint()..color = Colors.white);

    // Placket Line
    canvas.drawLine(
      const Offset(0, -6.0),
      const Offset(0, -1.5),
      Paint()
        ..color = const Color(0xFF1B5E20)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );

    // Pearl Buttons
    canvas.drawCircle(const Offset(0, -4.5), 0.5, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(0, -2.5), 0.5, Paint()..color = Colors.white);
    canvas.restore();

    // -------------------------------------------------------------
    // LAYER 4: Right Leg (Front Leg)
    // -------------------------------------------------------------
    canvas.save();
    canvas.translate(4, 2);
    canvas.rotate(-legAngle);
    // Right Pants (#1B4D20)
    final Path rightPants = Path()
      ..moveTo(-3.0, -0.5)
      ..lineTo(-2.5, 9.5)
      ..lineTo(0.5, 9.5)
      ..lineTo(0.0, -0.5)
      ..close();
    canvas.drawPath(rightPants, Paint()..color = const Color(0xFF1B4D20));

    // Right Shoe Upper
    final Path rightShoeUpper = Path()
      ..moveTo(-3.2, 9.0)
      ..lineTo(0.8, 9.0)
      ..lineTo(2.5, 11.2)
      ..lineTo(-4.0, 11.2)
      ..close();
    canvas.drawPath(rightShoeUpper, Paint()..color = const Color(0xFF1E293B));

    // Right Shoe Sole
    final rightSoleRRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-4.5, 11.2, 7.4, 2.2),
      const Radius.circular(1.0),
    );
    canvas.drawRRect(rightSoleRRect, Paint()..color = Colors.white);
    canvas.drawRRect(
      rightSoleRRect,
      Paint()
        ..color = const Color(0xFFE2E8F0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.4,
    );
    canvas.restore();

    // -------------------------------------------------------------
    // LAYER 5: Crimson Market Tote Bag (Bayong) on Hip
    // -------------------------------------------------------------
    canvas.save();
    canvas.translate(0, bobY);

    // Cross-body Strap
    canvas.drawLine(
      const Offset(-6.5, -9.0),
      const Offset(3.5, 0.5),
      Paint()
        ..color = const Color(0xFFB71C1C)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );

    // Tote Bag Body (#E53935)
    final toteRRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, -1, 8.5, 9.5),
      const Radius.circular(2.2),
    );
    canvas.drawRRect(toteRRect, Paint()..color = const Color(0xFFE53935));
    canvas.drawRRect(
      toteRRect,
      Paint()
        ..color = const Color(0xFFB71C1C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6,
    );

    // White Handle Loop
    final Path handlePath = Path()
      ..moveTo(2, -1)
      ..cubicTo(2, -2.8, 6.5, -2.8, 6.5, -1);
    canvas.drawPath(
      handlePath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..strokeCap = StrokeCap.round,
    );

    // Circular Leaf Emblem
    canvas.drawCircle(const Offset(4.2, 4.0), 1.8, Paint()..color = Colors.white);
    final Path leafPath = Path()
      ..moveTo(4.2, 3.0)
      ..cubicTo(4.9, 3.5, 4.9, 4.5, 4.2, 5.0)
      ..cubicTo(3.5, 4.5, 3.5, 3.5, 4.2, 3.0)
      ..close();
    canvas.drawPath(leafPath, Paint()..color = const Color(0xFF1B5E20));
    canvas.restore();

    // -------------------------------------------------------------
    // LAYER 6: Head & Sporty Cap Group
    // -------------------------------------------------------------
    canvas.save();
    canvas.translate(0, bobY);

    // Head (Faceless warm skin tone)
    canvas.drawCircle(const Offset(0, -16.5), 6.6, Paint()..color = const Color(0xFFF5D0A9));

    // Cap Crown (#1B5E20)
    final Path capCrown = Path()
      ..moveTo(-6.6, -18.0)
      ..cubicTo(-7.2, -24.5, 4.5, -25.5, 6.0, -18.5)
      ..cubicTo(3.2, -19.8, -3.5, -19.5, -6.6, -18.0)
      ..close();
    canvas.drawPath(capCrown, Paint()..color = const Color(0xFF1B5E20));

    // Cap Panel Inset
    final Path capPanel = Path()
      ..moveTo(-2.0, -19.0)
      ..cubicTo(-1.5, -24.0, 4.2, -24.0, 5.2, -18.5)
      ..close();
    canvas.drawPath(
      capPanel,
      Paint()..color = const Color(0xFF2E7D32).withValues(alpha: 0.8),
    );

    // Forward Visor Bill
    final Path capVisor = Path()
      ..moveTo(3.8, -19.0)
      ..cubicTo(6.0, -20.2, 9.6, -19.8, 11.0, -17.2)
      ..cubicTo(9.0, -17.0, 5.5, -17.5, 3.2, -17.8)
      ..close();
    canvas.drawPath(capVisor, Paint()..color = const Color(0xFF144618));

    // Top Button
    canvas.drawCircle(const Offset(-0.5, -24.2), 0.9, Paint()..color = Colors.white);
    canvas.restore();

    // -------------------------------------------------------------
    // LAYER 7: Right Arm (Front Arm - Dual Mode)
    // -------------------------------------------------------------
    canvas.save();
    canvas.translate(0, bobY);

    if (!isArrived) {
      // MODE A: Walking Stride Swing
      canvas.save();
      canvas.translate(6, -5);
      canvas.rotate(-armAngle);
      // Sleeve
      canvas.drawLine(
        const Offset(0, -2.5),
        const Offset(1, 2),
        Paint()
          ..color = const Color(0xFF2E7D32)
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round,
      );
      // Forearm
      canvas.drawLine(
        const Offset(1, 2),
        const Offset(2.5, 7.5),
        Paint()
          ..color = const Color(0xFFF5D0A9)
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round,
      );
      // Hand
      canvas.drawCircle(const Offset(2.5, 7.5), 1.6, Paint()..color = const Color(0xFFF5D0A9));
      canvas.restore();
    } else {
      // MODE B: Arrival Greeting Wave Pose
      // Shoulder sleeve
      canvas.drawLine(
        const Offset(6, -7.5),
        const Offset(8.5, -6.5),
        Paint()
          ..color = const Color(0xFF2E7D32)
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round,
      );

      // Waving forearm oscillates from elbow (8.5, -6.5) between -8 deg and +14 deg
      final double waveAngle = -0.1396 + 0.384 * math.sin(waveProgress * 2 * math.pi);
      canvas.save();
      canvas.translate(8.5, -6.5);
      canvas.rotate(waveAngle);
      // Forearm bent upward beside cheek
      canvas.drawLine(
        Offset.zero,
        const Offset(-0.5, -7.0),
        Paint()
          ..color = const Color(0xFFF5D0A9)
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round,
      );
      // Hand circle beside cheek
      canvas.drawCircle(const Offset(-0.5, -7.3), 1.6, Paint()..color = const Color(0xFFF5D0A9));
      canvas.restore();
    }
    canvas.restore();

    canvas.restore(); // Restore base transform
  }

  @override
  bool shouldRepaint(covariant PedestrianAvatarPainter oldDelegate) {
    return oldDelegate.walkCycleProgress != walkCycleProgress ||
        oldDelegate.arrivalHopProgress != arrivalHopProgress ||
        oldDelegate.waveProgress != waveProgress ||
        oldDelegate.isArrived != isArrived ||
        oldDelegate.facingSign != facingSign ||
        oldDelegate.scale != scale;
  }
}
