// Part 6: Interactive Market Map with camera bounds locked to market area
// Part 7: Updated to use StallDetailSheet with full features
// Part 9: Added Aling Suki AI Assistant as floating button
// Part 10: Manual clustering implementation for better marker management
import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../models/stall_model.dart';
import '../../../providers/stall_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../features/chat/domain/chat_message.dart';
import '../../stalls/presentation/stall_detail_sheet.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => MapScreenState();
}

class MapScreenState extends ConsumerState<MapScreen> with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();
  
  // Animation for floating Aling Suki button
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isChatOpen = false;
  
  // Manual clustering state
  double? _currentZoom = 19.0;
  static const double _clusterRadius = 0.0003; // ~30 meters at market zoom level
  
  // Performance optimization: Cache cluster bitmaps
  final Map<int, BitmapDescriptor> _clusterBitmapCache = {};
  Timer? _markerDebounce;
  
  // Ligao City Public Market coordinates (exact location from Google Maps)
  static const LatLng _ligaoMarketCenter = LatLng(13.241861, 123.538917);
  
  // Market boundary (wider to show all stalls)
  static final LatLngBounds _marketBounds = LatLngBounds(
    southwest: const LatLng(13.2410, 123.5378),
    northeast: const LatLng(13.2428, 123.5398),
  );
  
  Set<Marker> _markers = {};
  List<StallModel> _allStalls = [];
  List<StallModel> _filteredStalls = [];
  StallModel? _selectedStall;
  bool _isSearching = false;
  String _searchMode = ''; // 'name' or 'ingredient'
  MapType _currentMapType = MapType.hybrid; // Default to hybrid mode

  @override
  void initState() {
    super.initState();
    
    // Initialize pulse animation for Aling Suki button
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  // Reset UI state when user leaves this tab
  void resetUI() {
    if (!mounted) return;

    // Close stall info bottom sheet if open
    if (_selectedStall != null) {
      setState(() => _selectedStall = null);
      // Pop any open modal bottom sheets
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }

    // Close chatbot bottom sheet if open
    if (_isChatOpen) {
      setState(() => _isChatOpen = false);
      // Pop chatbot sheet if it's open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }

    // DO NOT reset: map camera, chat history, markers
  }

  @override
  void dispose() {
    _markerDebounce?.cancel();
    _mapController?.dispose();
    _searchController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    // Show the whole market area on creation
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _initMapView();
    });
  }
  
  void _initMapView() {
    if (_mapController == null) return;
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: const LatLng(13.2413, 123.5380),
          northeast: const LatLng(13.2425, 123.5395),
        ),
        60.0, // pixel padding
      ),
    );
  }

  void _onCameraMove(CameraPosition position) {
    // No bounds restriction - users can pan freely
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

  Map<String, List<StallModel>> _clusterStalls(
      List<StallModel> stalls, double zoom) {
    // At high zoom (19+), don't cluster — show all individually
    if (zoom >= 19.0) {
      return {
        for (var s in stalls) s.stallId: [s]
      };
    }

    final Map<String, List<StallModel>> clusters = {};
    final List<StallModel> assigned = [];

    for (final stall in stalls) {
      if (assigned.contains(stall)) continue;
      
      final nearby = stalls.where((other) {
        if (assigned.contains(other)) return false;
        final latDiff = (stall.latitude - other.latitude).abs();
        final lngDiff = (stall.longitude - other.longitude).abs();
        return latDiff < _clusterRadius && lngDiff < _clusterRadius;
      }).toList();

      final clusterId = 'cluster_${stall.stallId}';
      clusters[clusterId] = nearby;
      assigned.addAll(nearby);
    }

    return clusters;
  }

  Future<void> _buildMarkers(
      List<StallModel> stalls, double zoom) async {
    final clusters = _clusterStalls(stalls, zoom);
    final Set<Marker> newMarkers = {};

    for (final entry in clusters.entries) {
      final clusterStalls = entry.value;

      if (clusterStalls.length == 1) {
        // Single stall — show normal green marker
        final stall = clusterStalls.first;
        newMarkers.add(Marker(
          markerId: MarkerId(stall.stallId),
          position: LatLng(stall.latitude, stall.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(
            title: stall.name,
            snippet: '${_getCategoryLabel(stall.category)} • ${stall.openTime}',
          ),
          onTap: () => _onStallMarkerTapped(stall),
        ));
      } else {
        // Multiple stalls — show cluster bubble
        final center = LatLng(
          clusterStalls.map((s) => s.latitude)
              .reduce((a, b) => a + b) / clusterStalls.length,
          clusterStalls.map((s) => s.longitude)
              .reduce((a, b) => a + b) / clusterStalls.length,
        );

        newMarkers.add(Marker(
          markerId: MarkerId(entry.key),
          position: center,
          icon: await _buildClusterBitmap(clusterStalls.length),
          onTap: () {
            _mapController?.animateCamera(
              CameraUpdate.newLatLngZoom(
                center,
                (zoom + 1.5).clamp(18.0, 21.0),
              ),
            );
          },
        ));
      }
    }

    if (mounted) {
      setState(() => _markers = newMarkers);
    }
  }

  Future<BitmapDescriptor> _buildClusterBitmap(int clusterSize) async {
    // Return cached version if exists
    if (_clusterBitmapCache.containsKey(clusterSize)) {
      return _clusterBitmapCache[clusterSize]!;
    }

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint()..color = const Color(0xFF1B5E20);
    final double radius = clusterSize > 10 ? 30 : 24;

    // outer dark green circle
    canvas.drawCircle(Offset(radius, radius), radius, paint);

    // white border ring
    canvas.drawCircle(
      Offset(radius, radius),
      radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // white count text
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: clusterSize.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        radius - textPainter.width / 2,
        radius - textPainter.height / 2,
      ),
    );

    final img = await pictureRecorder
        .endRecording()
        .toImage((radius * 2).toInt(), (radius * 2).toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);

    final bitmap = BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
    
    // Save to cache before returning
    _clusterBitmapCache[clusterSize] = bitmap;
    return bitmap;
  }

  String _getCategoryLabel(String category) {
    switch (category.toLowerCase()) {
      case 'seafood':
      case 'fish':
        return '🐟 Seafood';
      case 'meat':
      case 'karne':
      case 'pork':
      case 'beef':
        return '🥩 Karne';
      case 'poultry':
      case 'manok':
        return '🐔 Manok';
      case 'vegetables':
      case 'gulay':
        return '🥦 Gulay';
      case 'fruits':
      case 'prutas':
        return '🍎 Prutas';
      case 'rice':
      case 'bigas':
        return '🌾 Bigas';
      case 'eatery':
        return '🍽️ Eatery';
      case 'sari-sari':
      case 'sari_sari':
        return '🏪 Sari-Sari';
      case 'spices':
      case 'pampalasa':
        return '🌶️ Pampalasa';
      case 'dry goods':
      case 'dry_goods':
        return '📦 Dry Goods';
      case 'ukay-ukay':
      case 'ukay_ukay':
        return '👕 Ukay-Ukay';
      default:
        return '🏪 Stall';
    }
  }

  void _onStallMarkerTapped(StallModel stall) {
    setState(() {
      _selectedStall = stall;
    });

    // Show full stall detail sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StallDetailSheet(
        stall: stall,
        onClose: () {
          Navigator.of(context).pop();
          setState(() {
            _selectedStall = null;
          });
        },
      ),
    );
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _filteredStalls = [];
        _searchMode = '';
      });
      _buildMarkers(_allStalls, _currentZoom ?? 18.0);
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
    
    // Update markers to show only search results
    if (results.isNotEmpty) {
      _buildMarkers(results, _currentZoom ?? 18.0);
      _animateToStalls(results);
    } else {
      _buildMarkers([], _currentZoom ?? 18.0);
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
              _buildMarkers(stalls, _currentZoom ?? 18.0);
              _initMapView();
            });
          }
          
          return Stack(
            children: [
              // Google Map with strict camera bounds (hybrid mode)
              GoogleMap(
                onMapCreated: _onMapCreated,
                onCameraMove: (position) {
                  _currentZoom = position.zoom;
                },
                onCameraIdle: () {
                  // Debounce marker rebuilding to avoid lag
                  _markerDebounce?.cancel();
                  _markerDebounce = Timer(
                    const Duration(milliseconds: 300),
                    () {
                      final stalls = _isSearching ? _filteredStalls : _allStalls;
                      _buildMarkers(stalls, _currentZoom ?? 18.0);
                    },
                  );
                },
                initialCameraPosition: const CameraPosition(
                  target: _ligaoMarketCenter,
                  zoom: 18.0,
                ),
                markers: _markers,
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                compassEnabled: false,
                rotateGesturesEnabled: true,
                tiltGesturesEnabled: false,
                scrollGesturesEnabled: true,
                zoomGesturesEnabled: true,
                trafficEnabled: false,
                buildingsEnabled: false,
                indoorViewEnabled: false,
                mapType: _currentMapType,
                minMaxZoomPreference: const MinMaxZoomPreference(16.0, 21.0),
                cameraTargetBounds: CameraTargetBounds.unbounded,
              ),
              
              // Cluster count badge (below search bar)
              if (stalls.isNotEmpty)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 74,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B5E20),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '${stalls.length} ${stalls.length == 1 ? 'stall' : 'stalls'} sa palengke',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
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
              
              // Floating Aling Suki AI Assistant button (bottom left)
              Positioned(
                bottom: 90,
                left: 16,
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _isChatOpen ? 1.0 : _pulseAnimation.value,
                      child: child,
                    );
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Main button
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2E7D32).withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _isChatOpen = true;
                              });
                              _showAlingSukiOverlay();
                            },
                            borderRadius: BorderRadius.circular(28),
                            child: const Center(
                              child: CircleAvatar(
                                backgroundColor: Colors.transparent,
                                backgroundImage: AssetImage('assets/images/aling_suki.png'),
                                radius: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // Unread badge (red dot) - show when chat has messages and is closed
                      if (!_isChatOpen && ref.watch(chatProvider).length > 1)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
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

  // Show Aling Suki chat overlay (modal bottom sheet)
  void _showAlingSukiOverlay() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AlingSukiChatSheet(),
    ).then((_) {
      setState(() {
        _isChatOpen = false;
      });
    });
  }
}

