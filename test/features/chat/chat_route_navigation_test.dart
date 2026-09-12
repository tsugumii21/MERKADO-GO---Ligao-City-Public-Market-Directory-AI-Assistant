import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merkado_go/features/chat/domain/chat_route_action.dart';
import 'package:merkado_go/features/chat/presentation/widgets/chat_route_card.dart';
import 'package:merkado_go/models/stall_model.dart';
import 'package:merkado_go/providers/stall_provider.dart';

void main() {
  group('ChatRouteAction Unit Tests', () {
    test('Correctly parses valid entrance route tag', () {
      const text = '''
To get to Peraz Sari-Sari Store from Gate 2, walk straight into the complex.
<!--ROUTE:{"originType":"entrance","originId":"2","destinationStallId":"id_27","destinationStallName":"Peraz Sari-Sari Store"}-->
''';

      final action = ChatRouteAction.tryParseFromText(text);
      expect(action, isNotNull);
      expect(action!.originType, equals('entrance'));
      expect(action.originId, equals('2'));
      expect(action.destinationStallId, equals('id_27'));
      expect(action.destinationStallName, equals('Peraz Sari-Sari Store'));
    });

    test('Correctly parses stall-to-stall route tag', () {
      const text = '''
Head north through the central corridor.
<!--ROUTE:{"originType":"stall","originId":"id_1","destinationStallId":"id_44","destinationStallName":"Fish Vendor"}-->
''';

      final action = ChatRouteAction.tryParseFromText(text);
      expect(action, isNotNull);
      expect(action!.originType, equals('stall'));
      expect(action.originId, equals('id_1'));
      expect(action.destinationStallId, equals('id_44'));
    });

    test('Returns null when no route tag is present', () {
      const text = 'Here are some good fish stalls: ADVZ Fish Retailing.';
      final action = ChatRouteAction.tryParseFromText(text);
      expect(action, isNull);
    });

    test('stripRouteTags cleanly removes closed and unclosed streaming tags', () {
      const closed =
          'Walk straight to Stall 27.\n<!--ROUTE:{"originType":"entrance","originId":"2","destinationStallId":"id_27"}-->';
      expect(
        ChatRouteAction.stripRouteTags(closed),
        equals('Walk straight to Stall 27.'),
      );

      const streaming =
          'Walk straight to Stall 27.\n<!--ROUTE:{"originType":"entr';
      expect(
        ChatRouteAction.stripRouteTags(streaming),
        equals('Walk straight to Stall 27.'),
      );
    });
  });

  group('ChatRouteCard Widget Tests', () {
    testWidgets('Renders route card, stall info, and zero emojis',
        (tester) async {
      final sampleStall = StallModel(
        stallId: 'id_27',
        name: 'PERAZ SARI-SARI STORE',
        category: 'Sari-Sari',
        categories: const ['Sari-Sari', 'Grocery'],
        products: const ['Canned goods', 'Noodles'],
        address: 'Building III',
        photoUrls: const [],
        openTime: '5:00 AM',
        closeTime: '6:00 PM',
        daysOpen: const [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday'
        ],
        latitude: 0.0,
        longitude: 0.0,
        isActive: true,
        status: 'open',
        section: 'BUILDING III',
        stallNumber: 'STALL #27',
        updatedAt: DateTime.now(),
      );

      const action = ChatRouteAction(
        originType: 'entrance',
        originId: '2',
        destinationStallId: 'id_27',
        destinationStallName: 'PERAZ SARI-SARI STORE',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allStallsProvider.overrideWith((ref) => Stream.value([sampleStall])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: EdgeInsets.all(16.0),
                child: ChatRouteCard(action: action),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify destination name and section are displayed
      expect(find.text('PERAZ SARI-SARI STORE'), findsOneWidget);
      expect(find.text('STALL #27 • BUILDING III'), findsOneWidget);
      expect(find.text('Start Navigation'), findsOneWidget);

      // Verify zero emojis
      final allTexts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .join(' ');
      final emojiRegex = RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true);
      expect(emojiRegex.hasMatch(allTexts), isFalse,
          reason: 'ChatRouteCard must not contain emojis');
    });
  });
}
