import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merkado_go/main.dart';

void main() {
  testWidgets('App smoke test builds successfully', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(),
      ),
    );

    // Initial frame pump
    expect(find.byType(MyApp), findsOneWidget);
  });
}
