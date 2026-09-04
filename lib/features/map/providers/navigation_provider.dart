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
  final init = ref.watch(pathfindingInitProvider);
  final service = ref.watch(pathfindingServiceProvider);
  if (service.entryPoints.isNotEmpty) {
    return service.entryPoints;
  }
  return init.maybeWhen(
    data: (_) => service.entryPoints,
    orElse: () => service.entryPoints,
  );
});

/// Currently selected starting entrance gate (Null by default until chosen by user)
final selectedEntranceProvider = StateProvider<MarketEntryPoint?>((ref) {
  return null;
});

/// Active navigation route state notifier
class ActiveRouteNotifier extends StateNotifier<NavigationRoute?> {
  final Ref _ref;

  ActiveRouteNotifier(this._ref) : super(null);

  /// Calculate route from chosen or default entrance to destination stall
  Future<void> navigateToStall({
    required String stallId,
    String? stallName,
    MarketEntryPoint? entranceOverride,
  }) async {
    final service = _ref.read(pathfindingServiceProvider);
    if (!service.isInitialized) {
      await service.initialize();
    }

    final entrance = entranceOverride ??
        _ref.read(selectedEntranceProvider) ??
        service.findNearestEntranceByWalkingDistance(stallId) ??
        (service.entryPoints.isNotEmpty ? service.entryPoints.first : null);
    if (entrance == null) return;

    // Update selected entrance state
    _ref.read(selectedEntranceProvider.notifier).state = entrance;

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

/// Trigger counter to replay the walking traversal animation on the map
final routeTraversalTriggerProvider = StateProvider<int>((ref) => 0);

