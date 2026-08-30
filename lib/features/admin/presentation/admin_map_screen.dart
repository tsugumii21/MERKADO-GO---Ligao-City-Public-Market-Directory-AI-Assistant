import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../../models/stall_model.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/stall_utils.dart';
import '../../../core/theme/app_colors.dart';

class AdminMapScreen extends StatefulWidget {
  const AdminMapScreen({super.key});

  @override
  State<AdminMapScreen> createState() => _AdminMapScreenState();
}

class _AdminMapScreenState extends State<AdminMapScreen> {
  GoogleMapController? _mapController;
  BitmapDescriptor? _openMarkerIcon;
  BitmapDescriptor? _closedMarkerIcon;
  Set<Marker> _markers = {};
  List<StallModel> _allStalls = [];
  List<StallModel> _filteredStalls = [];
  bool _isLoading = true;
  
  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Match user map behavior: show stall markers only at higher zoom
  double? _currentZoom = 19.0;
  static const double _stallVisibilityZoomThreshold = 20.0;

  // Ligao City Public Market coordinates
  static const LatLng _ligaoMarketCenter = LatLng(13.241861, 123.538917);
  static final LatLngBounds _marketBounds = LatLngBounds(
    southwest: const LatLng(13.2413, 123.5380),
    northeast: const LatLng(13.2425, 123.5395),
  );
  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(13.2419, 123.5387),
    zoom: 19.0,
  );

  @override
  void initState() {
    super.initState();
    _loadStalls();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStalls() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('stalls')
          .get();

      final stalls = snapshot.docs
          .map((doc) => StallModel.fromFirestore(doc))
          .toList();

      if (mounted) {
        setState(() {
          _allStalls = stalls;
          _filteredStalls = stalls;
        });
        await _createMarkers();
      }
    } catch (e) {
        debugPrint('❌ Error: Failed to load stalls: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(_marketBounds, 60.0),
      );
    });
  }

  void _onCameraMove(CameraPosition position) {
    if (_currentZoom != position.zoom) {
      setState(() {
        _currentZoom = position.zoom;
      });
    }
  }

  void _recenterMap() {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        const CameraPosition(
          target: _ligaoMarketCenter,
          zoom: 19.0,
        ),
      ),
    );
  }

  Future<void> _createMarkers([List<StallModel>? stalls]) async {
    final stallsToShow = stalls ?? _filteredStalls;
    final markers = <Marker>{};

    if ((_currentZoom ?? 19.0) < _stallVisibilityZoomThreshold) {
      if (mounted && _markers.isNotEmpty) {
        setState(() => _markers = {});
      }
      return;
    }

    _openMarkerIcon ??= await _createMarkerIcon(AppColors.primary);
    _closedMarkerIcon ??= await _createMarkerIcon(AppColors.error);

    for (var stall in stallsToShow) {
      // Skip stalls without coordinates
      if (stall.latitude == 0 && stall.longitude == 0) continue;

      markers.add(
        Marker(
          markerId: MarkerId(stall.stallId),
          position: LatLng(stall.latitude, stall.longitude),
          infoWindow: InfoWindow(
            title: stall.name,
            snippet: '${stall.category.replaceAll('_', ' ')} - Tap to edit',
          ),
          icon: StallUtils.isStallOpenNow(stall)
              ? _openMarkerIcon!
              : _closedMarkerIcon!,
          anchor: const Offset(0.5, 0.5),
          onTap: () => _onMarkerTapped(stall),
        ),
      );
    }

    setState(() => _markers = markers);
  }

  Future<BitmapDescriptor> _createMarkerIcon(Color markerColor) async {
    const double markerSize = 32.0;
    const double radius = markerSize / 2;
    const double iconSize = 14.0;
    const double borderWidth = 2.0;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    final fillPaint = Paint()..color = markerColor;
    canvas.drawCircle(const Offset(radius, radius), radius, fillPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawCircle(
      const Offset(radius, radius),
      radius - (borderWidth / 2),
      borderPaint,
    );

    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.storefront_rounded.codePoint),
        style: TextStyle(
          fontSize: iconSize,
          color: Colors.white,
          fontFamily: Icons.storefront_rounded.fontFamily,
          package: Icons.storefront_rounded.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    iconPainter.paint(
      canvas,
      Offset(
        radius - (iconPainter.width / 2),
        radius - (iconPainter.height / 2),
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      markerSize.toInt(),
      markerSize.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  void _filterMarkers() {
    if (_searchQuery.isEmpty) {
      setState(() {
        _filteredStalls = _allStalls;
      });
    } else {
      final filtered = _allStalls
          .where((s) =>
              s.name.toLowerCase().contains(_searchQuery) ||
              s.category.toLowerCase().contains(_searchQuery))
          .toList();
      setState(() {
        _filteredStalls = filtered;
      });
    }
    unawaited(_createMarkers());
  }

  void _onMarkerTapped(StallModel stall) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildStallActionSheet(stall),
    );
  }

  Widget _buildStallActionSheet(StallModel stall) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1.0),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Stall Info Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStallPhoto(stall),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stall.name,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Category chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        StallUtils.getCategoryLabel(stall.category),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Coordinates
                    Text(
                      'Lat: ${stall.latitude.toStringAsFixed(6)}, '
                      'Lng: ${stall.longitude.toStringAsFixed(6)}',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Action Buttons
          Column(
            children: [
              // Edit Stall Details button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    context.push(
                      '/admin/stalls/edit/${stall.stallId}',
                      extra: stall,
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit_rounded, size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Edit Stall Details',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.visible,
                        softWrap: false,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              
              // Edit Location on Map button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    side: const BorderSide(color: AppColors.primary, width: 1.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _showEditLocationDialog(stall);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Edit Location on Map',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                        overflow: TextOverflow.visible,
                        softWrap: false,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              
              // Delete Stall button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    side: const BorderSide(color: AppColors.error, width: 1.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => _deleteStall(stall),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.delete_rounded, size: 18, color: AppColors.error),
                      const SizedBox(width: 8),
                      Text(
                        'Delete Stall',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                        overflow: TextOverflow.visible,
                        softWrap: false,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStallPhoto(StallModel stall) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        color: AppColors.surfaceDim,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: stall.photoUrls.isNotEmpty &&
                stall.photoUrls.first.isNotEmpty &&
                stall.photoUrls.first.startsWith('http')
            ? Image.network(
                stall.photoUrls.first,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPhotoPlaceholder(),
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  );
                },
              )
            : _buildPhotoPlaceholder(),
      ),
    );
  }

  Widget _buildPhotoPlaceholder() {
    return Container(
      width: 72,
      height: 72,
      color: AppColors.surfaceDim,
      child: const Icon(
        Icons.store_rounded,
        color: AppColors.primary,
        size: 32,
      ),
    );
  }
  Future<void> _deleteStall(StallModel stall) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1.0),
        ),
        title: Text(
          'Delete Stall?',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${stall.name}"?\n\nThis action cannot be undone.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.inkMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.inkMuted,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('stalls')
            .doc(stall.stallId)
            .delete();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${stall.name} deleted successfully',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: AppColors.primary,
            ),
          );
          await _loadStalls();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error deleting stall: $e',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  void _showEditLocationDialog(StallModel stall) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1.0),
        ),
        title: Text(
          'Edit Location',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        content: Text(
          'Tap anywhere on the map to set a new location for "${stall.name}".',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.inkMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.inkMuted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              context.pop();
              _enterEditLocationMode(stall);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'OK',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _enterEditLocationMode(StallModel stall) {
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: Text(
          'Tap on the map to set new location for ${stall.name}',
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).clearMaterialBanners();
              setState(() {});
            },
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    setState(() {});
  }

  void _onMapLongPress(LatLng position) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1.0),
        ),
        title: Text(
          'Add Stall Here?',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set stall location at coordinates:',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceDim,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                'Lat: ${position.latitude.toStringAsFixed(6)}\nLng: ${position.longitude.toStringAsFixed(6)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: AppColors.ink,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.inkMuted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              context.pop();
              context.push(
                RouteNames.adminAddStall,
                extra: {
                  'latitude': position.latitude,
                  'longitude': position.longitude,
                },
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Add Stall Here',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1.0),
      ),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.poppins(
          fontSize: 13,
          color: AppColors.ink,
        ),
        decoration: InputDecoration(
          hintText: 'Search stalls on map...',
          hintStyle: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.inkSubtle,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.primary,
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.clear_rounded,
                    color: AppColors.inkMuted,
                    size: 18,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                    _filterMarkers();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value.trim().toLowerCase();
          });
          _filterMarkers();
        },
      ),
    );
  }

  Widget _buildOpenClosedCountBadge() {
    final stallsToCount = _searchQuery.isEmpty ? _allStalls : _filteredStalls;
    final openCount = stallsToCount.where((s) => StallUtils.isStallOpenNow(s)).length;
    final closedCount = stallsToCount.length - openCount;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                bottomLeft: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$openCount Open',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 24,
            color: AppColors.border,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: AppColors.errorLight,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$closedCount Closed',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            onMapCreated: _onMapCreated,
            onCameraMove: _onCameraMove,
            onCameraIdle: () {
              unawaited(_createMarkers());
            },
            initialCameraPosition: _initialCameraPosition,
            markers: _markers,
            mapType: MapType.satellite,
            minMaxZoomPreference: const MinMaxZoomPreference(17.0, 22.0),
            cameraTargetBounds: CameraTargetBounds.unbounded,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onLongPress: _onMapLongPress,
            padding: const EdgeInsets.only(bottom: 80),
          ),

          // Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              ),
            ),

          // Search Bar at Top
          Positioned(
            top: topInset + 12,
            left: 16,
            right: 16,
            child: _buildSearchBar(),
          ),

          // Open/Closed Count Badge
          Positioned(
            top: topInset + 12 + 46 + 8,
            left: 16,
            child: _buildOpenClosedCountBadge(),
          ),

          // Recenter button (bottom right)
          Positioned(
            bottom: 96,
            right: 16,
            child: Tooltip(
              message: 'Back to Market',
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 1.0),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _recenterMap,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.center_focus_strong_rounded,
                        color: AppColors.ink,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(RouteNames.adminAddStall),
        backgroundColor: AppColors.primary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        icon: const Icon(Icons.add_location_rounded, color: Colors.white),
        label: Text(
          'Add Stall',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
