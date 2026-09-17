import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/cloudinary_service.dart';
import '../domain/navigation_models.dart';
import 'navigation_provider.dart';

/// Stream provider for Firestore 'entrances' collection
final firestoreEntrancesStreamProvider =
    StreamProvider<Map<int, MarketEntryPoint>>((ref) {
  return FirebaseFirestore.instance
      .collection('entrances')
      .snapshots()
      .map((snapshot) {
    final map = <int, MarketEntryPoint>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final entranceId = (data['entrance_id'] ?? data['entranceId'] as num?)?.toInt();
      if (entranceId != null && entranceId > 0) {
        map[entranceId] = MarketEntryPoint.fromJson(data);
      }
    }
    return map;
  }).handleError((error) {
    debugPrint('Error listening to entrances stream: $error');
    return <int, MarketEntryPoint>{};
  });
});

/// Combined entrances provider that merges bundled 14 gates with Firestore custom data
final marketEntrancesProvider = Provider<List<MarketEntryPoint>>((ref) {
  final baselineEntrances = ref.watch(entryPointsProvider);
  final firestoreDataAsync = ref.watch(firestoreEntrancesStreamProvider);
  final firestoreMap = firestoreDataAsync.value ?? const <int, MarketEntryPoint>{};

  if (baselineEntrances.isEmpty) {
    return const <MarketEntryPoint>[];
  }

  final mergedList = baselineEntrances.map((baseline) {
    final remote = firestoreMap[baseline.entranceId];
    if (remote == null) {
      final defaultCdnPhoto =
          CloudinaryService.getEntrancePhotoUrl(baseline.entranceId);
      return baseline.copyWith(
        imageUrl: defaultCdnPhoto,
      );
    }

    final effectiveImage = (remote.imageUrl != null && remote.imageUrl!.trim().isNotEmpty)
        ? remote.imageUrl!.trim()
        : CloudinaryService.getEntrancePhotoUrl(baseline.entranceId);

    return baseline.copyWith(
      title: remote.title ?? baseline.title,
      description: (remote.description.isNotEmpty)
          ? remote.description
          : baseline.description,
      landmark: remote.landmark ?? baseline.landmark,
      imageUrl: effectiveImage,
      updatedAt: remote.updatedAt ?? baseline.updatedAt,
    );
  }).toList();

  mergedList.sort((a, b) => a.entranceId.compareTo(b.entranceId));
  return mergedList;
});

/// Repository service for updating entrance details in Firestore and Cloudinary
class EntranceRepository {
  final FirebaseFirestore _firestore;

  EntranceRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Upload new entrance image to Cloudinary and return secure URL
  Future<String?> uploadEntranceImage({
    required int entranceId,
    required Uint8List imageBytes,
    Function(int sent, int total)? onProgress,
  }) async {
    return CloudinaryService.uploadEntranceImageBytes(
      imageBytes,
      entranceId: entranceId,
      onProgress: onProgress,
    );
  }

  /// Save entrance metadata and image URL to Firestore
  Future<void> saveEntrance(MarketEntryPoint entrance) async {
    final docRef = _firestore.collection('entrances').doc('entrance_${entrance.entranceId}');
    final data = entrance.toMap();
    data['updated_at'] = FieldValue.serverTimestamp();

    await docRef.set(data, SetOptions(merge: true));
  }
}

/// EntranceRepository provider
final entranceRepositoryProvider = Provider<EntranceRepository>((ref) {
  return EntranceRepository();
});
