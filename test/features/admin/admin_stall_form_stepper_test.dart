import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merkado_go/features/admin/presentation/add_edit_stall_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createWidgetUnderTest() {
    return const MaterialApp(
      home: AddEditStallScreen(stallId: null),
    );
  }

  group('AddEditStallScreen Stepper Wizard Tests', () {
    testWidgets('Renders Step 0 Basic Info initially with Next button', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Step header checks
      expect(find.text('Basic Info'), findsAtLeastNWidgets(1));
      expect(find.text('Next: Category & Location'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Step 0 fields
      expect(find.text('Stall Name'), findsAtLeastNWidgets(1));
      expect(find.text('Stall Number & Full Address'), findsAtLeastNWidgets(1));
      expect(find.text('Market Map Location'), findsOneWidget);
    });

    testWidgets('Step 0 blocks advancing if required fields are missing', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tap Next without filling required fields
      final nextButton = find.text('Next: Category & Location');
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // Validation error message should be visible
      expect(find.text('Please enter a stall name.'), findsOneWidget);

      // Should still be on Step 0
      expect(find.text('Next: Category & Location'), findsOneWidget);
    });

    testWidgets('Fulfilling Step 0 requirements advances to Step 1 Category & Location', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Enter required fields
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'Test Bakery Stall');
      await tester.enterText(textFields.at(1), 'Building I, Stall 12');
      await tester.pump();

      // Tap Next
      await tester.tap(find.text('Next: Category & Location'));
      await tester.pumpAndSettle();

      // Should now be on Step 1
      expect(find.text('Primary Category'), findsAtLeastNWidgets(1));
      expect(find.text('Market Section & Building'), findsAtLeastNWidgets(1));
      expect(find.text('Next: Schedule & Products'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets('Step 1 requires subcategory selection before advancing to Step 2 and Step 3', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Fill Step 0
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'Test Meat Shop');
      await tester.enterText(textFields.at(1), 'Meat Section Stall 5');
      await tester.pump();

      // Tap Next to Step 1
      await tester.tap(find.text('Next: Category & Location'));
      await tester.pumpAndSettle();

      // Tap Category "Meat (Pork & Beef)"
      final meatCategory = find.text('Meat (Pork & Beef)');
      expect(meatCategory, findsOneWidget);
      await tester.tap(meatCategory);
      await tester.pumpAndSettle();

      // Subcategories card is auto-expanded and shows required indicator
      expect(find.text('Subcategories'), findsAtLeastNWidgets(1));
      expect(find.text('Subcategories for Meat *'), findsOneWidget);
      expect(find.text('Pork Cuts'), findsOneWidget);

      // Attempting to advance to Step 2 without selecting a subcategory should block
      await tester.tap(find.text('Next: Schedule & Products'));
      await tester.pumpAndSettle();
      expect(find.text('Please select at least one subcategory for Meat.'), findsOneWidget);

      // Select "Pork Cuts" subcategory
      await tester.tap(find.text('Pork Cuts'));
      await tester.pumpAndSettle();

      // Tap Next to Step 2
      await tester.tap(find.text('Next: Schedule & Products'));
      await tester.pumpAndSettle();

      // Verify Step 2 elements
      expect(find.text('Operating Hours & Schedule'), findsOneWidget);
      expect(find.text('Products & Inventory'), findsOneWidget);
      expect(find.text('Next: Photo & Status'), findsOneWidget);

      // Tap Next to Step 3
      await tester.tap(find.text('Next: Photo & Status'));
      await tester.pumpAndSettle();

      // Verify Step 3 elements
      expect(find.text('Stall Operational Status'), findsOneWidget);
      expect(find.text('Stall Photo'), findsOneWidget);
      expect(find.text('Review Stall Summary'), findsOneWidget);
      expect(find.text('Create Stall'), findsOneWidget);
      expect(find.text('Test Meat Shop'), findsWidgets);
      expect(find.text('Pork Cuts'), findsWidgets);
    });

    testWidgets('Stepper header allows jumping back to visited step', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Fill Step 0
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'Test Jump Shop');
      await tester.enterText(textFields.at(1), 'Section A');
      await tester.pump();

      // Advance to Step 1
      await tester.tap(find.text('Next: Category & Location'));
      await tester.pumpAndSettle();
      expect(find.text('Primary Category'), findsAtLeastNWidgets(1));

      // Tap Basic Info step in header to jump back to Step 0
      final basicInfoStep = find.text('Basic Info');
      expect(basicInfoStep, findsAtLeastNWidgets(1));
      await tester.tap(basicInfoStep.first);
      await tester.pumpAndSettle();

      // Should be back on Step 0
      expect(find.text('Next: Category & Location'), findsOneWidget);
      expect(find.text('Stall Name'), findsAtLeastNWidgets(1));
    });
  });
}
