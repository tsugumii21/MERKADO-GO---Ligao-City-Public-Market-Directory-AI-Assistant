import 'dart:math';

/// Authentic wayfinding and market phrases displayed during navigation loading.
class NavigationPhrases {
  NavigationPhrases._();

  static const List<String> phrases = [
    'Directing you to {stallName}...',
    'Finding the quickest pathway from {entranceName}...',
    'Mapping your route through the vibrant aisles of Ligao Public Market...',
    'Calculating the shortest corridor walk to your destination...',
    'Lace up your walking shoes, your market trip is starting!',
    'Navigating past fresh produce and friendly vendors...',
    'Plotting turn-by-turn walking steps to {stallName}...',
    'Charting the easiest way through the market complex...',
    'Dagos po! Preparing your market shopping route...',
    'Checking walkway connections and entrance corridors...',
    'Avoiding crowded intersections for a smoother walk...',
    'Almost there! Getting your indoor floor guide ready...',
    'Mapping aisle turns and corridor waypoints...',
    'Guiding you right to the vendor doorstep...',
    'Setting up your live walking directions...',
    'Finding the freshest finds — your route is ready!',
  ];

  /// Resolves a randomized phrase with optional dynamic stall and entrance substitution.
  static String getRandomPhrase({
    String? stallName,
    String? entranceName,
  }) {
    final random = Random();
    final template = phrases[random.nextInt(phrases.length)];
    return formatPhrase(
      template,
      stallName: stallName,
      entranceName: entranceName,
    );
  }

  /// Replaces {stallName} and {entranceName} placeholders.
  static String formatPhrase(
    String template, {
    String? stallName,
    String? entranceName,
  }) {
    final safeStall = stallName != null && stallName.trim().isNotEmpty
        ? stallName.trim()
        : 'your destination stall';
    final safeEntrance = entranceName != null && entranceName.trim().isNotEmpty
        ? entranceName.trim()
        : 'the selected gate';

    return template
        .replaceAll('{stallName}', safeStall)
        .replaceAll('{entranceName}', safeEntrance);
  }
}
