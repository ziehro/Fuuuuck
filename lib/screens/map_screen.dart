// lib/screens/map_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:fuuuuck/main.dart';

import 'package:fuuuuck/services/beach_data_service.dart';
import 'package:fuuuuck/services/settings_service.dart';
import 'package:fuuuuck/models/beach_model.dart';
import 'package:fuuuuck/screens/add_beach_screen.dart';
import 'package:fuuuuck/screens/beach_detail_screen.dart';
import 'package:fuuuuck/screens/migration_screen.dart';
import 'package:fuuuuck/util/metric_ranges.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => MapScreenState();

  // Static method to get metric keys for the AppBar menu
  static Set<String> getMetricKeys() => _metricKeys;

  // Metric keys to offer as layers
  static const Set<String> _metricKeys = {
    // Composition
    'Sand','Pebbles','Rocks','Boulders','Stone','Mud','Coal','Midden',
    // Flora
    'Kelp Beach','Seaweed Beach','Seaweed Rocks',
    // Driftwood
    'Kindling','Firewood','Logs','Trees',
    // Fauna
    'Anemones','Barnacles','Bugs','Clams','Limpets','Mussels','Oysters','Snails','Turtles',
  };
}

class MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  Stream<List<Beach>>? _beachesStream;
  Beach? _selectedBeach;

  bool _showSearchAreaButton = false;
  LatLng? _lastMapCenter;
  LatLngBounds? _currentBounds;

  // Layering
  String? _activeMetricKey; // null => no layer
  bool _showMarkers = true;

  // Circle "heatmap" with beach references
  final Set<Circle> _heatCircles = {};
  final Map<String, Beach> _circleToBeachMap = {}; // Maps circle ID to beach

  // Current zoom level for circle sizing
  double _currentZoom = 10.0;

  // Public methods that can be called from AppBar
  void toggleMarkers() {
    setState(() {
      _showMarkers = !_showMarkers;
    });
  }

  void setActiveMetric(String? key) {
    setState(() {
      _activeMetricKey = key;
      // Auto-hide markers when a layer is active
      if (key != null) {
        _showMarkers = false;
      }
      _heatCircles.clear();
      _circleToBeachMap.clear();
    });
  }

  void clearHeatmap() {
    setState(() {
      _activeMetricKey = null;
      // Restore markers when clearing heatmap
      _showMarkers = true;
      _heatCircles.clear();
      _circleToBeachMap.clear();
    });
  }

  @override
  void initState() {
    super.initState();
    _determineInitialPosition();
  }

  Future<void> _determineInitialPosition() async {
    try {
      final permission = await Permission.locationWhenInUse.request();
      if (!permission.isGranted) {
        _toast('Location permission is required to find nearby beaches.');
        setState(() => _currentPosition = const LatLng(49.2827, -123.1207)); // Vancouver
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() => _currentPosition = LatLng(pos.latitude, pos.longitude));
    } catch (e) {
      _toast('Failed to get current location: $e');
      setState(() => _currentPosition = const LatLng(49.2827, -123.1207));
    }
  }

  Future<void> _loadBeachesForVisibleRegion() async {
    if (_mapController == null) return;
    final visibleBounds = await _safeVisibleRegion(_mapController!);
    final beachDataService = Provider.of<BeachDataService>(context, listen: false);

    setState(() {
      _beachesStream = beachDataService.getBeachesNearby(bounds: visibleBounds);
      _currentBounds = visibleBounds;
      _showSearchAreaButton = false;
      _lastMapCenter = LatLng(
        (visibleBounds.northeast.latitude + visibleBounds.southwest.latitude) / 2,
        (visibleBounds.northeast.longitude + visibleBounds.southwest.longitude) / 2,
      );
    });
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<LatLngBounds> _safeVisibleRegion(GoogleMapController c) async {
    try {
      return await c.getVisibleRegion();
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 100));
      return c.getVisibleRegion();
    }
  }

  void _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;
    if (_currentPosition != null) {
      controller.animateCamera(CameraUpdate.newLatLngZoom(_currentPosition!, 10));
    }
    _currentBounds = await _safeVisibleRegion(controller);
    await _loadBeachesForVisibleRegion();
  }

  void _onCameraMove(CameraPosition position) {
    // Track zoom level for circle sizing
    _currentZoom = position.zoom;

    if (_lastMapCenter == null) return;
    final distance = Geolocator.distanceBetween(
      _lastMapCenter!.latitude, _lastMapCenter!.longitude,
      position.target.latitude, position.target.longitude,
    );
    if (distance > 2000 && !_showSearchAreaButton) {
      setState(() => _showSearchAreaButton = true);
    }
  }

  void _navigateToAddBeachScreen() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AddBeachScreen()));
  }

  // Handle taps on circles
  void _onCircleTap(String circleId) {
    final beach = _circleToBeachMap[circleId];
    if (beach != null) {
      setState(() => _selectedBeach = beach);
    }
  }

  // Handle taps on the map (for deselecting)
  void _onMapTap(LatLng position) {
    setState(() => _selectedBeach = null);
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  // ---- Circle heatmap helpers ----

  // Legend gradient colors (low -> high). Keep alpha 255; we apply alpha separately.
  static const List<Color> _grad = [
    Color(0xFF00BCD4), // low (teal)
    Color(0xFF8BC34A), // mid (green)
    Color(0xFFFFC107), // high (amber)
    Color(0xFFF44336), // very high (red)
  ];

  Color _lerpColor(Color a, Color b, double t) {
    return Color.fromARGB(
      (a.alpha + (b.alpha - a.alpha) * t).round(),
      (a.red + (b.red - a.red) * t).round(),
      (a.green + (b.green - a.green) * t).round(),
      (a.blue + (b.blue - a.blue) * t).round(),
    );
  }

  // Map 0..1 -> gradient color
  Color _colorFromNorm(double t, {int alpha = 110}) {
    t = t.clamp(0.0, 1.0);
    final pos = t * (_grad.length - 1);
    final i = pos.floor();
    final f = pos - i;
    if (i >= _grad.length - 1) return _grad.last.withAlpha(alpha);
    final c = _lerpColor(_grad[i], _grad[i + 1], f);
    return c.withAlpha(alpha);
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  // Calculate radius based on zoom level for better visibility
  double _getRadiusForZoom(double baseRadius) {
    // Zoom levels: 1 (world) to 20 (building)
    // At zoom 5, circles should be very large
    // At zoom 15, circles should be smaller

    // Exponential scaling based on zoom
    // Lower zoom (zoomed out) = larger circles
    // Higher zoom (zoomed in) = smaller circles

    final zoomFactor = math.pow(1.5, (12 - _currentZoom)).toDouble();
    return (baseRadius * zoomFactor).clamp(100.0, 5000.0);
  }

  void _rebuildHeatCircles(List<Beach> beaches) {
    _heatCircles.clear();
    _circleToBeachMap.clear();

    final key = _activeMetricKey;
    if (key == null) {
      setState(() {});
      return;
    }

    // Normalize by metricRanges if available, else by viewport values
    final range = metricRanges[key];
    double vMin, vMax;
    if (range != null) {
      vMin = range.min.toDouble();
      vMax = range.max.toDouble();
    } else {
      final vals = beaches.map((b) => b.aggregatedMetrics[key]).whereType<double>().toList()..sort();
      if (vals.isEmpty) {
        setState(() {});
        return;
      }
      vMin = vals.first;
      vMax = vals.last;
      if (vMax == vMin) vMax = vMin + 1.0;
    }

    // Base circle sizing (meters) - will be adjusted by zoom
    const double minRadius = 200.0;
    const double maxRadius = 800.0;

    for (final b in beaches) {
      final v = b.aggregatedMetrics[key];
      if (v == null) continue;

      final normLinear = ((v - vMin) / (vMax - vMin)).clamp(0.0, 1.0);
      final norm = normLinear;

      if (norm <= 0.02) continue; // skip tiny values

      final baseRadius = _lerp(minRadius, maxRadius, norm);
      final radius = _getRadiusForZoom(baseRadius); // Adjust for zoom
      final color = _colorFromNorm(norm, alpha: 120);

      final circleId = '${b.id}::$key';

      _heatCircles.add(
        Circle(
          circleId: CircleId(circleId),
          center: LatLng(b.latitude, b.longitude),
          radius: radius,
          fillColor: color,
          strokeColor: color.withAlpha(math.min(200, color.alpha + 60)),
          strokeWidth: 2,
          zIndex: 1,
          consumeTapEvents: true,
          onTap: () => _onCircleTap(circleId), // Add tap callback
        ),
      );

      // Map circle ID to beach for tap handling
      _circleToBeachMap[circleId] = b;
    }

    setState(() {});
  }

  // Helper method to convert settings to MapType
  MapType _getMapType(String style) {
    switch (style) {
      case 'satellite':
        return MapType.satellite;
      case 'hybrid':
        return MapType.hybrid;
      case 'terrain':
        return MapType.terrain;
      case 'normal':
      default:
        return MapType.normal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsService = Provider.of<SettingsService>(context);

    return _currentPosition == null
        ? const Center(child: CircularProgressIndicator(semanticsLabel: 'Getting your location...'))
        : Stack(
      children: [
        StreamBuilder<List<Beach>>(
          stream: _beachesStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(semanticsLabel: 'Loading beaches...'));
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final beaches = snapshot.data ?? [];

            // Markers - respect settings for labels and only show when no heatmap is active
            final markers = _showMarkers && _activeMetricKey == null
                ? beaches
                .map((b) => Marker(
              markerId: MarkerId(b.id),
              position: LatLng(b.latitude, b.longitude),
              onTap: () => setState(() => _selectedBeach = b),
              // Show/hide info window based on settings
              infoWindow: settingsService.showMarkerLabels
                  ? InfoWindow(title: b.name)
                  : InfoWindow.noText,
            ))
                .toSet()
                : <Marker>{};

            // Rebuild circles when data, metric, or zoom changes
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _rebuildHeatCircles(beaches);
            });

            return GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentPosition!,
                zoom: settingsService.defaultZoomLevel, // Use settings zoom
              ),
              onMapCreated: _onMapCreated,
              onCameraMove: (pos) => _onCameraMove(pos),
              onCameraIdle: () async {
                if (_mapController != null) {
                  _currentBounds = await _safeVisibleRegion(_mapController!);
                  // Rebuild circles on zoom change
                  if (_activeMetricKey != null) {
                    final currentBeaches = beaches;
                    _rebuildHeatCircles(currentBeaches);
                  }
                }
              },
              onTap: _onMapTap, // Deselect on map tap
              markers: markers,
              circles: _heatCircles,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: false,
              // Apply map style from settings
              mapType: _getMapType(settingsService.mapStyle),
            );
          },
        ),

        // Legend (only when a layer is active)
        if (_activeMetricKey != null)
          Positioned(
            left: 16,
            right: 88, // Leave space for FAB (56px) + margin (32px)
            bottom: 16 + MediaQuery.of(context).padding.bottom,
            child: _LegendBar(label: _activeMetricKey!),
          ),

        if (_selectedBeach != null)
          Positioned(
            bottom: 100,
            left: 20,
            right: 20,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => BeachDetailScreen(beachId: _selectedBeach!.id)),
                );
              },
              child: Card(
                elevation: 5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedBeach!.name,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (_activeMetricKey != null &&
                              _selectedBeach!.aggregatedMetrics[_activeMetricKey!] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_activeMetricKey!}: ${_selectedBeach!.aggregatedMetrics[_activeMetricKey!]!.toStringAsFixed(1)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(_selectedBeach!.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Adaptive "Search this area"
        if (_showSearchAreaButton)
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.search),
                label: Text('Search this area${_activeMetricKey != null ? ' • ${_activeMetricKey!}' : ''}'),
                onPressed: _loadBeachesForVisibleRegion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
                ),
              ),
            ),
          ),

        // Map Style Switcher Button (positioned to not overlap "my location" button)
        Positioned(
          bottom: _selectedBeach != null ? 220 : 120, // Above FAB and beach card
          right: 10,
          child: FloatingActionButton.small(
            heroTag: 'mapStyleButton',
            backgroundColor: Colors.white,
            onPressed: () => _showQuickMapStylePicker(settingsService),
            tooltip: 'Change Map Style',
            child: Icon(
              _getMapStyleIcon(settingsService.mapStyle),
              color: Theme.of(context).primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  // Get icon for current map style
  IconData _getMapStyleIcon(String style) {
    switch (style) {
      case 'satellite':
        return Icons.satellite_alt;
      case 'hybrid':
        return Icons.layers;
      case 'terrain':
        return Icons.terrain;
      case 'normal':
      default:
        return Icons.map;
    }
  }

  // Quick map style picker
  void _showQuickMapStylePicker(SettingsService settingsService) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Map Style',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('Standard'),
              trailing: settingsService.mapStyle == 'normal'
                  ? const Icon(Icons.check, color: seafoamGreen)
                  : null,
              onTap: () {
                settingsService.setMapStyle('normal');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.satellite_alt),
              title: const Text('Satellite'),
              trailing: settingsService.mapStyle == 'satellite'
                  ? const Icon(Icons.check, color: seafoamGreen)
                  : null,
              onTap: () {
                settingsService.setMapStyle('satellite');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.layers),
              title: const Text('Hybrid'),
              trailing: settingsService.mapStyle == 'hybrid'
                  ? const Icon(Icons.check, color: seafoamGreen)
                  : null,
              onTap: () {
                settingsService.setMapStyle('hybrid');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.terrain),
              title: const Text('Terrain'),
              trailing: settingsService.mapStyle == 'terrain'
                  ? const Icon(Icons.check, color: seafoamGreen)
                  : null,
              onTap: () {
                settingsService.setMapStyle('terrain');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---- UI helpers -------------------------------------------------------------

class _LegendBar extends StatelessWidget {
  final String label;
  const _LegendBar({required this.label});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Container(
              height: 12,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF00BCD4), // low
                    Color(0xFF8BC34A), // mid
                    Color(0xFFFFC107), // high
                    Color(0xFFF44336), // very high
                  ],
                ),
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [Text('low'), Text('high')],
            ),
          ],
        ),
      ),
    );
  }
}