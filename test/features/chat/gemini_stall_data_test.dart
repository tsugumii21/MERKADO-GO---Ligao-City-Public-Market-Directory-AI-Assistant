import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merkado_go/core/services/gemini_service.dart';
import 'package:merkado_go/data/seed_stalls.dart';
import 'package:merkado_go/models/stall_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GeminiService Stall Data Integration Tests', () {
    late ProviderContainer container;
    late GeminiService service;

    setUp(() {
      container = ProviderContainer();
      service = container.read(geminiServiceProvider);
    });

    tearDown(() {
      container.dispose();
    });

    test('Loads all 134 vendor stalls from seed data fallback', () async {
      expect(kMarketVendorsSeedData.length, equals(134));
      service.buildIntroMessage();
      expect(service.stallsCount, greaterThanOrEqualTo(0));
    });

    test('updateStalls accurately injects stall dataset', () {
      final sampleStalls = [
        StallModel(
          stallId: 'id_1',
          name: '2 CEE\'S STORE',
          category: 'Rice & Grains',
          categories: ['Rice & Grains'],
          products: ['Dinorado', 'Sinandomeng'],
          address: 'Building II',
          photoUrls: const [],
          openTime: '5:00 AM',
          closeTime: '6:00 PM',
          daysOpen: const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
          latitude: 0.0,
          longitude: 0.0,
          isActive: true,
          status: 'open',
          section: 'BUILDING II',
          stallNumber: 'STALL #15',
          updatedAt: DateTime.now(),
        ),
        StallModel(
          stallId: 'id_3',
          name: '4E\'S LLOBET MEATSHOP CORPORATION',
          category: 'Meat',
          categories: ['Meat'],
          products: [],
          address: 'Meat Section',
          photoUrls: const [],
          openTime: '5:00 AM',
          closeTime: '6:00 PM',
          daysOpen: const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
          latitude: 0.0,
          longitude: 0.0,
          isActive: true,
          status: 'open',
          section: 'MEAT SECTION',
          stallNumber: 'STALL #1',
          updatedAt: DateTime.now(),
        ),
      ];

      service.updateStalls(sampleStalls);
      expect(service.stallsCount, equals(2));
      expect(service.stallsLoaded, isTrue);
    });

    test('buildIntroMessage in English and Tagalog contains zero emojis', () {
      final introEN = service.buildIntroMessage(language: 'english');
      final introTL = service.buildIntroMessage(language: 'tagalog');

      final emojiRegex = RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true);
      expect(emojiRegex.hasMatch(introEN), isFalse, reason: 'English intro must have zero emojis');
      expect(emojiRegex.hasMatch(introTL), isFalse, reason: 'Tagalog intro must have zero emojis');
      expect(introEN, contains('Aling Suki'));
      expect(introTL, contains('Aling Suki'));
    });
  });
}
