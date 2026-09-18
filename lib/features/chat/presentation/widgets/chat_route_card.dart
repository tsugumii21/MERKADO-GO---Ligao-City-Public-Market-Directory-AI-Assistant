import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/stall_utils.dart';
import '../../../../core/widgets/main_shell.dart' show mainShellKey;
import '../../../../models/stall_model.dart';
import '../../../../providers/stall_provider.dart';
import '../../../map/domain/navigation_models.dart';
import '../../../map/presentation/widgets/navigation_loading_dialog.dart';
import '../../../map/providers/navigation_provider.dart';
import '../../../map/services/pathfinding_service.dart';
import '../../domain/chat_route_action.dart';

/// Clean, responsive in-chat transit ticket card providing 1-tap route initiation
class ChatRouteCard extends ConsumerWidget {
  final ChatRouteAction action;
  final VoidCallback? onClose;

  const ChatRouteCard({
    super.key,
    required this.action,
    this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stalls = ref.watch(allStallsProvider).asData?.value ?? [];
    final entryPoints = ref.watch(entryPointsProvider);
    final activeRoute = ref.watch(activeRouteProvider);
    final pathService = ref.watch(pathfindingServiceProvider);

    // 1. Resolve destination stall
    final destStall = _findStall(
      stalls,
      action.destinationStallId,
      action.destinationStallName,
    );

    // 2. Resolve origin (entrance or stall)
    final isStallOrigin = action.originType == 'stall';
    final originStall = isStallOrigin
        ? _findStall(stalls, action.originId ?? '', null)
        : null;

    final originEntrance = !isStallOrigin
        ? _findEntrance(entryPoints, action.originId, destStall, pathService)
        : null;

    // 3. Compute route metrics preview if pathfinding service is ready
    int? distanceMeters;
    String? walkDurationStr;

    if (destStall != null && pathService.isInitialized) {
      if (isStallOrigin && originStall != null) {
        final previewRoute = pathService.findStallToStallRoute(
          originStallId: originStall.stallId,
          destinationStallId: destStall.stallId,
          originName: originStall.name,
          destinationName: destStall.name,
        );
        if (previewRoute != null) {
          distanceMeters = previewRoute.totalEstimatedMeters.round();
          walkDurationStr = previewRoute.estimatedWalkingTimeFormatted;
        }
      } else if (originEntrance != null) {
        final previewRoute = pathService.findRoute(
          entranceNodeId: originEntrance.nodeId,
          destinationStallId: destStall.stallId,
          destinationName: destStall.name,
        );
        if (previewRoute != null) {
          distanceMeters = previewRoute.totalEstimatedMeters.round();
          walkDurationStr = previewRoute.estimatedWalkingTimeFormatted;
        }
      }
    }

    final isReroute = activeRoute != null;
    final destName = destStall?.name ?? action.destinationStallName ?? 'Market Stall';
    final destSection = destStall?.section?.trim().isNotEmpty == true
        ? destStall!.section!.trim()
        : 'Market Complex';
    final destStallNum = destStall?.stallNumber?.trim().isNotEmpty == true
        ? destStall!.stallNumber!.trim()
        : '';
    final isOpen = destStall != null ? StallUtils.isStallOpenNow(destStall) : true;

    final originLabel = isStallOrigin
        ? (originStall?.name ?? 'Starting Stall')
        : (originEntrance != null
            ? 'Gate ${originEntrance.entranceId} (${originEntrance.description})'
            : 'Nearest Entrance Gate');

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs + 2,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5E9),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppSpacing.cardRadius - 1),
                topRight: Radius.circular(AppSpacing.cardRadius - 1),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isReroute ? Icons.alt_route_rounded : Icons.navigation_rounded,
                  size: 15,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    isReroute ? 'REROUTE SUGGESTION' : 'NAVIGATION ROUTE',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AppColors.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                if (destStall != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isOpen ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isOpen ? 'OPEN' : 'CLOSED',
                      style: GoogleFonts.poppins(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: isOpen ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Route Origin & Destination Timeline
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Column(
              children: [
                // Origin Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary,
                          width: 2.5,
                        ),
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        originLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF4B5563),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                // Vertical Connector
                Container(
                  margin: const EdgeInsets.only(left: 6, top: 2, bottom: 2),
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 2,
                    height: 14,
                    color: const Color(0xFFD1D5DB),
                  ),
                ),

                // Destination Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.location_on_rounded,
                          size: 9,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            destName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.0,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF111827),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            destStallNum.isNotEmpty
                                ? '$destStallNum • $destSection'
                                : destSection,
                            style: GoogleFonts.poppins(
                              fontSize: 11.0,
                              color: const Color(0xFF6B7280),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Metrics Pill Row (Distance & Duration)
          if (distanceMeters != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '~$distanceMeters meters',
                      style: GoogleFonts.poppins(
                        fontSize: 11.0,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF374151),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  if (walkDurationStr != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        walkDurationStr,
                        style: GoogleFonts.poppins(
                          fontSize: 11.0,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF4B5563),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          const SizedBox(height: AppSpacing.xs),

          // Action Button
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: SizedBox(
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                ),
                onPressed: () => _handleStartNavigation(
                  context: context,
                  ref: ref,
                  destStall: destStall,
                  originEntrance: originEntrance,
                  originStall: originStall,
                  isStallOrigin: isStallOrigin,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isReroute ? Icons.alt_route_rounded : Icons.directions_walk_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        isReroute ? 'Reroute Navigation' : 'Start Navigation',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.0,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleStartNavigation({
    required BuildContext context,
    required WidgetRef ref,
    required StallModel? destStall,
    required MarketEntryPoint? originEntrance,
    required StallModel? originStall,
    required bool isStallOrigin,
  }) async {
    if (destStall == null) return;

    // 1. Capture required notifiers and state synchronously before widget dismissal
    final activeNotifier = ref.read(activeRouteProvider.notifier);
    final selectedEntranceNotifier = ref.read(selectedEntranceProvider.notifier);
    final routeTraversalNotifier = ref.read(routeTraversalTriggerProvider.notifier);
    final pathService = ref.read(pathfindingServiceProvider);
    final currentSelectedEntrance = ref.read(selectedEntranceProvider);
    final availableEntryPoints = ref.read(entryPointsProvider);

    final chosenEntrance = isStallOrigin
        ? null
        : (originEntrance ??
            currentSelectedEntrance ??
            pathService.findNearestEntranceByWalkingDistance(destStall.stallId) ??
            (availableEntryPoints.isNotEmpty ? availableEntryPoints.first : null));

    if (chosenEntrance != null) {
      selectedEntranceNotifier.state = chosenEntrance;
    }

    // 2. Haptic feedback
    unawaited(HapticFeedback.mediumImpact());

    // 3. Dismiss chat modal
    if (onClose != null) {
      onClose!();
    } else {
      await Navigator.of(context).maybePop();
    }

    // 4. Switch to Map Tab (tab 0)
    mainShellKey.currentState?.goToTab(0);

    // 5. Trigger Navigation asynchronously using pre-captured notifiers
    if (isStallOrigin && originStall != null) {
      await NavigationLoadingDialog.show(
        null,
        stallName: destStall.name,
        originName: originStall.name,
      );
      await activeNotifier.navigateStallToStall(
        originStallId: originStall.stallId,
        destinationStallId: destStall.stallId,
        originStallName: originStall.name,
        destinationStallName: destStall.name,
      );
    } else {
      await NavigationLoadingDialog.show(
        null,
        stallName: destStall.name,
        entrance: chosenEntrance,
      );

      await activeNotifier.navigateToStall(
        stallId: destStall.stallId,
        stallName: destStall.name,
        entranceOverride: chosenEntrance,
      );
    }

    // 6. Trigger avatar walking traversal animation on the map
    routeTraversalNotifier.state++;
  }

  StallModel? _findStall(
    List<StallModel> stalls,
    String queryId,
    String? queryName,
  ) {
    final cleanId = queryId.trim().toLowerCase();
    final cleanName = (queryName ?? '').trim().toLowerCase();

    // Direct stallId match (e.g. "id_27")
    for (final s in stalls) {
      if (s.stallId.toLowerCase() == cleanId) return s;
    }

    // Number extraction match (e.g. "27" in "STALL #27")
    final numMatch = RegExp(r'\d+').firstMatch(cleanId);
    if (numMatch != null) {
      final numStr = numMatch.group(0)!;
      for (final s in stalls) {
        if (s.stallNumber?.contains(numStr) == true) return s;
      }
    }

    // Exact or substring name match
    if (cleanName.isNotEmpty) {
      for (final s in stalls) {
        if (s.name.toLowerCase() == cleanName) return s;
      }
      for (final s in stalls) {
        if (s.name.toLowerCase().contains(cleanName) ||
            cleanName.contains(s.name.toLowerCase())) {
          return s;
        }
      }
    }

    return null;
  }

  MarketEntryPoint? _findEntrance(
    List<MarketEntryPoint> entryPoints,
    String? originId,
    StallModel? destStall,
    PathfindingService pathService,
  ) {
    if (entryPoints.isEmpty) return null;

    final query = (originId ?? '').trim().toLowerCase();

    // Check for gate number (e.g. "2" in "Gate 2" or "2")
    final numMatch = RegExp(r'\d+').firstMatch(query);
    if (numMatch != null) {
      final gateNum = int.tryParse(numMatch.group(0)!);
      if (gateNum != null) {
        for (final ep in entryPoints) {
          if (ep.entranceId == gateNum) return ep;
        }
      }
    }

    // Check nodeId match (e.g. "node_ex_2")
    for (final ep in entryPoints) {
      if (ep.nodeId.toLowerCase() == query) return ep;
    }

    // Fallback: nearest entrance to destination stall
    if (destStall != null && pathService.isInitialized) {
      return pathService.findNearestEntranceByWalkingDistance(destStall.stallId);
    }

    return entryPoints.first;
  }
}
