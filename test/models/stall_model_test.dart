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

  group('StallModel Map Location & Removal Tests', () {
    test('hasMapLocation is true and mapStallId resolves when physicalStallId is set', () {
      final stall = StallModel(
        stallId: 'doc_123',
        physicalStallId: 'slot_wm_52',
        name: 'Sample Meat Shop',
        category: 'Meat',
        products: const ['Pork'],
        address: 'Stall 52',
        photoUrls: const [],
        openTime: '5:00 AM',
        closeTime: '6:00 PM',
        daysOpen: const ['Monday'],
        latitude: 13.24,
        longitude: 123.53,
        isActive: true,
        updatedAt: DateTime.now(),
      );

      expect(stall.hasMapLocation, isTrue);
      expect(stall.mapStallId, equals('slot_wm_52'));
    });

    test('explicitHasMapLocation false forces hasMapLocation to false and mapStallId to empty string', () {
      final stall = StallModel(
        stallId: 'slot_wm_52',
        physicalStallId: null,
        explicitHasMapLocation: false,
        name: 'Unmapped Stall',
        category: 'Produce',
        products: const [],
        address: 'Stall 52',
        photoUrls: const [],
        openTime: '5:00 AM',
        closeTime: '6:00 PM',
        daysOpen: const ['Monday'],
        latitude: 13.24,
        longitude: 123.53,
        isActive: true,
        updatedAt: DateTime.now(),
      );

      expect(stall.hasMapLocation, isFalse);
      expect(stall.mapStallId, isEmpty);
    });

    test('copyWith(clearPhysicalStallId: true) clears physical slot and sets map location to false', () {
      final stall = StallModel(
        stallId: 'doc_123',
        physicalStallId: 'slot_wm_52',
        name: 'Sample Meat Shop',
        category: 'Meat',
        products: const ['Pork'],
        address: 'Stall 52',
        photoUrls: const [],
        openTime: '5:00 AM',
        closeTime: '6:00 PM',
        daysOpen: const ['Monday'],
        latitude: 13.24,
        longitude: 123.53,
        isActive: true,
        updatedAt: DateTime.now(),
      );

      final cleared = stall.copyWith(clearPhysicalStallId: true);

      expect(cleared.physicalStallId, isNull);
      expect(cleared.hasMapLocation, isFalse);
      expect(cleared.mapStallId, isEmpty);
    });
  });
}
