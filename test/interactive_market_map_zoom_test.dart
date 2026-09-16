import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:merkado_go/features/map/presentation/widgets/interactive_market_map.dart';

void main() {
  testWidgets('InteractiveMarketMap zoom scale limits', (tester) async {
    final controller = TransformationController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 800,
            child: InteractiveMarketMap(
              transformationController: controller,
            ),
          ),
        ),
      ),
    );

    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    final scale = controller.value.getMaxScaleOnAxis();
    debugPrint('Controller scale after load: $scale');
    expect(scale, closeTo(0.25, 0.01));

    // Test clamp when zoomed out below minScale (0.15)
    controller.value = Matrix4.identity()
      ..scaleByVector3(Vector3(0.08, 0.08, 0.08));
    await tester.pump();
    final clampedMinScale = controller.value.getMaxScaleOnAxis();
    debugPrint('Clamped scale when set to 0.08: $clampedMinScale');
    expect(clampedMinScale, closeTo(0.15, 0.01));

    // Test clamp when zoomed in above maxScale (3.5)
    controller.value = Matrix4.identity()
      ..scaleByVector3(Vector3(5.0, 5.0, 5.0));
    await tester.pump();
    final clampedMaxScale = controller.value.getMaxScaleOnAxis();
    debugPrint('Clamped scale when set to 5.0: $clampedMaxScale');
    expect(clampedMaxScale, closeTo(3.5, 0.01));

    // Test clamp when translated past boundary edge (0px padding - zero white edges)
    controller.value = Matrix4.identity()
      ..scaleByVector3(Vector3(0.25, 0.25, 0.25))
      ..setTranslation(Vector3(-10000.0, -10000.0, 0.0));
    await tester.pump();
    final clampedTx = controller.value.storage[12];
    final clampedTy = controller.value.storage[13];
    debugPrint('Clamped translation at edge: tx=$clampedTx, ty=$clampedTy');
    // At scale 0.25, map width is 8004 * 0.25 = 2001. Viewport width is 400. Minimum tx is 400 - 2001 = -1601.
    // Viewport height is 600 (Scaffold body). Minimum ty is 600 - (8000 * 0.25) = 600 - 2000 = -1400.
    expect(clampedTx, closeTo(-1601.0, 2.0));
    expect(clampedTy, closeTo(-1400.0, 2.0));

    // Pan back towards center from the edge
    controller.value = controller.value.clone()
      ..storage[12] += 50.0
      ..storage[13] += 50.0;
    await tester.pump();
    expect(controller.value.storage[12], closeTo(clampedTx + 50.0, 0.1));
    expect(controller.value.storage[13], closeTo(clampedTy + 50.0, 0.1));
  });
}
