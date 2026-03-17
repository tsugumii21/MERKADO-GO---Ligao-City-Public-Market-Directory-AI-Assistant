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

    _openMarkerIcon ??= await _createMarkerIcon(const Color(0xFF2E7D32));
    _closedMarkerIcon ??= await _createMarkerIcon(const Color(0xFFC62828));

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
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
                color: const Color(0xFFE0E0E0),
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
                        color: const Color(0xFF212121),
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
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF4CAF50)),
                      ),
                      child: Text(
                        StallUtils.getCategoryLabel(stall.category),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF2E7D32),
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
                        color: const Color(0xFF9E9E9E),
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
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
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
                height: 52,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    side: const BorderSide(color: Color(0xFF1B5E20), width: 1.5),
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
                      const Icon(Icons.location_on_rounded, size: 18, color: Color(0xFF1B5E20)),
                      const SizedBox(width: 8),
                      Text(
                        'Edit Location on Map',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1B5E20),
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
                height: 52,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    side: const BorderSide(color: Color(0xFFE53935), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => _deleteStall(stall),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.delete_rounded, size: 18, color: Color(0xFFE53935)),
                      const SizedBox(width: 8),
                      Text(
                        'Delete Stall',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFE53935),
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
        border: Border.all(color: const Color(0xFFE0E0E0)),
        color: const Color(0xFFF5F5F5),
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
                  return Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: const Color(0xFF1B5E20),
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
      color: const Color(0xFFE8F5E9),
      child: const Icon(
        Icons.store_rounded,
        color: Color(0xFF4CAF50),
        size: 32,
      ),
    );
  }

  Future<void> _deleteStall(StallModel stall) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text(
          'Delete Stall?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete "${stall.name}"?\n\nThis action cannot be undone.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: const Color(0xFF666666)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(color: Colors.white),
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
              backgroundColor: const Color(0xFF2E7D32),
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
              backgroundColor: const Color(0xFFE53935),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Edit Location',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Tap anywhere on the map to set a new location for "${stall.name}".',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: const Color(0xFF666666)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              context.pop();
              _enterEditLocationMode(stall);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('OK', style: GoogleFonts.poppins()),
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
        backgroundColor: const Color(0xFF1B5E20),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).clearMaterialBanners();
              setState(() {});
            },
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.white),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Add Stall Here?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set stall location at:',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Lat: ${position.latitude.toStringAsFixed(6)}\nLng: ${position.longitude.toStringAsFixed(6)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: Color(0xFF666666),
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
              style: GoogleFonts.poppins(color: const Color(0xFF666666)),
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
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Add Stall Here', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.poppins(
          fontSize: 13,
          color: const Color(0xFF212121),
        ),
        decoration: InputDecoration(
          hintText: 'Search stalls...',
          hintStyle: GoogleFonts.poppins(
            fontSize: 13,
            color: const Color(0xFF9E9E9E),
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF1B5E20),
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.clear_rounded,
                    color: Color(0xFF9E9E9E),
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
            vertical: 14,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5E9),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                bottomLeft: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2E7D32),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$openCount Open',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 28,
            color: const Color(0xFFE0E0E0),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: const BoxDecoration(
              color: Color(0xFFFFEBEE),
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFC62828),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$closedCount Closed',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFC62828),
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
                  color: Color(0xFF1B5E20),
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
            top: topInset + 12 + 48 + 8,
            left: 16,
            child: _buildOpenClosedCountBadge(),
          ),

          // Recenter button (bottom right) - same as user map
          Positioned(
            bottom: 100,
            right: 16,
            child: Tooltip(
              message: 'Back to Market',
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1B5E20),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _recenterMap,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 50,
                      height: 50,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.center_focus_strong_rounded,
                        color: Colors.white,
                        size: 24,
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
        backgroundColor: const Color(0xFF1B5E20),
        icon: const Icon(Icons.add_location_rounded, color: Colors.white),
        label: Text(
          'Add Stall',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

}
