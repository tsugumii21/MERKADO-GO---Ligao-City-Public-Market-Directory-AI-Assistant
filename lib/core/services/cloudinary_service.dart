import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String _cloudName = 'diiuzmjnk';
  static const String _uploadPreset = 'merkadogo';
  static const String baseDeliveryUrl = 'https://res.cloudinary.com/$_cloudName/image/upload/';

  /// Generates a CDN-optimized URL with format auto-negotiation (WebP/AVIF),
  /// perceptual quality compression, and dimensional capping.
  static String getOptimizedImageUrl(
    String url, {
    int width = 800,
    int? height,
    String crop = 'limit',
  }) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';

    const uploadMarker = '/image/upload/';
    final markerIndex = trimmed.indexOf(uploadMarker);
    if (markerIndex == -1) return trimmed;

    final transformations = <String>[
      'f_auto',
      'q_auto',
      'c_$crop',
      'w_$width',
      if (height != null) 'h_$height',
    ].join(',');

    final prefix = trimmed.substring(0, markerIndex + uploadMarker.length);
    final rest = trimmed.substring(markerIndex + uploadMarker.length);

    final segments = rest.split('/');
    if (segments.isNotEmpty &&
        (segments[0].contains('f_auto') ||
            segments[0].contains('q_auto') ||
            segments[0].contains('w_') ||
            segments[0].contains('c_limit') ||
            segments[0].contains('c_fill'))) {
      return '$prefix$transformations/${segments.sublist(1).join('/')}';
    }

    return '$prefix$transformations/$rest';
  }

  /// Resolves the deterministic Cloudinary CDN URL for a stall photo
  static String getStallPhotoUrl(String stallId, {int width = 800}) {
    final cleanId = stallId.trim();
    if (cleanId.isEmpty) return '';
    return getOptimizedImageUrl('${baseDeliveryUrl}merkadogo/stalls/$cleanId.jpg', width: width);
  }

  /// Resolves the deterministic Cloudinary CDN URL for an entrance gate photo
  static String getEntrancePhotoUrl(int entranceId, {int width = 800}) {
    return getOptimizedImageUrl('${baseDeliveryUrl}merkadogo/entrances/entry_$entranceId.jpg', width: width);
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
        debugPrint('[CloudinaryService] Failed: Cloudinary upload failed: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[CloudinaryService] Error: Cloudinary upload error: $e');
      return null;
    }
  }

  /// Evicts an image URL and all its transformed variants from in-memory and disk caches.
  static Future<void> evictImage(String? url) async {
    if (url == null || url.trim().isEmpty) return;
    final clean = url.trim();

    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (_) {}

    try {
      await CachedNetworkImage.evictFromCache(clean);
    } catch (_) {}

    try {
      final opt800 = getOptimizedImageUrl(clean, width: 800);
      if (opt800 != clean) {
        await CachedNetworkImage.evictFromCache(opt800);
      }
    } catch (_) {}

    try {
      final opt200 = getOptimizedImageUrl(clean, width: 200);
      if (opt200 != clean) {
        await CachedNetworkImage.evictFromCache(opt200);
      }
    } catch (_) {}
  }

  /// Upload profile image bytes to Cloudinary
  static Future<String?> uploadProfileImageBytes(
      Uint8List bytes, String userId) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return uploadImageBytes(
      bytes,
      folder: 'merkadogo/profiles',
      publicId: 'user_${userId}_$timestamp',
    );
  }

  /// Upload stall image bytes to Cloudinary
  static Future<String?> uploadStallImageBytes(
    Uint8List bytes, {
    String? stallId,
    Function(int sent, int total)? onProgress,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final resolvedPublicId = (stallId != null && stallId.isNotEmpty)
        ? '${stallId}_$timestamp'
        : null;
    return uploadImageBytes(
      bytes,
      folder: 'merkadogo/stalls',
      publicId: resolvedPublicId,
      onProgress: onProgress,
    );
  }

  /// Upload entrance gate image bytes to Cloudinary
  static Future<String?> uploadEntranceImageBytes(
    Uint8List bytes, {
    required int entranceId,
    Function(int sent, int total)? onProgress,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return uploadImageBytes(
      bytes,
      folder: 'merkadogo/entrances',
      publicId: 'entry_${entranceId}_$timestamp',
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