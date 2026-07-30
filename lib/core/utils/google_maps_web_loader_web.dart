// ignore: avoid_web_libraries_in_flutter
// ignore: unused_import
import 'dart:async';
import 'dart:html' as html;

/// Injects the Google Maps JS API script and waits for it to fully load.
/// Uses the script element's onLoad event to guarantee `google.maps`
/// is available before any GoogleMap widget attempts to render.
Future<void> injectGoogleMapsScript(String apiKey) async {
  if (apiKey.isEmpty) return;

  // If the script is already loaded and valid, nothing to do.
  final existingScript =
      html.document.querySelector('script[src*="maps.googleapis.com"]');
  if (existingScript != null) {
    final src = existingScript.getAttribute('src') ?? '';
    if (!src.contains('YOUR_GOOGLE_MAPS_API_KEY')) {
      return; // Already loaded with a real key.
    }
    // Remove the broken placeholder script.
    existingScript.remove();
  }

  final completer = Completer<void>();

  final script = html.ScriptElement()
    ..src = 'https://maps.googleapis.com/maps/api/js?key=$apiKey'
    ..type = 'text/javascript';

  script.onLoad.listen((_) {
    if (!completer.isCompleted) completer.complete();
  });

  script.onError.listen((_) {
    // Complete even on error so the app doesn't hang indefinitely.
    if (!completer.isCompleted) completer.complete();
  });

  html.document.head?.children.add(script);

  // Safety timeout — never block startup for more than 10 seconds.
  return completer.future.timeout(
    const Duration(seconds: 10),
    onTimeout: () {},
  );
}
