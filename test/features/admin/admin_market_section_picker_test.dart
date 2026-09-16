import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merkado_go/features/admin/presentation/widgets/admin_market_section_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AdminMarketSectionPicker Widget Tests', () {
    testWidgets('Renders unselected placeholder when selectedSectionId is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminMarketSectionPicker(
              selectedSectionId: null,
              onSectionChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Select Market Section / Building'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_down_rounded), findsOneWidget);
    });

    testWidgets('Renders assigned section details when selectedSectionId is provided', (tester) async {
      String? changedId;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminMarketSectionPicker(
              selectedSectionId: 'BUILDING II',
              onSectionChanged: (val) => changedId = val,
            ),
          ),
        ),
      );

      expect(find.text('Building II'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      expect(changedId, isNull);
    });

    testWidgets('Tapping picker opens bottom sheet with search and group headers', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminMarketSectionPicker(
              selectedSectionId: null,
              onSectionChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Select Market Section / Building'));
      await tester.pumpAndSettle();

      expect(find.text('Market Section & Building'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('COMMODITY SECTIONS'), findsOneWidget);
      expect(find.text('CAMARIN BUILDINGS'), findsOneWidget);
      expect(find.text('NUMBERED BUILDINGS'), findsOneWidget);
    });

    testWidgets('Search input filters sections dynamically and selection triggers callback', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      String? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminMarketSectionPicker(
              selectedSectionId: null,
              onSectionChanged: (val) => selected = val,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Select Market Section / Building'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Building V');
      await tester.pumpAndSettle();

      final resultTile = find.widgetWithText(InkWell, 'Building V');
      expect(resultTile, findsOneWidget);
      expect(find.text('Building I'), findsNothing);

      await tester.tap(resultTile);
      await tester.pumpAndSettle();

      expect(selected, equals('BUILDING V'));
    });
  });
}
