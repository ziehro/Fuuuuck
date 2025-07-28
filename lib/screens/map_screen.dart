// lib/screens/map_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import 'package:fuuuuck/services/beach_data_service.dart'; // ** FIX: Added this import **
import 'package:fuuuuck/models/beach_model.dart';
import 'package:fuuuuck/screens/add_beach_screen.dart';
import 'package:fuuuuck/screens/beach_detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  Stream<List<Beach>>? _beachesStream;
  Beach? _selectedBeach;

  bool _showSearchAreaButton = false;
  LatLng? _lastMapCenter;

  @override
  void initState() {
    super.initState();
    _initializeLocationAndBeaches();
  }

  Future<void> _initializeLocationAndBeaches() async {
    try {
      PermissionStatus permission = await Permission.locationWhenInUse.request();
      if (!permission.isGranted) {
        _showSnackBar('Location permission is required to find nearby beaches.');
        setState(() {
          _currentPosition = const LatLng(49.2827, -123.1207);
          _lastMapCenter = _currentPosition;
          _loadBeachesForLocation(_currentPosition!);
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _lastMapCenter = _currentPosition;
        _loadBeachesForLocation(_currentPosition!);
      });

    } catch (e) {
      _showSnackBar('Failed to get current location: $e');
      setState(() {
        _currentPosition = const LatLng(49.2827, -123.1207);
        _lastMapCenter = _currentPosition;
        _loadBeachesForLocation(_currentPosition!);
      });
    }
  }

  void _loadBeachesForLocation(LatLng location) {
    final beachDataService = Provider.of<BeachDataService>(context, listen: false);
    setState(() {
      _beachesStream = beachDataService.getBeachesNearby(
        latitude: location.latitude,
        longitude: location.longitude,
      );
      _showSearchAreaButton = false;
      _lastMapCenter = location;
    });
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_currentPosition != null) {
      controller.animateCamera(CameraUpdate.newLatLngZoom(_currentPosition!, 10.0));
    }
  }

  void _onCameraMove(CameraPosition position) {
    if (_lastMapCenter != null) {
      final distance = Geolocator.distanceBetween(
        _lastMapCenter!.latitude,
        _lastMapCenter!.longitude,
        position.target.latitude,
        position.target.longitude,
      );
      if (distance > 2000) {
        setState(() {
          _showSearchAreaButton = true;
        });
      }
    }
  }

  void _navigateToAddBeachScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddBeachScreen()),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              final markers = beaches.map((beach) => Marker(
                markerId: MarkerId(beach.id),
                position: LatLng(beach.latitude, beach.longitude),
                onTap: () {
                  setState(() {
                    _selectedBeach = beach;
                  });
                },
              )).toSet();

              return GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _currentPosition!,
                  zoom: 10.0,
                ),
                onMapCreated: _onMapCreated,
                onCameraMove: _onCameraMove,
                onTap: (_) {
                  setState(() {
                    _selectedBeach = null;
                  });
                },
                markers: markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: false,
              );
            },
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
                    MaterialPageRoute(
                      builder: (context) => BeachDetailScreen(beachId: _selectedBeach!.id),
                    ),
                  );
                },
                child: Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _selectedBeach!.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedBeach!.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          if (_showSearchAreaButton)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text('Search this area'),
                  onPressed: () async {
                    if (_mapController != null) {
                      LatLng newCenter = await _mapController!.getLatLng(
                        ScreenCoordinate(
                          x: MediaQuery.of(context).size.width.floor() ~/ 2,
                          y: MediaQuery.of(context).size.height.floor() ~/ 2,
                        ),
                      );
                      _loadBeachesForLocation(newCenter);
                    }
                  },
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