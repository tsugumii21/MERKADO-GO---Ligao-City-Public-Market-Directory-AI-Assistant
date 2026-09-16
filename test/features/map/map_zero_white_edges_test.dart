import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:merkado_go/features/map/presentation/widgets/interactive_market_map.dart';

void main() {
  group('Map Zero White Edges & Rotation Containment Tests', () {
    testWidgets('Map strictly covers viewport at all rotation angles with zero white edges',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = TransformationController();
      const screenW = 400.0;
      const screenH = 800.0;
      const svgW = 8004.0;
      const svgH = 8000.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: screenW,
              height: screenH,
              child: InteractiveMarketMap(
                transformationController: controller,
              ),
            ),
          ),
        ),
      );

      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Test multiple rotation angles: 15, 30, 45, 60, 90, 135, 180, 270 degrees
      final angles = [
        math.pi / 12,
        math.pi / 6,
        math.pi / 4,
        math.pi / 3,
        math.pi / 2,
        3 * math.pi / 4,
        math.pi,
        3 * math.pi / 2,
      ];

      for (final angle in angles) {
        // Rotate around viewport center and pan to extreme offset
        final rotMatrix = Matrix4.identity()
          ..translateByVector3(Vector3(screenW / 2, screenH / 2, 0.0))
          ..rotateZ(angle)
          ..scaleByVector3(Vector3(0.25, 0.25, 0.25))
          ..translateByVector3(Vector3(-svgW / 2, -svgH / 2, 0.0));

        // Add extreme translations (attempting to pull map away from edges)
        for (final offset in [
          const Offset(5000.0, 5000.0),
          const Offset(-5000.0, -5000.0),
          const Offset(5000.0, -5000.0),
          const Offset(-5000.0, 5000.0),
        ]) {
          final testMatrix = rotMatrix.clone()
            ..storage[12] += offset.dx
            ..storage[13] += offset.dy;

          controller.value = testMatrix;
          await tester.pump();

          // Invert matrix to verify 4 viewport corners are strictly inside map
          final inv = Matrix4.identity();
          inv.copyInverse(controller.value);

          final c0 = inv.transform3(Vector3(0.0, 0.0, 0.0));
          final c1 = inv.transform3(Vector3(screenW, 0.0, 0.0));
          final c2 = inv.transform3(Vector3(screenW, screenH, 0.0));
          final c3 = inv.transform3(Vector3(0.0, screenH, 0.0));

          final uMin = math.min(math.min(c0.x, c1.x), math.min(c2.x, c3.x));
          final uMax = math.max(math.max(c0.x, c1.x), math.max(c2.x, c3.x));
          final vMin = math.min(math.min(c0.y, c1.y), math.min(c2.y, c3.y));
          final vMax = math.max(math.max(c0.y, c1.y), math.max(c2.y, c3.y));

          // Every viewport corner MUST be inside [0, svgW] and [0, svgH] (zero white edges)
          expect(uMin, greaterThanOrEqualTo(-0.5));
          expect(uMax, lessThanOrEqualTo(svgW + 0.5));
          expect(vMin, greaterThanOrEqualTo(-0.5));
          expect(vMax, lessThanOrEqualTo(svgH + 0.5));
        }
      }
    });

    testWidgets('Unrotated panning clamps strictly at map boundary edges with zero padding',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = TransformationController();
      const screenW = 400.0;
      const screenH = 800.0;
      const svgW = 8004.0;
      const svgH = 8000.0;
      const scale = 0.25;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: screenW,
              height: screenH,
              child: InteractiveMarketMap(
                transformationController: controller,
              ),
            ),
          ),
        ),
      );

      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // 1. Pan far right: map left edge (0) aligns with screen left edge (0) -> tx = 0
      controller.value = Matrix4.identity()
        ..scaleByVector3(Vector3(scale, scale, scale))
        ..setTranslation(Vector3(9999.0, 0.0, 0.0));
      await tester.pump();
      expect(controller.value.storage[12], closeTo(0.0, 1.0));

      // 2. Pan far left: map right edge (svgW) aligns with screen right edge (screenW)
      controller.value = Matrix4.identity()
        ..scaleByVector3(Vector3(scale, scale, scale))
        ..setTranslation(Vector3(-9999.0, 0.0, 0.0));
      await tester.pump();
      final expectedMinTx = screenW - svgW * scale; // 400 - 2001 = -1601.0
      expect(controller.value.storage[12], closeTo(expectedMinTx, 1.0));

      // 3. Pan far down: map top edge (0) aligns with screen top edge (0) -> ty = 0
      controller.value = Matrix4.identity()
        ..scaleByVector3(Vector3(scale, scale, scale))
        ..setTranslation(Vector3(0.0, 9999.0, 0.0));
      await tester.pump();
      expect(controller.value.storage[13], closeTo(0.0, 1.0));

      // 4. Pan far up: map bottom edge (svgH) aligns with screen bottom edge (screenH)
      controller.value = Matrix4.identity()
        ..scaleByVector3(Vector3(scale, scale, scale))
        ..setTranslation(Vector3(0.0, -9999.0, 0.0));
      await tester.pump();
      final expectedMinTy = screenH - svgH * scale; // 800 - 2000 = -1200.0
      expect(controller.value.storage[13], closeTo(expectedMinTy, 1.0));
    });
  });
}
