import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String _cloudName = 'diiuzmjnk';
  static const String _uploadPreset = 'merkadogo';

  static Future<String?> uploadProfileImage(
      File imageFile, String userId) async {
    try {
      debugPrint('📤 Starting Cloudinary upload...');

      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      final dataUri = 'data:image/jpeg;base64,$base64Image';

      final response = await http.post(
        Uri.parse(
          'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'file': dataUri,
          'upload_preset': _uploadPreset,
        }),
      );

      debugPrint('📥 Status: ${response.statusCode}');
      debugPrint('📥 Body: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final secureUrl = json['secure_url'] as String;
        debugPrint('✅ Upload success: $secureUrl');
        return secureUrl;
      } else {
        debugPrint('❌ Upload failed: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Upload error: $e');
      return null;
    }
  }

  /// Upload stall image to Cloudinary (to 'merkadogo/stalls' folder)
  /// Returns the secure URL or null if upload fails
  static Future<String?> uploadStallImage(
    File imageFile, {
    Function(int sent, int total)? onProgress,
  }) async {
    try {
      debugPrint('📤 Starting stall image upload...');

      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      final dataUri = 'data:image/jpeg;base64,$base64Image';

      if (onProgress != null) {
        onProgress(50, 100); // Simulated progress (encoding done)
      }

      final response = await http.post(
        Uri.parse(
          'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'file': dataUri,
          'upload_preset': _uploadPreset,
          'folder': 'merkadogo/stalls',
        }),
      );

      if (onProgress != null) {
        onProgress(100, 100); // Upload complete
      }

      debugPrint('📥 Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final secureUrl = json['secure_url'] as String;
        debugPrint('✅ Stall image upload success: $secureUrl');
        return secureUrl;
      } else {
        debugPrint('❌ Stall image upload failed: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Stall image upload error: $e');
      return null;
    }
  }

  /// Upload multiple stall images
  static Future<List<String>> uploadMultipleStallImages(
    List<File> imageFiles, {
    Function(int currentIndex, int total)? onProgress,
  }) async {
    List<String> uploadedUrls = [];

    for (int i = 0; i < imageFiles.length; i++) {
      if (onProgress != null) {
        onProgress(i, imageFiles.length);
      }

      final url = await uploadStallImage(imageFiles[i]);
      if (url != null) {
        uploadedUrls.add(url);
      }
    }

    if (onProgress != null) {
      onProgress(imageFiles.length, imageFiles.length);
    }

    return uploadedUrls;
  }
}