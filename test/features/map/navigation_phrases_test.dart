import 'package:flutter_test/flutter_test.dart';
import 'package:merkado_go/features/map/constants/navigation_phrases.dart';

void main() {
  group('NavigationPhrases Unit Tests', () {
    test('Contains at least 15 distinct authentic phrases', () {
      expect(NavigationPhrases.phrases.length, greaterThanOrEqualTo(15));
      expect(NavigationPhrases.phrases.toSet().length, NavigationPhrases.phrases.length);
    });

    test('formatPhrase replaces placeholders accurately', () {
      const template = 'Navigating from {entranceName} to {stallName}...';
      final formatted = NavigationPhrases.formatPhrase(
        template,
        stallName: 'Aling Nena Vegetables',
        entranceName: 'Gate 2',
      );

      expect(formatted, equals('Navigating from Gate 2 to Aling Nena Vegetables...'));
    });

    test('formatPhrase handles null or empty arguments gracefully', () {
      const template = 'Navigating from {entranceName} to {stallName}...';
      final formatted = NavigationPhrases.formatPhrase(
        template,
        stallName: null,
        entranceName: '',
      );

      expect(formatted, equals('Navigating from the selected gate to your destination stall...'));
    });

    test('getRandomPhrase returns non-empty string without unreplaced placeholders', () {
      for (var i = 0; i < 50; i++) {
        final phrase = NavigationPhrases.getRandomPhrase(
          stallName: 'Stall 10',
          entranceName: 'Gate 2',
        );

        expect(phrase, isNotEmpty);
        expect(phrase.contains('{stallName}'), isFalse);
        expect(phrase.contains('{entranceName}'), isFalse);
      }
    });
  });
}