// Aling Suki Chat Overlay Widget
class _AlingSukiChatSheet extends ConsumerStatefulWidget {
  const _AlingSukiChatSheet();

  @override
  ConsumerState<_AlingSukiChatSheet> createState() => _AlingSukiChatSheetState();
}

class _AlingSukiChatSheetState extends ConsumerState<_AlingSukiChatSheet> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    
    // Scroll to bottom when sheet opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(instant: true);
    });
    
    // Refresh stall data when chat opens (without clearing chat)
    _initializeChat();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    if (_isRefreshing) return;
    
    setState(() => _isRefreshing = true);
    
    // Only refresh stall data, don't clear chat history
    await ref.read(chatProvider.notifier).refreshStalls();
    
    setState(() => _isRefreshing = false);
  }

  Future<void> _refreshStallData() async {
    if (_isRefreshing) return;
    
    setState(() => _isRefreshing = true);
    
    // Refresh stall data and clear chat to start fresh
    await ref.read(chatProvider.notifier).refreshStalls();
    ref.read(chatProvider.notifier).clearChat();
    
    setState(() => _isRefreshing = false);
  }

  void _scrollToBottom({bool instant = false}) {
    if (!_scrollController.hasClients) return;
    
    if (instant) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    } else {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    
    ref.read(chatProvider.notifier).sendMessage(text);
    _inputController.clear();
    _scrollToBottom();
  }

  void _sendSuggestion(String suggestion) {
    ref.read(chatProvider.notifier).sendMessage(suggestion);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatProvider);
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final hasUserMessages = messages.where((m) => m.role == 'user').isNotEmpty;

    // Scroll to bottom when messages update
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (messages.isNotEmpty && messages.last.isStreaming) {
        _scrollToBottom();
      }
    });

    return Container(
      height: screenHeight * 0.7 + keyboardHeight,
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFBDBDBD),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5E9),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE0E0E0), width: 1),
              ),
            ),
            child: Row(
              children: [
                // Avatar
                const CircleAvatar(
                  backgroundColor: Colors.white,
                  backgroundImage: AssetImage('assets/images/aling_suki.png'),
                  radius: 20,
                ),
                const SizedBox(width: 12),
                
                // Name and status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Aling Suki',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1B5E20),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Online indicator
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4CAF50),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Inyong Market Guide 🛒',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Refresh button
                IconButton(
                  icon: _isRefreshing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Color(0xFF1B5E20)),
                          ),
                        )
                      : const Icon(Icons.refresh_rounded),
                  color: const Color(0xFF1B5E20),
                  onPressed: _isRefreshing ? null : _refreshStallData,
                  tooltip: 'Reset Chat',
                ),
                
                // Close button
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  color: const Color(0xFF666666),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),

          // Quick suggestions (show only when no user messages)
          if (!hasUserMessages) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mga tanong na maaari mong itanong:',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF666666),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildSuggestionChip('Saan makakabili ng sariwang isda?'),
                        _buildSuggestionChip('Which stalls are open right now?'),
                        _buildSuggestionChip('Saan ang karne at manok section?'),
                        _buildSuggestionChip('Ilan lahat ng stalls sa palengke?'),
                        _buildSuggestionChip('Nasaan ang dry goods area?'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Input bar
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 12 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Color(0xFFE0E0E0), width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    onSubmitted: (_) => _sendMessage(),
                    onChanged: (_) => setState(() {}),
                    style: GoogleFonts.poppins(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Magtanong kay Aling Suki...',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 14,
                        color: const Color(0xFF9E9E9E),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Send button
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _inputController.text.trim().isEmpty
                        ? const Color(0xFFBDBDBD)
                        : const Color(0xFF1B5E20),
                    shape: BoxShape.circle,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _inputController.text.trim().isEmpty
                          ? null
                          : _sendMessage,
                      borderRadius: BorderRadius.circular(22),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
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
  }

  Widget _buildSuggestionChip(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: const Color(0xFF1B5E20),
          ),
        ),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFF1B5E20), width: 1),
        onPressed: () => _sendSuggestion(text),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.role == 'user';
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            // Small avatar for Aling Suki
            const CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage: AssetImage('assets/images/aling_suki.png'),
              radius: 12,
            ),
            const SizedBox(width: 8),
          ],
          Container(
            constraints: BoxConstraints(maxWidth: screenWidth * 0.75),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: isUser ? const Color(0xFF1B5E20) : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(isUser ? 18 : 4),
                topRight: const Radius.circular(18),
                bottomLeft: const Radius.circular(18),
                bottomRight: Radius.circular(isUser ? 4 : 18),
              ),
            ),
            child: message.isStreaming
                ? _buildTypingIndicator()
                : isUser
                    ? Text(
                        message.content,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white,
                          height: 1.5,
                        ),
                      )
                    : MarkdownBody(
                        data: message.content,
                        softLineBreak: true,
                        styleSheet: MarkdownStyleSheet(
                          p: GoogleFonts.poppins(
                            fontSize: 14,
                            color: const Color(0xFF212121),
                            height: 1.5,
                          ),
                          strong: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF212121),
                            height: 1.5,
                          ),
                          listBullet: GoogleFonts.poppins(
                            fontSize: 14,
                            color: const Color(0xFF212121),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (index) => _TypingDot(delay: index * 200),
      ),
    );
  }
}

// Typing indicator animation
class _TypingDot extends StatefulWidget {
  final int delay;
  
  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: Container(
        width: 8,
        height: 8,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: const BoxDecoration(
          color: Color(0xFF1B5E20),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
