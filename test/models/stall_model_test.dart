import 'package:flutter_test/flutter_test.dart';
import 'package:merkado_go/models/stall_model.dart';

void main() {
  group('StallModel Photo URL Resolution Tests', () {
    test('primaryPhotoUrl returns empty string when photoUrls is empty (no blind Cloudinary fallback)', () {
      final stall = StallModel(
        stallId: 'id_10',
        name: 'Sample Stall',
        category: 'Fish',
        products: const ['Tilapia'],
        address: 'Stall 10',
        photoUrls: const [],
        openTime: '5:00 AM',
        closeTime: '6:00 PM',
        daysOpen: const ['Monday', 'Tuesday'],
        latitude: 13.24,
        longitude: 123.53,
        isActive: true,
        updatedAt: DateTime.now(),
      );

      expect(stall.primaryPhotoUrl, isEmpty);
    });

    test('primaryPhotoUrl returns first valid URL when photoUrls is populated', () {
      const sampleUrl = 'https://res.cloudinary.com/diiuzmjnk/image/upload/v12345/merkadogo/stalls/id_10.jpg';
      final stall = StallModel(
        stallId: 'id_10',
        name: 'Sample Stall',
        category: 'Fish',
        products: const ['Tilapia'],
        address: 'Stall 10',
        photoUrls: const [sampleUrl],
        openTime: '5:00 AM',
        closeTime: '6:00 PM',
        daysOpen: const ['Monday', 'Tuesday'],
        latitude: 13.24,
        longitude: 123.53,
        isActive: true,
        updatedAt: DateTime.now(),
      );

      expect(stall.primaryPhotoUrl, equals(sampleUrl));
    });

    test('primaryPhotoUrl ignores whitespace-only photoUrls', () {
      final stall = StallModel(
        stallId: 'id_10',
        name: 'Sample Stall',
        category: 'Fish',
        products: const ['Tilapia'],
        address: 'Stall 10',
        photoUrls: const ['   ', ''],
        openTime: '5:00 AM',
        closeTime: '6:00 PM',
        daysOpen: const ['Monday', 'Tuesday'],
        latitude: 13.24,
        longitude: 123.53,
        isActive: true,
        updatedAt: DateTime.now(),
      );

      expect(stall.primaryPhotoUrl, isEmpty);
    });
  });
}
