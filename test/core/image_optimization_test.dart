import 'package:flutter_test/flutter_test.dart';
import 'package:merkado_go/core/services/cloudinary_service.dart';

void main() {
  group('CloudinaryService Image Optimization Tests', () {
    test('transforms raw Cloudinary URL with default parameters (WebP/AVIF, q_auto, w_800)', () {
      const rawUrl =
          'https://res.cloudinary.com/diiuzmjnk/image/upload/v1740000000/merkadogo/entrances/entry_1.jpg';
      final optimized = CloudinaryService.getOptimizedImageUrl(rawUrl);

      expect(
        optimized,
        'https://res.cloudinary.com/diiuzmjnk/image/upload/f_auto,q_auto,c_limit,w_800/v1740000000/merkadogo/entrances/entry_1.jpg',
      );
    });

    test('transforms with custom width and crop parameters', () {
      const rawUrl =
          'https://res.cloudinary.com/diiuzmjnk/image/upload/merkadogo/stalls/stall_abc.jpg';
      final optimized = CloudinaryService.getOptimizedImageUrl(
        rawUrl,
        width: 200,
        height: 200,
        crop: 'fill',
      );

      expect(
        optimized,
        'https://res.cloudinary.com/diiuzmjnk/image/upload/f_auto,q_auto,c_fill,w_200,h_200/merkadogo/stalls/stall_abc.jpg',
      );
    });

    test('replaces existing transformation parameters without duplicating segments', () {
      const existingTransformedUrl =
          'https://res.cloudinary.com/diiuzmjnk/image/upload/f_auto,q_auto,c_limit,w_800/v12345/merkadogo/photo.jpg';
      final updated = CloudinaryService.getOptimizedImageUrl(
        existingTransformedUrl,
        width: 200,
      );

      expect(
        updated,
        'https://res.cloudinary.com/diiuzmjnk/image/upload/f_auto,q_auto,c_limit,w_200/v12345/merkadogo/photo.jpg',
      );
    });

    test('leaves non-Cloudinary external URLs unmodified', () {
      const externalUrl = 'https://firebasestorage.googleapis.com/v0/b/bucket/o/image.jpg?alt=media';
      final result = CloudinaryService.getOptimizedImageUrl(externalUrl);

      expect(result, externalUrl);
    });

    test('handles empty or blank input gracefully', () {
      expect(CloudinaryService.getOptimizedImageUrl(''), '');
      expect(CloudinaryService.getOptimizedImageUrl('   '), '');
    });

    test('getStallPhotoUrl generates optimized CDN URL', () {
      final stallUrl = CloudinaryService.getStallPhotoUrl('slot_42');
      expect(
        stallUrl,
        'https://res.cloudinary.com/diiuzmjnk/image/upload/f_auto,q_auto,c_limit,w_800/merkadogo/stalls/slot_42.jpg',
      );

      final customWidthStallUrl = CloudinaryService.getStallPhotoUrl('slot_42', width: 400);
      expect(
        customWidthStallUrl,
        'https://res.cloudinary.com/diiuzmjnk/image/upload/f_auto,q_auto,c_limit,w_400/merkadogo/stalls/slot_42.jpg',
      );

      expect(CloudinaryService.getStallPhotoUrl(''), '');
    });

    test('getEntrancePhotoUrl generates optimized CDN URL', () {
      final entranceUrl = CloudinaryService.getEntrancePhotoUrl(3);
      expect(
        entranceUrl,
        'https://res.cloudinary.com/diiuzmjnk/image/upload/f_auto,q_auto,c_limit,w_800/merkadogo/entrances/entry_3.jpg',
      );

      final thumbUrl = CloudinaryService.getEntrancePhotoUrl(3, width: 200);
      expect(
        thumbUrl,
        'https://res.cloudinary.com/diiuzmjnk/image/upload/f_auto,q_auto,c_limit,w_200/merkadogo/entrances/entry_3.jpg',
      );
    });
  });
}
