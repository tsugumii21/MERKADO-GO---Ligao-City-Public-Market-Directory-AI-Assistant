import 'package:flutter_test/flutter_test.dart';
import 'package:merkado_go/features/auth/constants/auth_loading_phrases.dart';

void main() {
  group('AuthLoadingPhrases Unit Tests', () {
    test('Contains at least 10 distinct authentic market welcome phrases', () {
      expect(AuthLoadingPhrases.phrases.length, greaterThanOrEqualTo(10));
      expect(AuthLoadingPhrases.phrases.toSet().length, AuthLoadingPhrases.phrases.length);
    });

    test('formatPhrase replaces {userName} accurately', () {
      const template = 'Welcome back, {userName}! Preparing your market guide...';
      final formatted = AuthLoadingPhrases.formatPhrase(
        template,
        userName: 'Maria',
      );

      expect(formatted, equals('Welcome back, Maria! Preparing your market guide...'));
    });

    test('formatPhrase handles null, empty, or whitespace userName gracefully', () {
      const template = 'Welcome back, {userName}!';
      final formattedNull = AuthLoadingPhrases.formatPhrase(template, userName: null);
      final formattedEmpty = AuthLoadingPhrases.formatPhrase(template, userName: '   ');

      expect(formattedNull, equals('Welcome back, market explorer!'));
      expect(formattedEmpty, equals('Welcome back, market explorer!'));
    });

    test('getRandomPhrase returns non-empty string without raw placeholder', () {
      for (var i = 0; i < 50; i++) {
        final phrase = AuthLoadingPhrases.getRandomPhrase(userName: 'Carlos');
        expect(phrase, isNotEmpty);
        expect(phrase.contains('{userName}'), isFalse);
      }
    });
  });
}
