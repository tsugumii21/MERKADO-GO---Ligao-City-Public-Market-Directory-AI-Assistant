// Part 6: Interactive Market Map with camera bounds locked to market area
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/stall_model.dart';
import '../../../providers/stall_provider.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();
  
  // Ligao City Public Market coordinates (exact location from Google Maps)
  static const LatLng _ligaoMarketCenter = LatLng(13.2419233, 123.5385460);
  
  // Strict market boundary (tight around the two main buildings)
  static final LatLngBounds _marketBounds = LatLngBounds(
    southwest: const LatLng(13.2409233, 123.5375460),
    northeast: const LatLng(13.2429233, 123.5395460),
  );
  
  Set<Marker> _markers = {};
  List<StallModel> _allStalls = [];
  List<StallModel> _filteredStalls = [];
  StallModel? _selectedStall;
  bool _isSearching = false;
  String _searchMode = ''; // 'name' or 'ingredient'
  MapType _currentMapType = MapType.hybrid; // Default to hybrid mode

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    // Fit map to market bounds on creation
    Future.delayed(const Duration(milliseconds: 500), () {
      controller.animateCamera(
        CameraUpdate.newLatLngBounds(_marketBounds, 40),
      );
    });
  }

  void _onCameraMove(CameraPosition position) {
    // Enforce boundary - snap back to center if user pans outside
    if (!_marketBounds.contains(position.target)) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(_ligaoMarketCenter),
      );
    }
  }

  void _toggleMapType() {
    setState(() {
      _currentMapType = _currentMapType == MapType.hybrid
          ? MapType.normal
          : MapType.hybrid;
    });
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

  void _createMarkers(List<StallModel> stalls, {List<StallModel>? highlightStalls}) {
    final markers = <Marker>{};
    
    for (final stall in stalls) {
      final isHighlighted = highlightStalls?.contains(stall) ?? false;
      final isSelected = _selectedStall?.stallId == stall.stallId;
      
      // Optimized marker colors for hybrid/satellite mode
      double hue;
      double alpha;
      
      if (isSelected) {
        hue = BitmapDescriptor.hueYellow;
        alpha = 1.0;
      } else if (isHighlighted) {
        hue = BitmapDescriptor.hueOrange;
        alpha = 1.0;
      } else {
        hue = BitmapDescriptor.hueGreen;
        alpha = 0.7;
      }
      
      markers.add(
        Marker(
          markerId: MarkerId(stall.stallId),
          position: LatLng(stall.latitude, stall.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          alpha: alpha,
          infoWindow: InfoWindow(
            title: stall.name,
            snippet: stall.category,
          ),
          onTap: () => _onMarkerTapped(stall),
        ),
      );
    }
    
    setState(() {
      _markers = markers;
    });
  }

  void _onMarkerTapped(StallModel stall) {
    setState(() {
      _selectedStall = stall;
    });
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _filteredStalls = [];
        _searchMode = '';
      });
      _createMarkers(_allStalls);
      _recenterMap();
      return;
    }

    final queryLower = query.toLowerCase().trim();
    
    // Mode A: Search by stall name
    final nameMatches = _allStalls.where((stall) {
      return stall.name.toLowerCase().contains(queryLower);
    }).toList();
    
    // Mode B: Search by ingredient/product
    final productMatches = _allStalls.where((stall) {
      return stall.products.any((product) => 
        product.toLowerCase().contains(queryLower)
      );
    }).toList();
    
    List<StallModel> results;
    String mode;
    
    if (nameMatches.isNotEmpty) {
      // Prefer name matches (Mode A)
      results = nameMatches;
      mode = 'name';
    } else if (productMatches.isNotEmpty) {
      // Fall back to ingredient matches (Mode B)
      results = productMatches;
      mode = 'ingredient';
    } else {
      // No matches
      results = [];
      mode = '';
    }
    
    setState(() {
      _isSearching = true;
      _filteredStalls = results;
      _searchMode = mode;
    });
    
    _createMarkers(_allStalls, highlightStalls: results);
    
    if (results.isNotEmpty) {
      _animateToStalls(results);
    }
  }

  void _animateToCameraPosition(LatLng position, double zoom) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(position, zoom),
    );
  }

  void _animateToStalls(List<StallModel> stalls) {
    if (stalls.isEmpty) return;
    
    if (stalls.length == 1) {
      // Single stall: zoom to it
      _animateToCameraPosition(
        LatLng(stalls.first.latitude, stalls.first.longitude),
        19.5,
      );
    } else {
      // Multiple stalls: fit bounds
      final bounds = _calculateBounds(stalls);
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 80),
      );
    }
  }

  LatLngBounds _calculateBounds(List<StallModel> stalls) {
    double minLat = stalls.first.latitude;
    double maxLat = stalls.first.latitude;
    double minLng = stalls.first.longitude;
    double maxLng = stalls.first.longitude;
    
    for (final stall in stalls) {
      if (stall.latitude < minLat) minLat = stall.latitude;
      if (stall.latitude > maxLat) maxLat = stall.latitude;
      if (stall.longitude < minLng) minLng = stall.longitude;
      if (stall.longitude > maxLng) maxLng = stall.longitude;
    }
    
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final stallsAsync = ref.watch(allStallsProvider);
    
    return Scaffold(
      body: stallsAsync.when(
        data: (stalls) {
          if (_allStalls.isEmpty || _allStalls.length != stalls.length) {
            _allStalls = stalls;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _createMarkers(stalls);
            });
          }
          
          return Stack(
            children: [
              // Google Map with strict camera bounds (hybrid mode)
              GoogleMap(
                onMapCreated: _onMapCreated,
                onCameraMove: _onCameraMove,
                initialCameraPosition: const CameraPosition(
                  target: _ligaoMarketCenter,
                  zoom: 19.0,
                ),
                markers: _markers,
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                compassEnabled: true,
                rotateGesturesEnabled: true,
                tiltGesturesEnabled: false,
                scrollGesturesEnabled: true,
                zoomGesturesEnabled: true,
                trafficEnabled: false,
                buildingsEnabled: false,
                indoorViewEnabled: false,
                mapType: _currentMapType,
                minMaxZoomPreference: const MinMaxZoomPreference(18.0, 21.0),
                cameraTargetBounds: CameraTargetBounds(_marketBounds),
              ),
              
              // Search bar overlay
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 72,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search bar container
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          color: const Color(0xFF212121),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search stalls or ingredients...',
                          hintStyle: GoogleFonts.poppins(
                            fontSize: 15,
                            color: const Color(0xFF9E9E9E),
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: colorScheme.primary,
                            size: 22,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                  color: const Color(0xFF9E9E9E),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    
                    // Search results indicator
                    if (_isSearching && _filteredStalls.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _searchMode == 'name'
                                  ? Icons.store_rounded
                                  : Icons.inventory_2_rounded,
                              size: 16,
                              color: colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _searchMode == 'name'
                                  ? '${_filteredStalls.length} stall${_filteredStalls.length > 1 ? 's' : ''} found'
                                  : '${_filteredStalls.length} stall${_filteredStalls.length > 1 ? 's' : ''} sell this',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _filteredStalls.map((s) => s.category).toSet().join(', '),
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    // No results message
                    if (_isSearching && _filteredStalls.isEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: Color(0xFFFF9800),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'No stalls found',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF757575),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Map type toggle button (top right)
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                right: 16,
                child: Tooltip(
                  message: _currentMapType == MapType.hybrid ? 'Satellite View' : 'Map View',
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _toggleMapType,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.layers_rounded,
                            color: Color(0xFF1B5E20),
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              // Zoom controls (right side, centered vertically)
              Positioned(
                right: 16,
                top: MediaQuery.of(context).size.height * 0.45,
                child: Column(
                  children: [
                    // Zoom In button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            _mapController?.animateCamera(
                              CameraUpdate.zoomIn(),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.add_rounded,
                              color: Color(0xFF1B5E20),
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 1),
                    
                    // Divider line
                    Container(
                      width: 44,
                      height: 1,
                      color: const Color(0xFFE0E0E0),
                    ),
                    
                    const SizedBox(height: 1),
                    
                    // Zoom Out button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            _mapController?.animateCamera(
                              CameraUpdate.zoomOut(),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.remove_rounded,
                              color: Color(0xFF1B5E20),
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Recenter button (bottom right)
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
                          color: Colors.black.withOpacity(0.2),
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
              
              // Draggable stall detail sheet
              if (_selectedStall != null)
                DraggableScrollableSheet(
                  initialChildSize: 0.35,
                  minChildSize: 0.35,
                  maxChildSize: 0.85,
                  builder: (context, scrollController) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 30,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: ListView(
                        controller: scrollController,
                        padding: EdgeInsets.zero,
                        children: [
                          // Drag handle
                          Center(
                            child: Container(
                              margin: const EdgeInsets.only(top: 12, bottom: 8),
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0E0E0),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Close button and category badge
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.store_rounded,
                                            size: 14,
                                            color: colorScheme.primary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _selectedStall!.category,
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: colorScheme.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded),
                                      onPressed: () {
                                        setState(() {
                                          _selectedStall = null;
                                        });
                                      },
                                      color: const Color(0xFF757575),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 12),
                                
                                // Stall name
                                Text(
                                  _selectedStall!.name,
                                  style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1B5E20),
                                    height: 1.2,
                                  ),
                                ),
                                
                                const SizedBox(height: 8),
                                
                                // Address
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      size: 16,
                                      color: Color(0xFF757575),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        _selectedStall!.address,
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          color: const Color(0xFF757575),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 12),
                                
                                // Operating hours
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.access_time_rounded,
                                        size: 18,
                                        color: Color(0xFF1B5E20),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${_selectedStall!.openTime} - ${_selectedStall!.closeTime}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF212121),
                                            ),
                                          ),
                                          Text(
                                            _selectedStall!.daysOpen.join(', '),
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              color: const Color(0xFF757575),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Products section
                                Text(
                                  'Products Available',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF212121),
                                  ),
                                ),
                                
                                const SizedBox(height: 8),
                                
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _selectedStall!.products.map((product) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(
                                          color: const Color(0xFFE0E0E0),
                                          width: 1,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        product,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF424242),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                
                                const SizedBox(height: 20),
                                
                                // View full details button
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      // TODO: Navigate to stall detail screen (Part 7)
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Full stall details coming in Part 7!',
                                            style: GoogleFonts.poppins(),
                                          ),
                                          backgroundColor: colorScheme.primary,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colorScheme.primary,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: Text(
                                      'View Full Details',
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          );
        },
        loading: () => Container(
          color: const Color(0xFF1B5E20),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  color: Colors.white,
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading market map...',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 60,
                  color: colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading map',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.error,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
