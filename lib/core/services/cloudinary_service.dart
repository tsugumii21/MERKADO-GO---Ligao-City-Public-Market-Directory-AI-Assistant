import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String _cloudName = 'diiuzmjnk';
  static const String _uploadPreset = 'merkadogo';
  static const String baseDeliveryUrl = 'https://res.cloudinary.com/$_cloudName/image/upload/';

  /// Resolves the deterministic Cloudinary CDN URL for a stall photo
  static String getStallPhotoUrl(String stallId) {
    final cleanId = stallId.trim();
    if (cleanId.isEmpty) return '';
    return '${baseDeliveryUrl}merkadogo/stalls/$cleanId.jpg';
  }

  /// Resolves the deterministic Cloudinary CDN URL for an entrance gate photo
  static String getEntrancePhotoUrl(int entranceId) {
    return '${baseDeliveryUrl}merkadogo/entrances/entry_$entranceId.jpg';
  }

  /// Upload raw image bytes to Cloudinary
  static Future<String?> uploadImageBytes(
    Uint8List bytes, {
    String? folder,
    String? publicId,
    Function(int sent, int total)? onProgress,
  }) async {
    try {
      final base64Image = base64Encode(bytes);
      final dataUri = 'data:image/jpeg;base64,$base64Image';

      if (onProgress != null) {
        onProgress(50, 100);
      }

      final Map<String, String> payload = {
        'file': dataUri,
        'upload_preset': _uploadPreset,
      };

      if (folder != null && folder.isNotEmpty) {
        payload['folder'] = folder;
      }

      if (publicId != null && publicId.isNotEmpty) {
        payload['public_id'] = publicId;
      }

      final response = await http.post(
        Uri.parse(
          'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (onProgress != null) {
        onProgress(100, 100);
      }

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final secureUrl = json['secure_url'] as String;
        return secureUrl;
      } else {
        debugPrint('❌ Failed: Cloudinary upload failed: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error: Cloudinary upload error: $e');
      return null;
    }
  }

  /// Upload profile image bytes to Cloudinary
  static Future<String?> uploadProfileImageBytes(
      Uint8List bytes, String userId) async {
    return uploadImageBytes(bytes);
  }

  /// Upload stall image bytes to Cloudinary
  static Future<String?> uploadStallImageBytes(
    Uint8List bytes, {
    String? stallId,
    Function(int sent, int total)? onProgress,
  }) async {
    return uploadImageBytes(
      bytes,
      folder: 'merkadogo/stalls',
      publicId: stallId,
      onProgress: onProgress,
    );
  }

  /// Upload multiple stall images as bytes
  static Future<List<String>> uploadMultipleStallImagesBytes(
    List<Uint8List> imageBytesList, {
    Function(int currentIndex, int total)? onProgress,
  }) async {
    List<String> uploadedUrls = [];

    for (int i = 0; i < imageBytesList.length; i++) {
      if (onProgress != null) {
        onProgress(i, imageBytesList.length);
      }

      final url = await uploadStallImageBytes(imageBytesList[i]);
      if (url != null) {
        uploadedUrls.add(url);
      }
    }

    if (onProgress != null) {
      onProgress(imageBytesList.length, imageBytesList.length);
    }

    return uploadedUrls;
  }
}