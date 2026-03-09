import 'package:flutter_dotenv/flutter_dotenv.dart';

/// App secrets loaded from .env file
/// NEVER commit actual values to version control
class AppSecrets {
  // Cloudinary Configuration
  static String get cloudinaryCloudName =>
      dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  
  // Note: These credentials are stored but NOT used in unsigned uploads
  static String get cloudinaryApiKey =>
      dotenv.env['CLOUDINARY_API_KEY'] ?? '';
  
  static String get cloudinaryApiSecret =>
      dotenv.env['CLOUDINARY_API_SECRET'] ?? '';
  
  static String get cloudinaryUrl =>
      dotenv.env['CLOUDINARY_URL'] ?? '';
  
  static String get cloudinaryUploadPreset =>
      dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';

  // Gemini AI Configuration
  static String get geminiApiKey =>
      dotenv.env['GEMINI_API_KEY'] ?? '';

  // Google Maps Configuration
  static String get googleMapsApiKey =>
      dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  // Validation
  static bool get isConfigured {
    return cloudinaryCloudName.isNotEmpty &&
        cloudinaryUploadPreset.isNotEmpty &&
        geminiApiKey.isNotEmpty &&
        googleMapsApiKey.isNotEmpty;
  }

  static String get missingKeys {
    final missing = <String>[];
    if (cloudinaryCloudName.isEmpty) missing.add('CLOUDINARY_CLOUD_NAME');
    if (cloudinaryUploadPreset.isEmpty) missing.add('CLOUDINARY_UPLOAD_PRESET');
    if (geminiApiKey.isEmpty) missing.add('GEMINI_API_KEY');
    if (googleMapsApiKey.isEmpty) missing.add('GOOGLE_MAPS_API_KEY');
    return missing.join(', ');
  }
}
