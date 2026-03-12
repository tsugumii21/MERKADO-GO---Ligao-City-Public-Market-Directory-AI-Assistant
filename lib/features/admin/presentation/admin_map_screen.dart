import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../../models/stall_model.dart';
import '../../../core/router/route_names.dart';

class AdminMapScreen extends StatefulWidget {
  const AdminMapScreen({super.key});

  @override
  State<AdminMapScreen> createState() => _AdminMapScreenState();
}

class _AdminMapScreenState extends State<AdminMapScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  List<StallModel> _allStalls = [];
  bool _isLoading = true;

  // Ligao City Public Market coordinates
  static const LatLng _ligaoMarketCenter = LatLng(13.241861, 123.538917);
  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: _ligaoMarketCenter,
    zoom: 18.0,
  );

  @override
  void initState() {
    super.initState();
    _loadStalls();
  }

  @override
  void dispose() {
    _mapController?.dispose();
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
        });
        _createMarkers();
      }
    } catch (e) {
      debugPrint('Error loading stalls: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _createMarkers() {
    final markers = <Marker>{};

    for (var stall in _allStalls) {
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
          icon: BitmapDescriptor.defaultMarkerWithHue(
            stall.isActive ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
          ),
          onTap: () => _onMarkerTapped(stall),
        ),
      );
    }

    setState(() => _markers = markers);
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
          
          // Stall Info
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: stall.photoUrls.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          stall.photoUrls.first,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Icon(Icons.store, size: 30, color: Color(0xFF666666)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stall.name,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF212121),
                      ),
                    ),
                    Text(
                      stall.category.replaceAll('_', ' ').toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF666666),
                      ),
                    ),
                    Text(
                      'Lat: ${stall.latitude.toStringAsFixed(6)}, Lng: ${stall.longitude.toStringAsFixed(6)}',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: const Color(0xFF999999),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Action Buttons
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                context.pop(); // Close bottom sheet
                context.push('${RouteNames.adminEditStall.replaceAll(':id', stall.stallId)}');
              },
              icon: const Icon(Icons.edit, size: 18),
              label: Text(
                'Edit Stall Details',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                context.pop(); // Close bottom sheet
                _showEditLocationDialog(stall);
              },
              icon: const Icon(Icons.edit_location, size: 18),
              label: Text(
                'Edit Location on Map',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1B5E20),
                side: const BorderSide(color: Color(0xFF1B5E20)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
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
    // Show banner and enable tap-to-set-location
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
              setState(() {
                // Remove temporary marker if any
              });
            },
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    // Add map tap listener for one-time location update
    setState(() {
      // Enable location editing mode by adding temporary onTap handler
      // This is a simplified version; full implementation would use overlay
    });
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
              // Navigate to add stall screen with coordinates pre-filled
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            onMapCreated: (controller) => _mapController = controller,
            initialCameraPosition: _initialCameraPosition,
            markers: _markers,
            mapType: MapType.hybrid,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onLongPress: _onMapLongPress,
            padding: const EdgeInsets.only(bottom: 80), // Space for bottom nav
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

          // Top Info Card
          Positioned(
            top: 60,
            left: 16,
            right: 16,
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Color(0xFF1B5E20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Admin Map View',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF212121),
                            ),
                          ),
                          Text(
                            '${_allStalls.length} stall${_allStalls.length != 1 ? 's' : ''} • Tap markers to edit',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: const Color(0xFF666666),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _loadStalls,
                      icon: const Icon(Icons.refresh, color: Color(0xFF1B5E20)),
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Legend
          Positioned(
            bottom: 100,
            right: 16,
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on, color: Colors.green, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Active',
                          style: GoogleFonts.poppins(fontSize: 11),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on, color: Colors.red, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Inactive',
                          style: GoogleFonts.poppins(fontSize: 11),
                        ),
                      ],
                    ),
                  ],
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
