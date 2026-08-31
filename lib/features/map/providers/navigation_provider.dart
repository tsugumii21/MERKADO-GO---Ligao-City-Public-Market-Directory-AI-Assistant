import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/navigation_models.dart';
import '../services/pathfinding_service.dart';

/// Singleton instance of PathfindingService
final pathfindingServiceProvider = Provider<PathfindingService>((ref) {
  return PathfindingService();
});

/// Asynchronous graph initializer provider
final pathfindingInitProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(pathfindingServiceProvider);
  if (!service.isInitialized) {
    await service.initialize();
  }
  return true;
});

/// List of all 14 market entrance gates
final entryPointsProvider = Provider<List<MarketEntryPoint>>((ref) {
  final service = ref.watch(pathfindingServiceProvider);
  return service.entryPoints;
});

/// Currently selected starting entrance gate (Defaults to Entrance 1: Straight From Church)
final selectedEntranceProvider = StateProvider<MarketEntryPoint?>((ref) {
  final entryPoints = ref.watch(entryPointsProvider);
  if (entryPoints.isEmpty) return null;
  return entryPoints.first;
});

/// Active navigation route state notifier
class ActiveRouteNotifier extends StateNotifier<NavigationRoute?> {
  final Ref _ref;

  ActiveRouteNotifier(this._ref) : super(null);

  /// Calculate route from chosen or default entrance to destination stall
  void navigateToStall({
    required String stallId,
    String? stallName,
    MarketEntryPoint? entranceOverride,
  }) {
    final service = _ref.read(pathfindingServiceProvider);
    if (!service.isInitialized) return;

    final entrance = entranceOverride ?? _ref.read(selectedEntranceProvider);
    if (entrance == null) return;

    final route = service.findRoute(
      entranceNodeId: entrance.nodeId,
      destinationStallId: stallId,
      destinationName: stallName,
    );

    state = route;
    _ref.read(currentStepIndexProvider.notifier).state = 0;
  }

  /// Clear current navigation route
  void clearRoute() {
    state = null;
    _ref.read(currentStepIndexProvider.notifier).state = 0;
  }
}

final activeRouteProvider =
    StateNotifierProvider<ActiveRouteNotifier, NavigationRoute?>((ref) {
  return ActiveRouteNotifier(ref);
});

/// Current active navigation instruction step index (0-indexed)
final currentStepIndexProvider = StateProvider<int>((ref) => 0);
