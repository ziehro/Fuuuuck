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
import 'package:mybeachbook/services/notification_service.dart';
import 'package:mybeachbook/services/auth_service.dart';
import 'package:mybeachbook/models/beach_model.dart';
import 'package:mybeachbook/screens/add_beach_screen.dart';
import 'package:mybeachbook/screens/beach_detail_screen.dart';
import 'package:mybeachbook/screens/settings_screen.dart';
import 'package:mybeachbook/screens/moderation_screen.dart';
import 'package:mybeachbook/util/metric_ranges.dart';
import 'package:mybeachbook/util/constants.dart';
import 'package:mybeachbook/widgets/map_menu.dart';

class MapScreen extends StatefulWidget {
  final bool isAdmin;

  const MapScreen({super.key, this.isAdmin = false});

  @override
  State<MapScreen> createState() => MapScreenState();

  static Set<String> getMetricKeys() => _metricKeys;

  static const Set<String> _metricKeys = {
    // Composition
    'Sand','Pebbles','Rocks','Baseball Rocks','Boulders','Stone','Mud','Coal','Midden',
    // Flora
    'Kelp Beach','Seaweed Beach','Seaweed Rocks',
    // Driftwood
    'Kindling','Firewood','Logs','Trees',
    // Fauna
    'Anemones','Barnacles','Bugs','Clams','Limpets','Mussels','Oysters','Snails','Turtles',
    // Other Metrics
    'Islands','Bluff Height','Bluffs Grade','Garbage','People','Width','Length',
    'Boats on Shore','Caves','Patio Nearby?','Gold','Lookout','Private','Stink','Windy',
  };

  static const Set<String> _satelliteMetrics = {
    'Shoreline Proximity',
    'Water Quality Index',
    'Tide Prediction',
    'Weather Overlay',
    'UV Index',
    'Water Temperature',
    'Wave Height',
    'Wind Speed',
  };

  static const bool _showSatelliteMetrics = false;

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

  Beach? _beachBeingMoved;
  LatLng? _newBeachPosition;
  bool _isMovingBeach = false;
  String _selectedWaterBodyType = 'tidal';

