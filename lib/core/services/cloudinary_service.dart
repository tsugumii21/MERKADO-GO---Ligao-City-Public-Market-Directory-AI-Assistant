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
}