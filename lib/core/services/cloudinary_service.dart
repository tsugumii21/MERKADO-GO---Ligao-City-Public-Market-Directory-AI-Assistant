import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/app_secrets.dart';

/// Service for uploading images to Cloudinary
/// Uses unsigned upload preset (no authentication required)
class CloudinaryService {
  static const String _baseUrl = 'https://api.cloudinary.com/v1_1';

  /// Upload an image to Cloudinary
  /// 
  /// [imageFile] - The image file to upload
  /// [folder] - Optional folder name in Cloudinary (e.g., 'stalls', 'profiles')
  /// 
  /// Returns the secure URL of the uploaded image, or null on failure
  Future<String?> uploadImage(File imageFile, {String? folder}) async {
    try {
      // Step 1: Compress image to max 300KB
      final compressedImage = await _compressImage(imageFile);
      if (compressedImage == null) {
        print('❌ Image compression failed');
        return null;
      }

      // Step 2: Prepare multipart request
      final cloudName = AppSecrets.cloudinaryCloudName;
      final uploadPreset = AppSecrets.cloudinaryUploadPreset;

      if (cloudName.isEmpty || uploadPreset.isEmpty) {
        print('❌ Cloudinary credentials missing in .env');
        return null;
      }

      final uri = Uri.parse('$_baseUrl/$cloudName/image/upload');
      final request = http.MultipartRequest('POST', uri);

      // Add upload preset
      request.fields['upload_preset'] = uploadPreset;

      // Add folder if specified
      if (folder != null && folder.isNotEmpty) {
        request.fields['folder'] = folder;
      }

      // Add the image file
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          compressedImage.path,
        ),
      );

      // Step 3: Send request
      print('📤 Uploading image to Cloudinary...');
      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(responseData);
        final secureUrl = jsonResponse['secure_url'] as String?;

        if (secureUrl != null) {
          print('✅ Image uploaded successfully: $secureUrl');
          return secureUrl;
        } else {
          print('❌ No secure_url in response');
          return null;
        }
      } else {
        print('❌ Upload failed: ${response.statusCode}');
        print('Response: $responseData');
        return null;
      }
    } catch (e) {
      print('❌ Cloudinary upload error: $e');
      return null;
    }
  }

  /// Compress image to max 300KB
  Future<File?> _compressImage(File imageFile) async {
    try {
      final filePath = imageFile.path;
      final lastIndex = filePath.lastIndexOf('.');
      final splitPath = filePath.substring(0, lastIndex);
      final outPath = '${splitPath}_compressed.jpg';

      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        imageFile.path,
        outPath,
        quality: 85,
        minWidth: 1024,
        minHeight: 1024,
      );

      if (compressedFile == null) {
        return null;
      }

      // Check file size
      final fileSize = await compressedFile.length();
      print('📊 Compressed image size: ${(fileSize / 1024).toStringAsFixed(2)} KB');

      // If still too large, compress more
      if (fileSize > 300 * 1024) {
        final secondPass = await FlutterImageCompress.compressAndGetFile(
          compressedFile.path,
          outPath,
          quality: 70,
          minWidth: 800,
          minHeight: 800,
        );
        return secondPass != null ? File(secondPass.path) : File(compressedFile.path);
      }

      return File(compressedFile.path);
    } catch (e) {
      print('❌ Compression error: $e');
      return null;
    }
  }

  /// Upload multiple images to Cloudinary
  /// Returns a list of secure URLs
  Future<List<String>> uploadMultipleImages(
    List<File> imageFiles, {
    String? folder,
  }) async {
    final urls = <String>[];

    for (final imageFile in imageFiles) {
      final url = await uploadImage(imageFile, folder: folder);
      if (url != null) {
        urls.add(url);
      }
    }

    return urls;
  }
}