  static final BitmapDescriptor _defaultMarker = BitmapDescriptor.defaultMarker;
  static final BitmapDescriptor _greenMarker = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
  static final BitmapDescriptor _orangeMarker = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);

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

    try {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(msg),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
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

  void _onCircleTap(String circleId) {
    final beach = _circleToBeachMap[circleId];
    if (beach != null) {
      setState(() => _selectedBeach = beach);
    }
  }

  void _onMapTap(LatLng position) {
    if (_isMovingBeach && _beachBeingMoved != null) {
      setState(() {
        _newBeachPosition = position;
      });
    } else {
      setState(() => _selectedBeach = null);
    }
  }

  void _startMovingBeach(Beach beach) {
    setState(() {
      _beachBeingMoved = beach;
      _newBeachPosition = LatLng(beach.latitude, beach.longitude);
      _isMovingBeach = true;
      _selectedBeach = null;
      _selectedWaterBodyType = beach.waterBodyType ?? 'tidal';
    });

    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(beach.latitude, beach.longitude), 16),
      );
    }
  }

  Future<void> _submitMoveBeach() async {
    if (_beachBeingMoved == null || _newBeachPosition == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: const Text('No beach or position selected'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final beachId = _beachBeingMoved!.id;
    final beachName = _beachBeingMoved!.name;
    final newPosition = _newBeachPosition!;
    final waterBodyType = _selectedWaterBodyType;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Updating beach location...'),
              ],
            ),
          ),
        ),
      ),
    );

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
        'waterBodyType': waterBodyType,
      });

      if (mounted) Navigator.of(context).pop();

      setState(() {
        _beachBeingMoved = null;
        _newBeachPosition = null;
        _isMovingBeach = false;
      });

      await _loadBeachesForVisibleRegion();

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Success'),
            content: Text('$beachName location updated successfully!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to update location: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _cancelMoveBeach() {
    setState(() {
      _beachBeingMoved = null;
      _newBeachPosition = null;
      _isMovingBeach = false;
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: const Text('Move cancelled'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _centerOnMyLocation() async {
    if (_currentPosition != null && _mapController != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_currentPosition!, 15),
      );
    }
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

  void _showLayerMenu(BuildContext context) {
    final keys = MapScreen.getMetricKeys().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final satelliteKeys = MapScreen._satelliteMetrics.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

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
                'Heatmap Layer',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(),
            ListTile(
              title: const Text('None'),
              trailing: _activeMetricKey == null
                  ? const Icon(Icons.check, color: seafoamGreen)
                  : null,
              onTap: () {
                setActiveMetric(null);
                Navigator.pop(context);
              },
            ),
            const Divider(),
            Expanded(
              child: ListView(
                shrinkWrap: true,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'User Metrics',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: seafoamGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ...keys.map((key) => ListTile(
                    title: Text(key),
                    trailing: _activeMetricKey == key
                        ? const Icon(Icons.check, color: seafoamGreen)
                        : null,
                    onTap: () {
                      setActiveMetric(key);
                      Navigator.pop(context);
                    },
                  )),

                  if (MapScreen._showSatelliteMetrics) ...[
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.satellite_alt, size: 16, color: seafoamGreen),
                          const SizedBox(width: 8),
                          Text(
                            'Satellite Metrics',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: seafoamGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...satelliteKeys.map((key) => ListTile(
                      title: Text(key),
                      trailing: _activeMetricKey == key
                          ? const Icon(Icons.check, color: seafoamGreen)
                          : null,
                      onTap: () {
                        setActiveMetric(key);
                        Navigator.pop(context);
                      },
                    )),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMenuDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.settings, color: seafoamGreen),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showSignOutConfirmation();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSignOutConfirmation() async {
    final bool? shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );

    if (shouldSignOut == true) {
      final authService = Provider.of<AuthService>(context, listen: false);

      if (widget.isAdmin) {
        final notificationService = Provider.of<NotificationService>(context, listen: false);
        notificationService.stopListening(notifyChange: false);
      }

      await authService.signOut();
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

  @override
  Widget build(BuildContext context) {
    final settingsService = Provider.of<SettingsService>(context);
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

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
            final markers = <Marker>{};

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
                  infoWindow: const InfoWindow(title: 'New Location'),
                ),
              );
            }

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
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapType: _getMapType(settingsService.mapStyle),
              padding: EdgeInsets.only(
                top: topPadding,
                bottom: bottomPadding,
              ),
            );
          },
        ),

        if (_isMovingBeach && _beachBeingMoved != null)
          Positioned(
            top: topPadding + 80,
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

        if (_isMovingBeach && _beachBeingMoved != null)
          Positioned(
            bottom: 20,
            left: 80,
            right: 20,
            child: Card(
              elevation: 5,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Water Body Type',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Tidal', style: TextStyle(fontSize: 12)),
                            value: 'tidal',
                            groupValue: _selectedWaterBodyType,
                            onChanged: (value) {
                              setState(() => _selectedWaterBodyType = value!);
                            },
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Lake', style: TextStyle(fontSize: 12)),
                            value: 'lake',
                            groupValue: _selectedWaterBodyType,
                            onChanged: (value) {
                              setState(() => _selectedWaterBodyType = value!);
                            },
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('River', style: TextStyle(fontSize: 12)),
                            value: 'river',
                            groupValue: _selectedWaterBodyType,
                            onChanged: (value) {
                              setState(() => _selectedWaterBodyType = value!);
                            },
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Collapsible Menu
        if (!_isMovingBeach)
          MapMenu(
            onAddBeach: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddBeachScreen()),
              );
            },
            onCenterLocation: _centerOnMyLocation,
            onToggleMarkers: toggleMarkers,
            onHeatmapLayer: () => _showLayerMenu(context),
            onClearHeatmap: clearHeatmap,
            onMapStyle: () => _showQuickMapStylePicker(settingsService),
            onSettings: () => _showMenuDialog(context),
            onModeration: widget.isAdmin
                ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ModerationScreen(),
                ),
              );
            }
                : null,
            showMarkers: _showMarkers,
            hasActiveHeatmap: _activeMetricKey != null,
          ),

        if (_activeMetricKey != null)
          Positioned(
            left: 88,
            right: 88,
            bottom: bottomPadding + 100,
            child: _LegendBar(label: _activeMetricKey!),
          ),

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
                        if (widget.isAdmin) ...[
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
            top: topPadding + 16,
            left: 80,
            right: 80,
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