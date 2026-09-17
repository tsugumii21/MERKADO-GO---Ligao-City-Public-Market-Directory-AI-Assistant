import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merkado_go/core/widgets/exit_confirmation_dialog.dart';

void main() {
  group('ExitConfirmationDialog Widget Tests', () {
    testWidgets('renders icon, title, message, and buttons properly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExitConfirmationDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check title and description
      expect(find.text('Exit MerkadoGo?'), findsOneWidget);
      expect(
        find.text('Are you sure you want to exit? You can return anytime to explore stalls and navigate the market.'),
        findsOneWidget,
      );

      // Check buttons
      expect(find.text('Stay in App'), findsOneWidget);
      expect(find.text('Exit'), findsOneWidget);
      expect(find.byIcon(Icons.logout_rounded), findsOneWidget);
    });

    testWidgets('tapping Stay in App pops dialog with false', (tester) async {
      bool? dialogResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  dialogResult = await showExitConfirmationDialog(context);
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap to open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.byType(ExitConfirmationDialog), findsOneWidget);

      // Tap Stay in App
      await tester.tap(find.text('Stay in App'));
      await tester.pumpAndSettle();

      expect(find.byType(ExitConfirmationDialog), findsNothing);
      expect(dialogResult, isFalse);
    });

    testWidgets('tapping Exit pops dialog with true', (tester) async {
      bool? dialogResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  dialogResult = await showExitConfirmationDialog(context);
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap to open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.byType(ExitConfirmationDialog), findsOneWidget);

      // Tap Exit button
      await tester.tap(find.text('Exit'));
      await tester.pumpAndSettle();

      expect(find.byType(ExitConfirmationDialog), findsNothing);
      expect(dialogResult, isTrue);
    });

    testWidgets('Stay in App and Exit button texts are centered and single-line on compact screen', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExitConfirmationDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final stayText = tester.widget<Text>(find.text('Stay in App'));
      expect(stayText.textAlign, TextAlign.center);
      expect(stayText.maxLines, 1);

      final exitText = tester.widget<Text>(find.text('Exit'));
      expect(exitText.textAlign, TextAlign.center);
      expect(exitText.maxLines, 1);

      // Verify buttons are rendered and both have min 48px height
      final stayButton = tester.getRect(find.byType(FilledButton));
      final exitButton = tester.getRect(find.byType(OutlinedButton));
      expect(stayButton.height, greaterThanOrEqualTo(48.0));
      expect(exitButton.height, greaterThanOrEqualTo(48.0));

      // Verify text centers align vertically within their respective buttons
      final stayTextCenter = tester.getCenter(find.text('Stay in App'));
      final exitTextCenter = tester.getCenter(find.text('Exit'));
      expect((stayTextCenter.dy - stayButton.center.dy).abs(), lessThan(2.0));
      expect((exitTextCenter.dy - exitButton.center.dy).abs(), lessThan(2.0));
    });
  });
}
