import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merkado_go/data/seed_stalls.dart';
import 'package:merkado_go/features/chat/domain/chat_directory_action.dart';
import 'package:merkado_go/features/chat/presentation/aling_suki_chat_screen.dart';
import 'package:merkado_go/features/chat/presentation/widgets/chat_directory_card.dart';
import 'package:merkado_go/features/map/services/pathfinding_service.dart';
import 'package:merkado_go/models/stall_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatDirectoryAction Unit Tests', () {
    test('Correctly parses valid directory tag', () {
      const text = '''
Here are 5 sari-sari stores. Since there are 18 stalls total, you can check them out in the Stall Directory.
<!--DIRECTORY:{"category":"Sari Sari","totalCount":18}-->
''';

      final action = ChatDirectoryAction.tryParseFromText(text);
      expect(action, isNotNull);
      expect(action!.category, equals('Sari Sari'));
      expect(action.totalCount, equals(18));
    });

    test('Returns null when no directory tag is present', () {
      const text = 'Here are some good sari-sari stalls in the market.';
      final action = ChatDirectoryAction.tryParseFromText(text);
      expect(action, isNull);
    });

    test('stripDirectoryTags cleanly removes closed and unclosed streaming tags', () {
      const closed =
          'Check the stalls below.\n<!--DIRECTORY:{"category":"Sari Sari","totalCount":18}-->';
      expect(
        ChatDirectoryAction.stripDirectoryTags(closed),
        equals('Check the stalls below.'),
      );

      const streaming =
          'Check the stalls below.\n<!--DIRECTORY:{"category":"Sari';
      expect(
        ChatDirectoryAction.stripDirectoryTags(streaming),
        equals('Check the stalls below.'),
      );
    });
  });

  group('ChatDirectoryCard Widget Tests', () {
    testWidgets('Renders category info, stall count, and zero emojis',
        (tester) async {
      const action = ChatDirectoryAction(
        category: 'Sari Sari',
        totalCount: 18,
      );

      bool wasClosed = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatDirectoryCard(
                action: action,
                onClose: () => wasClosed = true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify category title and count badge rendered
      expect(find.text('STALL DIRECTORY'), findsOneWidget);
      expect(find.text('18 stalls'), findsOneWidget);
      expect(find.text('View in Stall Directory'), findsOneWidget);
      expect(find.textContaining('Sari Sari'), findsWidgets);

      // Verify zero emojis
      final allTextWidgets =
          tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '');
      for (final text in allTextWidgets) {
        final hasEmoji = RegExp(
          r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
          unicode: true,
        ).hasMatch(text);
        expect(hasEmoji, isFalse, reason: 'Text "$text" contains emoji');
      }

      // Tap CTA button
      await tester.tap(find.text('View in Stall Directory'));
      await tester.pumpAndSettle();

      expect(wasClosed, isTrue);
    });
  });

  group('AlingSukiChatScreen Fallback Directory Resolution Tests', () {
    List<StallModel> generateStalls(String category, int count) {
      return List.generate(
        count,
        (i) => StallModel(
          stallId: 'id_${category.toLowerCase()}_$i',
          name: '${category.toUpperCase()} STALL $i',
          category: category,
          categories: [category],
          products: ['Sample $category product'],
          address: 'Market Complex',
          photoUrls: const [],
          openTime: '5:00 AM',
          closeTime: '6:00 PM',
          daysOpen: const ['Monday'],
          latitude: 0.0,
          longitude: 0.0,
          isActive: true,
          status: 'open',
          section: '$category Section',
          stallNumber: 'STALL #$i',
          updatedAt: DateTime.now(),
        ),
      );
    }

    final testStalls = [
      ...generateStalls('Fish', 8),
      ...generateStalls('Meat', 12),
      ...generateStalls('Produce', 10),
    ];

    test('General query "what stalls are open?" returns null and never hijacks to Meat', () {
      final action = AlingSukiChatScreen.resolveFallbackDirectoryAction(
        'Here are some open stalls across the market: ADVZ Fish Retailing, Peraz Sari-Sari Store, and Mang Juan Meat Shop.',
        'what stalls are open?',
        stalls: testStalls,
      );
      expect(action, isNull,
          reason: 'General query should not display category directory card');
    });

    test('Fish query "where can I buy fish?" without directory advice returns null and never returns Meat', () {
      final action = AlingSukiChatScreen.resolveFallbackDirectoryAction(
        'You can buy fresh fish at ADVZ Fish Retailing and Ponteres Dried Fish Store.',
        'where can I buy fish?',
        stalls: testStalls,
      );
      expect(action, isNull,
          reason: 'Conversational fish recommendation without directory handoff must not trigger directory card');
    });

    test('Explicit "show all fish" returns Fish directory action, not Meat', () {
      final action = AlingSukiChatScreen.resolveFallbackDirectoryAction(
        'Here are some fish vendors. You can view all in the directory.',
        'show all fish stalls',
        stalls: testStalls,
      );
      expect(action, isNotNull);
      expect(action!.category, equals('Fish'));
      expect(action.totalCount, equals(8));
    });

    test('Word boundary regex prevents "origin" from matching Meat keyword "orig"', () {
      final action = AlingSukiChatScreen.resolveFallbackDirectoryAction(
        'I am Aling Suki, the official assistant of Ligao Public Market.',
        'what is your origin?',
        stalls: testStalls,
      );
      expect(action, isNull,
          reason: 'The word "origin" must not trigger Meat category via keyword "orig"');
    });

    test('Query for "matang baka" fish targets Fish category, not Meat', () {
      final action = AlingSukiChatScreen.resolveFallbackDirectoryAction(
        'Since there are 8 Fish stalls, you can check it out in the stall directory.',
        'where can I buy matang baka fish?',
        stalls: testStalls,
      );
      expect(action, isNotNull);
      expect(action!.category, equals('Fish'),
          reason: 'Matang baka fish query with directory advice must match Fish');
    });
  });

  group('Proximity Solver Graph Verification', () {
    test('Accurately identifies Ponteres as #1 nearest fish stall to Entrance 6', () {
      final nodesStr = File('assets/map/map_nodes.json').readAsStringSync();
      final entriesStr = File('assets/map/market_entry_points.json').readAsStringSync();
      final stallNodesStr = File('assets/map/stall_nodes.json').readAsStringSync();

      final pathService = PathfindingService();
      pathService.initializeWithRawData(
        mapNodesJson: jsonDecode(nodesStr),
        entryPointsJson: jsonDecode(entriesStr),
        stallNodesJson: jsonDecode(stallNodesStr),
      );

      final fishStalls = kMarketVendorsSeedData.where((v) {
        final cat = (v['category'] ?? '').toString();
        final cats = (v['categories'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        return cat.toLowerCase().contains('fish') || cats.any((c) => c.toLowerCase().contains('fish'));
      }).toList();

      final entrance6 = pathService.getEntryPointById(6);
      expect(entrance6, isNotNull);

      final results = <Map<String, dynamic>>[];
      for (final stall in fishStalls) {
        final stallId = (stall['stall_id'] as String? ?? 'id_${stall['id']}').trim();
        final name = stall['name'].toString();
        final route = pathService.findRoute(
          entranceNodeId: entrance6!.nodeId,
          destinationStallId: stallId,
          destinationName: name,
        );
        if (route != null) {
          results.add({
            'stallId': stallId,
            'name': name,
            'distance': route.totalDistance,
            'meters': (route.totalDistance * 0.15).round(),
          });
        }
      }

      results.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

      expect(results.isNotEmpty, isTrue);

      // Ponteres Dried Fish Store must be rank 1
      final topRank = results.first;
      expect(topRank['name'], contains('PONTERES DRIED FISH STORE'));
      expect(topRank['meters'], lessThan(100)); // ~71 meters

      // ADVZ Fish Retailing must be farther down the ranking (> 300 meters)
      final advz = results.firstWhere((r) => (r['name'] as String).contains('ADVZ'));
      final advzRank = results.indexOf(advz) + 1;
      expect(advzRank, greaterThanOrEqualTo(6));
      expect(advz['meters'], greaterThan(350));
    });
  });
}
