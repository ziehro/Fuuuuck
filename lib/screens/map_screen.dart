// lib/screens/map_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart'; // For current location
import 'package:permission_handler/permission_handler.dart'; // For location permissions
import 'package:provider/provider.dart'; // To access BeachDataService
import 'dart:async'; // For async operations

import 'package:fuuuuck/services/beach_data_service.dart';
import 'package:fuuuuck/models/beach_model.dart';
import 'package:fuuuuck/screens/add_beach_screen.dart'; // To navigate to Add Beach screen
import 'package:fuuuuck/screens/beach_detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  Stream<List<Beach>>? _beachesStream; // Stream to hold nearby beaches

  @override
  void initState() {
    super.initState();
    _initializeLocationAndBeaches();
  }

  Future<void> _initializeLocationAndBeaches() async {
    try {
      // First, get location permission
      PermissionStatus permission = await Permission.locationWhenInUse.request();
      if (!permission.isGranted) {
        _showSnackBar('Location permission is required to find nearby beaches.');
        // Set a default location if permission is denied
        setState(() {
          _currentPosition = const LatLng(49.2827, -123.1207); // Default to Vancouver
          _loadBeachesForCurrentLocation();
        });
        return;
      }

      // Then, get the current position
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _loadBeachesForCurrentLocation();
      });

    } catch (e) {
      _showSnackBar('Failed to get current location: $e');
      // Fallback to a default location
      setState(() {
        _currentPosition = const LatLng(49.2827, -123.1207);
        _loadBeachesForCurrentLocation();
      });
    }
  }

  void _loadBeachesForCurrentLocation() {
    if (_currentPosition != null) {
      final beachDataService = Provider.of<BeachDataService>(context, listen: false);
      setState(() {
        _beachesStream = beachDataService.getBeachesNearby(
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
        );
      });
    }
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
          : StreamBuilder<List<Beach>>(
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
            infoWindow: InfoWindow(
              title: beach.name,
              snippet: beach.description,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => BeachDetailScreen(beachId: beach.id)),
              ),
            ),
          )).toSet();

          return GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition!,
              zoom: 10.0,
            ),
            onMapCreated: _onMapCreated,
            markers: markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddBeachScreen,
        tooltip: 'Add New Beach',
        child: const Icon(Icons.add_location_alt),
      ),
    );
  }
}