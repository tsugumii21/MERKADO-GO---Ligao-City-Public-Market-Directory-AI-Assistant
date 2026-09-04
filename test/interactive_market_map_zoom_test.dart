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

    // Test clamp when zoomed out below minScale (0.25)
    controller.value = Matrix4.identity()
      ..scaleByVector3(Vector3(0.10, 0.10, 0.10));
    await tester.pump();
    final clampedMinScale = controller.value.getMaxScaleOnAxis();
    debugPrint('Clamped scale when set to 0.10: $clampedMinScale');
    expect(clampedMinScale, closeTo(0.25, 0.01));

    // Test clamp when zoomed in above maxScale (3.5)
    controller.value = Matrix4.identity()
      ..scaleByVector3(Vector3(5.0, 5.0, 5.0));
    await tester.pump();
    final clampedMaxScale = controller.value.getMaxScaleOnAxis();
    debugPrint('Clamped scale when set to 5.0: $clampedMaxScale');
    expect(clampedMaxScale, closeTo(3.5, 0.01));
  });
}
