import 'package:flutter/foundation.dart';
import '../constants/app_secrets.dart';

import 'google_maps_web_loader_stub.dart'
    if (dart.library.html) 'google_maps_web_loader_web.dart';

/// Loads the Google Maps JavaScript API before the widget tree boots.
/// Returns a Future that completes only after the script has fully loaded,
/// guaranteeing `google.maps` is available when GoogleMap widget renders.
Future<void> loadGoogleMapsWebScript() async {
  if (kIsWeb) {
    final apiKey = AppSecrets.googleMapsApiKey.isNotEmpty
        ? AppSecrets.googleMapsApiKey
        : AppSecrets.firebaseWebApiKey;
    await injectGoogleMapsScript(apiKey);
  }
}
