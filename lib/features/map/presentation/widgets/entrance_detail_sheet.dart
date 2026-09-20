import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/cloudinary_service.dart';
import '../../../../core/widgets/image_shimmer_placeholder.dart';
import '../../../../providers/user_provider.dart';
import '../../domain/navigation_models.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/entrance_provider.dart';
import 'navigation_loading_dialog.dart';
import '../../../admin/presentation/widgets/admin_edit_entrance_sheet.dart';

/// Modal bottom sheet displaying detailed entrance information, photograph, and routing actions.
class EntranceDetailSheet extends ConsumerWidget {
  final MarketEntryPoint entrance;
  final VoidCallback onClose;
  final bool isAdmin;
  final VoidCallback? onEdit;
  final VoidCallback? onStartRoute;
  final VoidCallback? onClearSelection;

  const EntranceDetailSheet({
    super.key,
    required this.entrance,
    required this.onClose,
    this.isAdmin = false,
    this.onEdit,
    this.onStartRoute,
    this.onClearSelection,
  });

  static Future<void> show(
    BuildContext context,
    MarketEntryPoint entrance, {
    bool isAdmin = false,
    VoidCallback? onEdit,
    VoidCallback? onStartRoute,
    VoidCallback? onClearSelection,
  }) {
    final rawUrl = entrance.imageUrl?.trim();
    if (rawUrl != null && rawUrl.isNotEmpty) {
      try {
        final optimizedUrl =
            CloudinaryService.getOptimizedImageUrl(rawUrl, width: 800);
        precacheImage(CachedNetworkImageProvider(optimizedUrl), context)
            .catchError((_) {});
      } catch (_) {}
    }

    bool effectiveAdmin = isAdmin;
    if (!effectiveAdmin) {
      try {
        effectiveAdmin =
            GoRouterState.of(context).uri.toString().startsWith('/admin');
      } catch (_) {
        // GoRouter not mounted or unavailable in test environments
      }
    }

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.40),
      sheetAnimationStyle: AnimationStyle(
        duration: const Duration(milliseconds: 360),
        curve: const Cubic(0.16, 1.0, 0.3, 1.0),
        reverseDuration: const Duration(milliseconds: 260),
        reverseCurve: Curves.easeInCubic,
      ),
      builder: (ctx) => EntranceDetailSheet(
        entrance: entrance,
        onClose: () => Navigator.of(ctx).pop(),
        isAdmin: effectiveAdmin,
        onEdit: onEdit,
        onStartRoute: onStartRoute,
        onClearSelection: onClearSelection,
      ),
    );
  }

  void _handleStartRoute(BuildContext context, WidgetRef ref) async {
    unawaited(HapticFeedback.selectionClick());
    ref.read(selectedEntranceProvider.notifier).state = entrance;

    final targetStall = ref.read(pickingOriginTargetStallProvider);
    final activeRoute = ref.read(activeRouteProvider);
    final activeRouteNotifier = ref.read(activeRouteProvider.notifier);

    if (targetStall != null) {
      final destStallId = targetStall.stallId;
      final destStallName = targetStall.name;
      ref.read(pickingOriginTargetStallProvider.notifier).state = null;
      ref.read(isPickingEntranceOnMapProvider.notifier).state = false;
      onStartRoute?.call();
      Navigator.of(context).pop();

      await NavigationLoadingDialog.show(
        null,
        stallName: destStallName,
        entrance: entrance,
      );

      await activeRouteNotifier.navigateToStall(
        stallId: destStallId,
        stallName: destStallName,
        entranceOverride: entrance,
      );
      return;
    }

    if (activeRoute != null && activeRoute.destinationStallId.isNotEmpty) {
      final destStallId = activeRoute.destinationStallId;
      final destStallName = activeRoute.destinationStallName;
      ref.read(pickingOriginTargetStallProvider.notifier).state = null;
      ref.read(isPickingEntranceOnMapProvider.notifier).state = false;
      onStartRoute?.call();
      Navigator.of(context).pop();

      await NavigationLoadingDialog.show(
        null,
        stallName: destStallName,
        entrance: entrance,
      );

      await activeRouteNotifier.navigateToStall(
        stallId: destStallId,
        stallName: destStallName,
        entranceOverride: entrance,
      );
      return;
    }

    onStartRoute?.call();

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Starting route set from ${entrance.displayName}',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _handleClearSelection(BuildContext context, WidgetRef ref) {
    HapticFeedback.selectionClick();
    ref.read(selectedEntranceProvider.notifier).state = null;

    final activeRoute = ref.read(activeRouteProvider);
    if (activeRoute != null && activeRoute.destinationStallId.isNotEmpty) {
      ref.read(activeRouteProvider.notifier).clearRoute();
    }

    onClearSelection?.call();

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Starting entrance selection cleared',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF334155),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch for live updates from firestore/entrances provider
    final allEntrances = ref.watch(marketEntrancesProvider);
    final liveEntrance = allEntrances.firstWhere(
      (e) => e.entranceId == entrance.entranceId,
      orElse: () => entrance,
    );

    final currentUser = ref.watch(userDataStreamProvider).value;
    final userIsAdmin = isAdmin || (currentUser?.role == 'admin');
    final selectedEntrance = ref.watch(selectedEntranceProvider);
    final targetStall = ref.watch(pickingOriginTargetStallProvider);
    final isPickingEntranceOnMap = ref.watch(isPickingEntranceOnMapProvider);
    final isPickingMode = targetStall != null || isPickingEntranceOnMap;
    final isSelected = !isPickingMode && (selectedEntrance?.entranceId == liveEntrance.entranceId);
    final mediaQuery = MediaQuery.of(context);

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: mediaQuery.size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x29000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 38,
                height: 4.5,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),

            // Header Bar with Clean Sheet Title & Close Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Entrance Details',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    visualDensity: VisualDensity.compact,
                    splashRadius: 20,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF64748B),
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 6),

                    // Hero Media Card
                    Builder(
                      builder: (context) {
                        final rawUrl = liveEntrance.imageUrl?.trim();
                        final optimizedUrl = (rawUrl != null && rawUrl.isNotEmpty)
                            ? CloudinaryService.getOptimizedImageUrl(rawUrl, width: 800)
                            : null;

                        return ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 1,
                              ),
                            ),
                            child: optimizedUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: optimizedUrl,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 800,
                                    maxWidthDiskCache: 1200,
                                    fadeInDuration: const Duration(milliseconds: 160),
                                    fadeOutDuration: const Duration(milliseconds: 100),
                                    placeholder: (context, url) =>
                                        const ImageShimmerPlaceholder(
                                      height: 200,
                                      centerIcon: Icons.door_front_door_outlined,
                                    ),
                                    errorWidget: (context, url, error) =>
                                        _buildImagePlaceholder(liveEntrance),
                                  )
                                : _buildImagePlaceholder(liveEntrance),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Entrance Title & Gate Pill
                    Builder(
                      builder: (context) {
                        final hasCustomTitle = liveEntrance.title != null &&
                            liveEntrance.title!.trim().isNotEmpty &&
                            liveEntrance.title!.trim().toLowerCase() !=
                                'gate ${liveEntrance.entranceId}';

                        final hasDistinctDescription = liveEntrance
                                .effectiveDescription.isNotEmpty &&
                            liveEntrance.effectiveDescription
                                    .toLowerCase()
                                    .trim() !=
                                liveEntrance.effectiveLandmark
                                    .toLowerCase()
                                    .trim() &&
                            liveEntrance.effectiveDescription
                                    .toLowerCase()
                                    .trim() !=
                                liveEntrance.displayName.toLowerCase().trim();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (hasCustomTitle) ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _buildGatePill(liveEntrance.entranceId),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      liveEntrance.displayName,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0F172A),
                                        height: 1.25,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              Text(
                                liveEntrance.displayName,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                  height: 1.25,
                                ),
                              ),
                            ],

                            const SizedBox(height: 10),

                            // Information Chips Row
                            if (liveEntrance.effectiveLandmark.isNotEmpty)
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildInfoChip(
                                    icon: Icons.location_on_rounded,
                                    label: liveEntrance.effectiveLandmark,
                                    iconColor: const Color(0xFF166534),
                                    bgColor: const Color(0xFFDCFCE7),
                                    borderColor: const Color(0xFF86EFAC),
                                  ),
                                ],
                              ),

                            // Description Text (only when distinct from landmark & title)
                            if (hasDistinctDescription) ...[
                              const SizedBox(height: 8),
                              Text(
                                liveEntrance.effectiveDescription,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF475569),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // Primary Action: Set as Origin / Start Route OR Clear Selection
                    if (isSelected) ...[
                      OutlinedButton.icon(
                        onPressed: () => _handleClearSelection(context, ref),
                        icon: const Icon(
                          Icons.clear_rounded,
                          size: 20,
                          color: Color(0xFFDC2626),
                        ),
                        label: Text(
                          'Clear Selection',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFDC2626),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFFEF2F2),
                          side: const BorderSide(
                            color: Color(0xFFFECACA),
                            width: 1.2,
                          ),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ] else ...[
                      ElevatedButton.icon(
                        onPressed: () => _handleStartRoute(context, ref),
                        icon: const Icon(Icons.directions_walk_rounded, size: 20),
                        label: Text(
                          'Start Route',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],

                    // Admin Quick Action (if applicable)
                    if (userIsAdmin) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          if (onEdit != null) {
                            onEdit!();
                          } else {
                            AdminEditEntranceSheet.show(
                              context,
                              liveEntrance,
                              onSaved: () {
                                ref.invalidate(firestoreEntrancesStreamProvider);
                                ref.invalidate(marketEntrancesProvider);
                              },
                            );
                          }
                        },
                        icon: const Icon(Icons.edit_note_rounded,
                            size: 20, color: Color(0xFF1E293B)),
                        label: Text(
                          'Edit Gate Photo & Details',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGatePill(int entranceId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF86EFAC),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.location_on_rounded,
            size: 14,
            color: Color(0xFF166534),
          ),
          const SizedBox(width: 4),
          Text(
            'Gate $entranceId',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF166534),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder(MarketEntryPoint entrance) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on_rounded,
              size: 28,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Gate ${entrance.entranceId} Entrance',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Ligao Public Market',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF334155),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
