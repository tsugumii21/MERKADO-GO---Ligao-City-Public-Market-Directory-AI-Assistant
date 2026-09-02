import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/stall_model.dart';
import '../../../providers/stall_provider.dart';
import '../stalls/presentation/stall_detail_sheet.dart';
import 'presentation/widgets/market_svg_map_view.dart';

class IndoorMapScreen extends ConsumerStatefulWidget {
  const IndoorMapScreen({super.key});

  @override
  ConsumerState<IndoorMapScreen> createState() => _IndoorMapScreenState();
}

class _IndoorMapScreenState extends ConsumerState<IndoorMapScreen> {
  final GlobalKey<MarketSvgMapViewState> _svgMapKey = GlobalKey<MarketSvgMapViewState>();
  StallModel? _selectedStall;

  void _onStallSelected(StallModel stall) {
    setState(() {
      _selectedStall = stall;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StallDetailSheet(
        stall: stall,
        onClose: () {
          Navigator.of(context).pop();
          if (mounted) {
            setState(() => _selectedStall = null);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stallsAsync = ref.watch(allStallsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Public Market Floor Plan',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            Text(
              'Ligao City Public Market • Architectural Vector View',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.center_focus_strong_rounded, color: AppColors.ink),
            tooltip: 'Reset View',
            onPressed: () => _svgMapKey.currentState?.resetView(),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(height: 1.0, thickness: 1.0, color: AppColors.border),
        ),
      ),
      body: stallsAsync.when(
        data: (stalls) {
          return Stack(
            children: [
              Positioned.fill(
                child: MarketSvgMapView(
                  key: _svgMapKey,
                  stalls: stalls,
                  selectedStall: _selectedStall,
                  onStallSelected: _onStallSelected,
                ),
              ),

              // Floating Bottom Reset / Fit Button
              Positioned(
                bottom: 24,
                right: 24,
                child: FloatingActionButton.extended(
                  onPressed: () => _svgMapKey.currentState?.resetView(),
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  icon: const Icon(Icons.fit_screen_rounded, color: Colors.white),
                  label: Text(
                    'Fit Screen',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => Center(
          child: Text(
            'Error: $err',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
