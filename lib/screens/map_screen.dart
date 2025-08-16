// lib/screens/map_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:fuuuuck/services/beach_data_service.dart';
import 'package:fuuuuck/models/beach_model.dart';
import 'package:fuuuuck/screens/add_beach_screen.dart';
import 'package:fuuuuck/screens/beach_detail_screen.dart';
import 'package:fuuuuck/screens/migration_screen.dart'; // Add this import
import 'package:fuuuuck/util/metric_ranges.dart'; // normalization if available

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

  // Circle "heatmap"
  final Set<Circle> _heatCircles = {};

  // Public methods that can be called from AppBar
  void toggleMarkers() {
    setState(() {
      _showMarkers = !_showMarkers;
    });
  }

  void setActiveMetric(String? key) {
    setState(() {
      _activeMetricKey = key;
      _heatCircles.clear(); // rebuild on next frame
    });
  }

  void clearHeatmap() {
    setState(() {
      _activeMetricKey = null;
      _heatCircles.clear();
    });
  }

  // Add method to navigate to migration screen
  void _navigateToMigration() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MigrationScreen()),
    );
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

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

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

  void _rebuildHeatCircles(List<Beach> beaches) {
    _heatCircles.clear();
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

    // Circle sizing (meters). Tune as you like.
    const double minRadius = 120.0;
    const double maxRadius = 1600.0;

    for (final b in beaches) {
      final v = b.aggregatedMetrics[key];
      if (v == null) continue;

      final normLinear = ((v - vMin) / (vMax - vMin)).clamp(0.0, 1.0);
      final norm = normLinear;

      if (norm <= 0.02) continue; // skip tiny values

      final radius = _lerp(minRadius, maxRadius, norm);
      final color = _colorFromNorm(norm, alpha: 110);

      _heatCircles.add(
        Circle(
          circleId: CircleId('${b.id}::$key'),
          center: LatLng(b.latitude, b.longitude),
          radius: radius,
          fillColor: color,
          strokeColor: color.withAlpha(math.min(180, color.alpha + 40)),
          strokeWidth: 1,
          zIndex: 1,
        ),
      );
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Beaches'),
        actions: [
          // TEMP: Migration button - remove after migration is complete
          IconButton(
            tooltip: 'Migration Tool',
            icon: const Icon(Icons.sync_alt),
            onPressed: _navigateToMigration,
          ),

          // Toggle markers on/off
          IconButton(
            tooltip: _showMarkers ? 'Hide markers' : 'Show markers',
            icon: Icon(_showMarkers ? Icons.location_pin : Icons.location_off),
            onPressed: () => setState(() => _showMarkers = !_showMarkers),
          ),

          // Layers menu (pick a metric from the bar)
          PopupMenuButton<String?>(
            tooltip: 'Heatmap layer',
            icon: const Icon(Icons.layers),
            onSelected: (val) {
              setState(() {
                _activeMetricKey = val;   // null => no layer
                _heatCircles.clear();     // rebuild on next frame
              });
            },
            itemBuilder: (context) {
              final keys = _metricKeys.toList()
                ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
              return <PopupMenuEntry<String?>>[
                const PopupMenuItem<String?>(
                  value: null,
                  child: Text('None'),
                ),
                const PopupMenuDivider(),
                ...keys.map((k) => PopupMenuItem<String?>(
                  value: k,
                  child: Text(k),
                )),
              ];
            },
          ),

          // Clear heatmap
          if (_activeMetricKey != null)
            IconButton(
              tooltip: 'Clear heatmap',
              icon: const Icon(Icons.layers_clear),
              onPressed: () => setState(() {
                _activeMetricKey = null;
                _heatCircles.clear();
              }),
            ),
        ],
      ),
      body: _currentPosition == null
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

              // Markers
              final markers = _showMarkers
                  ? beaches
                  .map((b) => Marker(
                markerId: MarkerId(b.id),
                position: LatLng(b.latitude, b.longitude),
                onTap: () => setState(() => _selectedBeach = b),
                infoWindow: _activeMetricKey != null && b.aggregatedMetrics[_activeMetricKey!] != null
                    ? InfoWindow(
                  title: b.name,
                  snippet:
                  '${_activeMetricKey!}: ${b.aggregatedMetrics[_activeMetricKey!]!.toStringAsFixed(1)}',
                )
                    : InfoWindow(title: b.name),
              ))
                  .toSet()
                  : <Marker>{};

              // Rebuild circles when data or metric changes
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _rebuildHeatCircles(beaches);
              });

              return GoogleMap(
                initialCameraPosition: CameraPosition(target: _currentPosition!, zoom: 10),
                onMapCreated: _onMapCreated,
                onCameraMove: (pos) => _onCameraMove(pos),
                onCameraIdle: () async {
                  if (_mapController != null) {
                    _currentBounds = await _safeVisibleRegion(_mapController!);
                  }
                },
                onTap: (_) => setState(() => _selectedBeach = null),
                markers: markers,
                circles: _heatCircles,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: false,
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
                        Text(_selectedBeach!.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
              top: MediaQuery.of(context).padding.top + 10,
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
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddBeachScreen,
        tooltip: 'Add New Beach',
        child: const Icon(Icons.add_location_alt),
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