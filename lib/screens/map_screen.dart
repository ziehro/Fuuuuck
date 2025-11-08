// lib/screens/map_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:mybeachbook/main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dart_geohash/dart_geohash.dart';

import 'package:mybeachbook/services/beach_data_service.dart';
import 'package:mybeachbook/services/settings_service.dart';
import 'package:mybeachbook/models/beach_model.dart';
import 'package:mybeachbook/screens/add_beach_screen.dart';
import 'package:mybeachbook/screens/beach_detail_screen.dart';
import 'package:mybeachbook/screens/migration_screen.dart';
import 'package:mybeachbook/util/metric_ranges.dart';
import 'package:mybeachbook/util/constants.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => MapScreenState();

  static Set<String> getMetricKeys() => _metricKeys;

  static const Set<String> _metricKeys = {
    'Sand','Pebbles','Rocks','Boulders','Stone','Mud','Coal','Midden',
    'Kelp Beach','Seaweed Beach','Seaweed Rocks',
    'Kindling','Firewood','Logs','Trees',
    'Anemones','Barnacles','Bugs','Clams','Limpets','Mussels','Oysters','Snails','Turtles',
  };

  static const Set<String> _premiumMetricKeys = {
    'Water Index',
    'Shoreline Risk',
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

  String? _activeMetricKey;
  bool _showMarkers = true;

  final Set<Circle> _heatCircles = {};
  final Map<String, Beach> _circleToBeachMap = {};

  double _currentZoom = 10.0;

  // Beach moving state
  Beach? _beachBeingMoved;
  LatLng? _newBeachPosition;
  bool _isMovingBeach = false;

  // Cached marker icons to prevent flickering
  static final BitmapDescriptor _defaultMarker = BitmapDescriptor.defaultMarker;
  static final BitmapDescriptor _greenMarker = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
  static final BitmapDescriptor _orangeMarker = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);

  // Admin check
  bool get _isAdmin {
    final currentUser = FirebaseAuth.instance.currentUser;
    return currentUser != null && AppConstants.adminUserIds.contains(currentUser.uid);
  }

  void toggleMarkers() {
    setState(() {
      _showMarkers = !_showMarkers;
    });
  }

  void setActiveMetric(String? key) {
    final settingsService = Provider.of<SettingsService>(context, listen: false);

    if (key != null && MapScreen._premiumMetricKeys.contains(key)) {
      if (!settingsService.hasPremiumAccess) {
        _showPremiumAccessDialog();
        return;
      }
    }

    setState(() {
      _activeMetricKey = key;
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
      _showMarkers = true;
      _heatCircles.clear();
      _circleToBeachMap.clear();
    });
  }

  void _showPremiumAccessDialog() {
    final TextEditingController codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Premium Feature'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This layer requires premium access.'),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Access Code',
                hintText: 'Enter your premium code',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final settingsService = Provider.of<SettingsService>(context, listen: false);
              final success = await settingsService.validateAndSetPremiumAccess(codeController.text);

              if (success && mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Premium access activated!')),
                );
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid access code')),
                );
              }
            },
            child: const Text('Activate'),
          ),
        ],
      ),
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
        setState(() => _currentPosition = const LatLng(49.2827, -123.1207));
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

  void _onCircleTap(String circleId) {
    final beach = _circleToBeachMap[circleId];
    if (beach != null) {
      setState(() => _selectedBeach = beach);
    }
  }

  void _onMapTap(LatLng position) {
    if (_isMovingBeach) {
      // If moving, update the position
      setState(() {
        _newBeachPosition = position;
      });
    } else {
      // Otherwise, deselect beach
      setState(() => _selectedBeach = null);
    }
  }

  // Beach moving functionality - initiated by button click
  void _startMovingBeach(Beach beach) {
    setState(() {
      _beachBeingMoved = beach;
      _newBeachPosition = LatLng(beach.latitude, beach.longitude);
      _isMovingBeach = true;
      _selectedBeach = null; // Clear selected beach
    });

    _toast('Tap on map or drag orange pin to new location');
  }

  Future<void> _submitMoveBeach() async {
    if (_beachBeingMoved == null || _newBeachPosition == null) return;

    // Set state BEFORE updating Firebase to prevent flickering
    final beachId = _beachBeingMoved!.id;
    final newPosition = _newBeachPosition!;

    setState(() {
      _beachBeingMoved = null;
      _newBeachPosition = null;
      _isMovingBeach = false;
    });

    // Now update Firebase
    _toast('Updating beach location...');

    try {
      final geoHasher = GeoHasher();
      final newGeohash = geoHasher.encode(
        newPosition.longitude,
        newPosition.latitude,
        precision: 9,
      );

      await FirebaseFirestore.instance
          .collection('beaches')
          .doc(beachId)
          .update({
        'latitude': newPosition.latitude,
        'longitude': newPosition.longitude,
        'geohash': newGeohash,
        'locationRefined': true,
        'locationRefinedAt': FieldValue.serverTimestamp(),
      });

      _toast('Beach location updated successfully!');
    } catch (e) {
      _toast('Failed to update location: $e');
    }
  }

  void _cancelMoveBeach() {
    setState(() {
      _beachBeingMoved = null;
      _newBeachPosition = null;
      _isMovingBeach = false;
    });
    _toast('Move cancelled');
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  static const List<Color> _grad = [
    Color(0xFF00BCD4),
    Color(0xFF8BC34A),
    Color(0xFFFFC107),
    Color(0xFFF44336),
  ];

  Color _lerpColor(Color a, Color b, double t) {
    return Color.fromARGB(
      (a.alpha + (b.alpha - a.alpha) * t).round(),
      (a.red + (b.red - a.red) * t).round(),
      (a.green + (b.green - a.green) * t).round(),
      (a.blue + (b.blue - a.blue) * t).round(),
    );
  }

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

  double _getRadiusForZoom(double baseRadius) {
    final zoomFactor = math.pow(1.5, (12 - _currentZoom)).toDouble();
    return (baseRadius * zoomFactor).clamp(100.0, 5000.0);
  }

  void _rebuildHeatCircles(List<Beach> beaches) {
    _heatCircles.clear();
    _circleToBeachMap.clear();

    final key = _activeMetricKey;
    if (key == null) {
      return;
    }

    final range = metricRanges[key];
    double vMin, vMax;

    // Get values from either aggregatedMetrics or direct beach properties
    final vals = beaches.map((b) {
      if (key == 'Water Index') return b.waterIndex;
      if (key == 'Shoreline Risk') return b.shorelineRiskProxy;
      return b.aggregatedMetrics[key];
    }).whereType<double>().toList()..sort();

    if (vals.isEmpty) {
      return;
    }

    if (range != null) {
      vMin = range.min.toDouble();
      vMax = range.max.toDouble();
    } else {
      vMin = vals.first;
      vMax = vals.last;
      if (vMax == vMin) vMax = vMin + 1.0;
    }

    const double minRadius = 200.0;
    const double maxRadius = 800.0;

    for (final b in beaches) {
      double? v;
      if (key == 'Water Index') {
        v = b.waterIndex;
      } else if (key == 'Shoreline Risk') {
        v = b.shorelineRiskProxy;
      } else {
        v = b.aggregatedMetrics[key];
      }

      if (v == null) continue;

      final normLinear = ((v - vMin) / (vMax - vMin)).clamp(0.0, 1.0);
      final norm = normLinear;

      if (norm <= 0.02) continue;

      final baseRadius = _lerp(minRadius, maxRadius, norm);
      final radius = _getRadiusForZoom(baseRadius);
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
          onTap: () => _onCircleTap(circleId),
        ),
      );

      _circleToBeachMap[circleId] = b;
    }
  }

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

            // Build markers set
            final markers = <Marker>{};

            // Add regular beach markers (only when not moving)
            if (_showMarkers && _activeMetricKey == null && !_isMovingBeach) {
              for (final b in beaches) {
                markers.add(
                  Marker(
                    markerId: MarkerId(b.id),
                    position: LatLng(b.latitude, b.longitude),
                    onTap: () => setState(() => _selectedBeach = b),
                    icon: (b.locationRefined ?? false) ? _greenMarker : _defaultMarker,
                    infoWindow: settingsService.showMarkerLabels
                        ? InfoWindow(title: b.name)
                        : InfoWindow.noText,
                  ),
                );
              }
            }

            // Add the orange draggable marker for moving (separate from beach markers)
            if (_isMovingBeach && _newBeachPosition != null && _beachBeingMoved != null) {
              markers.add(
                Marker(
                  markerId: MarkerId('moving_${_beachBeingMoved!.id}'),
                  position: _newBeachPosition!,
                  draggable: true,
                  onDragEnd: (newPosition) {
                    setState(() {
                      _newBeachPosition = newPosition;
                    });
                  },
                  icon: _orangeMarker,
                  zIndex: 1000,
                ),
              );
            }

            // Rebuild heat circles only when active metric is set
            if (_activeMetricKey != null) {
              _rebuildHeatCircles(beaches);
            }

            return GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentPosition!,
                zoom: settingsService.defaultZoomLevel,
              ),
              onMapCreated: _onMapCreated,
              onCameraMove: (pos) => _onCameraMove(pos),
              onCameraIdle: () async {
                if (_mapController != null) {
                  _currentBounds = await _safeVisibleRegion(_mapController!);
                  if (_activeMetricKey != null) {
                    final currentBeaches = beaches;
                    _rebuildHeatCircles(currentBeaches);
                  }
                }
              },
              onTap: _onMapTap,
              markers: markers,
              circles: _heatCircles,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: false,
              zoomGesturesEnabled: true,
              scrollGesturesEnabled: true,
              rotateGesturesEnabled: true,
              tiltGesturesEnabled: true,
              mapType: _getMapType(settingsService.mapStyle),
            );
          },
        ),

        // Moving beach controls overlay
        if (_isMovingBeach && _beachBeingMoved != null)
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: Center(
              child: Card(
                color: Colors.orange.shade100,
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Moving: ${_beachBeingMoved!.name}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tap on map or drag the orange pin',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _cancelMoveBeach,
                            icon: const Icon(Icons.close),
                            label: const Text('Cancel'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _submitMoveBeach,
                            icon: const Icon(Icons.check),
                            label: const Text('Submit'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        if (_activeMetricKey != null)
          Positioned(
            left: 88,
            right: 88,
            bottom: 22 + MediaQuery.of(context).padding.bottom,
            child: _LegendBar(label: _activeMetricKey!),
          ),

        // Selected beach info card with Move Pin button
        if (_selectedBeach != null && !_isMovingBeach)
          Positioned(
            bottom: 100,
            left: 20,
            right: 20,
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
                        if (_activeMetricKey != null)
                          _buildMetricBadge(_selectedBeach!),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_selectedBeach!.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BeachDetailScreen(beachId: _selectedBeach!.id),
                                ),
                              );
                            },
                            icon: const Icon(Icons.info_outline, size: 18),
                            label: const Text('View Details'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        if (_isAdmin) ...[
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _startMovingBeach(_selectedBeach!),
                            icon: const Icon(Icons.location_searching, size: 18),
                            label: const Text('Move Pin'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

        if (_showSearchAreaButton && !_isMovingBeach)
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

        if (!_isMovingBeach)
          Positioned(
            top: 8,
            left: 8,
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

  Widget _buildMetricBadge(Beach beach) {
    String? displayValue;
    if (_activeMetricKey == 'Water Index' && beach.waterIndex != null) {
      displayValue = beach.waterIndex!.toStringAsFixed(1);
    } else if (_activeMetricKey == 'Shoreline Risk' && beach.shorelineRiskProxy != null) {
      displayValue = beach.shorelineRiskProxy!.toStringAsFixed(1);
    } else if (beach.aggregatedMetrics[_activeMetricKey!] != null) {
      displayValue = beach.aggregatedMetrics[_activeMetricKey!]!.toStringAsFixed(1);
    }

    if (displayValue == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${_activeMetricKey!}: $displayValue',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

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

class _LegendBar extends StatelessWidget {
  final String label;
  const _LegendBar({required this.label});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Container(
              height: 8,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF00BCD4),
                    Color(0xFF8BC34A),
                    Color(0xFFFFC107),
                    Color(0xFFF44336),
                  ],
                ),
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('low', style: TextStyle(fontSize: 10)),
                Text('high', style: TextStyle(fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}