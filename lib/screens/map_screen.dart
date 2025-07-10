// lib/screens/map_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart'; // For current location
import 'package:permission_handler/permission_handler.dart'; // For location permissions
import 'package:provider/provider.dart'; // To access BeachDataService
// For theme colors (if needed directly)

import 'package:fuuuuck/services/beach_data_service.dart';
import 'package:fuuuuck/models/beach_model.dart';
import 'package:fuuuuck/screens/add_beach_screen.dart'; // To navigate to Add Beach screen
// import 'package:fuuuuck/screens/beach_detail_screen.dart'; // Future: To navigate to beach detail

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentPosition; // To store user's current location
  bool _isLoadingLocation = true; // To show loading while getting location
  bool _cameraMovedToInitialLocation = false; // Track if camera has moved

  @override
  void initState() {
    super.initState();
    _getCurrentLocation(); // Start getting location when the screen initializes
  }

  // --- Geolocation Methods ---
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });
    try {
      // Request location permissions
      PermissionStatus permission = await Permission.locationWhenInUse.request();

      if (permission.isGranted) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _isLoadingLocation = false;
        });
        // If map controller is already available, move camera
        if (_mapController != null && !_cameraMovedToInitialLocation) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(_currentPosition!, 10.0),
          );
          _cameraMovedToInitialLocation = true;
        }
      } else {
        // Handle permission denied
        _showSnackBar('Location permission denied. Cannot show current location.');
        setState(() {
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      debugPrint('Error getting current location: $e');
      _showSnackBar('Failed to get current location: ${e.toString()}');
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  // --- Map Callbacks ---
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    // If we have current location and haven't moved camera yet, animate to it
    if (_currentPosition != null && !_cameraMovedToInitialLocation) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_currentPosition!, 10.0), // Zoom level 10
      );
      _cameraMovedToInitialLocation = true;
    }
  }

  // --- Navigation to Add Beach Screen ---
  void _navigateToAddBeachScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddBeachScreen()), // Pass initialLocation if desired later
    );
  }

  @override
  void dispose() {
    _mapController?.dispose(); // Dispose map controller to free resources
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final beachDataService = Provider.of<BeachDataService>(context);

    // Initial camera position (e.g., center of your region if no location yet)
    final CameraPosition initialCameraPosition = CameraPosition(
      target: _currentPosition ?? const LatLng(49.2827, -123.1207), // Default to Vancouver
      zoom: _currentPosition != null ? 10.0 : 7.0, // Zoom based on location availability
    );

    return Scaffold(
      body: _isLoadingLocation && _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<Beach>>(
        stream: beachDataService.getBeaches(), // Listen for all beaches
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error loading beaches: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            // While waiting for data, show map with no markers yet or loading indicator
            return _currentPosition != null // Show map if we have location, otherwise general loading
                ? GoogleMap(
              initialCameraPosition: initialCameraPosition,
              onMapCreated: _onMapCreated,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: false,
              // No markers yet, as data is still loading
            )
                : const Center(child: CircularProgressIndicator());
          }

          // Data has arrived, now build the markers
          final List<Beach> beaches = snapshot.data ?? [];
          final Set<Marker> markers = {}; // Local set of markers for this build
          for (final beach in beaches) {
            final marker = Marker(
              markerId: MarkerId(beach.id),
              position: LatLng(beach.latitude, beach.longitude),
              infoWindow: InfoWindow(
                title: beach.name,
                snippet: beach.description,
                onTap: () {
                  // TODO: Navigate to Beach Detail Screen on marker tap
                  _showSnackBar('Tapped on ${beach.name}');
                  // Example navigation (uncomment/implement BeachDetailScreen later):
                  // Navigator.push(context, MaterialPageRoute(builder: (context) => BeachDetailScreen(beachId: beach.id)));
                },
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure), // Custom color
            );
            markers.add(marker);
          }

          return GoogleMap(
            initialCameraPosition: initialCameraPosition,
            onMapCreated: _onMapCreated,
            markers: markers, // Pass the newly generated markers
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddBeachScreen,
        tooltip: 'Add New Beach',
        backgroundColor: Theme.of(context).floatingActionButtonTheme.backgroundColor,
        foregroundColor: Theme.of(context).floatingActionButtonTheme.foregroundColor,
        child: const Icon(Icons.add_location_alt),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}