import 'dart:math';

/// Authentic welcoming and market phrases displayed during login loading.
class AuthLoadingPhrases {
  AuthLoadingPhrases._();

  static const List<String> phrases = [
    'Dagos po! Welcome back to Ligao Public Market...',
    'Preparing your market directory and vendor list...',
    'Locating 134 fresh stalls and market goods...',
    'Setting up your interactive map and gate pins...',
    'Syncing your saved favorite stalls and preferences...',
    'Connecting to Ligao Market vendors and fresh deals...',
    'Loading today\'s freshest fruits, meats, fish, and produce...',
    'Welcome back, market explorer! Getting everything ready...',
    'Tuning navigation pathways for seamless shopping...',
    'Bringing you the vibrant heartbeat of Ligao Public Market...',
    'Almost ready! Entering your market companion...',
    'Fetching the latest stall hours and market updates...',
  ];

  /// Resolves a randomized welcome phrase.
  static String getRandomPhrase({String? userName}) {
    final random = Random();
    final template = phrases[random.nextInt(phrases.length)];
    return formatPhrase(template, userName: userName);
  }

  /// Replaces {userName} placeholder if provided.
  static String formatPhrase(String template, {String? userName}) {
    final safeUser = userName != null && userName.trim().isNotEmpty
        ? userName.trim()
        : 'market explorer';

    return template.replaceAll('{userName}', safeUser);
  }
}
