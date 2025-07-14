// lib/screens/add_beach_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io'; // For File
import 'package:cloud_firestore/cloud_firestore.dart'; // For Timestamp, GeoPoint
// For debugPrint

// Corrected Imports for Location, Geocoding, Geohash, and Google Maps LatLng
import 'package:geolocator/geolocator.dart'; // For getting current GPS location
import 'package:geocoding/geocoding.dart'; // For Placemark and placemarkFromCoordinates
import 'package:dart_geohash/dart_geohash.dart'; // Corrected: For Geohash calculation (Null-Safe)
import 'package:google_maps_flutter/google_maps_flutter.dart'; // Corrected: For LatLng

// Your app's services and models
import 'package:fuuuuck/services/beach_data_service.dart';
import 'package:fuuuuck/services/auth_service.dart'; // To get current user ID
import 'package:fuuuuck/models/beach_model.dart';
import 'package:fuuuuck/models/contribution_model.dart';
import 'package:fuuuuck/models/confirmed_identification.dart'; // Correct source for ConfirmedIdentification
// For theme colors
import 'package:fuuuuck/screens/scanner_screen.dart'; // Only for navigating to the ScannerScreen widget

// Enum to represent the various input types for the dynamic form
enum InputFieldType {
  text,
  number,
  multiChoice,
  singleChoice,
  slider,
  imagePicker,
  scannerConfirmation,
}

// Data structure to represent a form field for dynamic rendering
class FormFieldData {
  final String label;
  final InputFieldType type;
  final List<String>? options; // For single/multi-choice
  final int? minValue; // For slider
  final int? maxValue; // For slider
  dynamic initialValue; // Stores the current value of the field

  FormFieldData({
    required this.label,
    required this.type,
    this.options,
    this.minValue,
    this.maxValue,
    this.initialValue,
  });
}


class AddBeachScreen extends StatefulWidget {
  // Option to pass a pre-determined location, e.g., from a map tap
  final LatLng? initialLocation;
  // New: Optional ID for the beach if we are adding a contribution
  final String? beachId;

  const AddBeachScreen({super.key, this.initialLocation, this.beachId});

  @override
  State<AddBeachScreen> createState() => _AddBeachScreenState();
}

class _AddBeachScreenState extends State<AddBeachScreen> {
  final _formKey = GlobalKey<FormState>(); // Key for form validation
  final _pageController = PageController(); // Add PageController


  // Controllers for basic text inputs
  final TextEditingController _beachNameController = TextEditingController();
  final TextEditingController _shortDescriptionController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _provinceController = TextEditingController();
  final TextEditingController _municipalityController = TextEditingController();

  List<File> _mainBeachImageFiles = []; // For multiple images of the beach // For the primary image of the beach
  List<ConfirmedIdentification> _scannerConfirmedIdentifications = []; // AI scanner results


  // Map to hold all dynamic form data (like your old app's 'data' map)
  final Map<String, dynamic> _formData = {};

  // For location (will automatically get from GPS or use initialLocation)
  LatLng? _currentLocation;
  bool _gettingLocation = false;


  // --- All your questions from the Java app, structured for Flutter ---
  final List<FormFieldData> _formFields = [
    // Core beach details handled by controllers above, no need in this list
    FormFieldData(label: 'Boats on Shore', type: InputFieldType.slider, minValue: 0, maxValue: 1),
    FormFieldData(label: 'Caves', type: InputFieldType.slider, minValue: 0, maxValue: 1),
    FormFieldData(label: 'Patio Nearby?', type: InputFieldType.slider, minValue: 0, maxValue: 1),
    FormFieldData(label: 'Gold', type: InputFieldType.slider, minValue: 0, maxValue: 1),
    FormFieldData(label: 'Lookout', type: InputFieldType.slider, minValue: 0, maxValue: 1),
    FormFieldData(label: 'Private', type: InputFieldType.slider, minValue: 0, maxValue: 1),
    FormFieldData(label: 'Stink', type: InputFieldType.slider, minValue: 0, maxValue: 1),
    FormFieldData(label: 'Windy', type: InputFieldType.slider, minValue: 0, maxValue: 2),

    FormFieldData(label: 'Trees', type: InputFieldType.slider, minValue: 1, maxValue: 5),
    FormFieldData(label: 'Logs', type: InputFieldType.slider, minValue: 1, maxValue: 5),
    FormFieldData(label: 'Firewood', type: InputFieldType.slider, minValue: 1, maxValue: 5),
    FormFieldData(label: 'Kindling', type: InputFieldType.slider, minValue: 1, maxValue: 5),

    FormFieldData(label: 'Baseball Rocks', type: InputFieldType.slider, minValue: 1, maxValue: 5),
    FormFieldData(label: 'Boulders', type: InputFieldType.slider, minValue: 1, maxValue: 5),
    FormFieldData(label: 'Sand', type: InputFieldType.slider, minValue: 1, maxValue: 5),
    FormFieldData(label: 'Pebbles', type: InputFieldType.slider, minValue: 1, maxValue: 5),
    FormFieldData(label: 'Rocks', type: InputFieldType.slider, minValue: 1, maxValue: 5),
    FormFieldData(label: 'Islands', type: InputFieldType.slider, minValue: 1, maxValue: 5),
    FormFieldData(label: 'Mud', type: InputFieldType.slider, minValue: 1, maxValue: 5),
    FormFieldData(label: 'Midden', type: InputFieldType.slider, minValue: 1, maxValue: 5),
    FormFieldData(label: 'Stone', type: InputFieldType.slider, minValue: 1, maxValue: 5),
    FormFieldData(label: 'Coal', type: InputFieldType.slider, minValue: 1, maxValue: 5),

    FormFieldData(label: 'Anemones', type: InputFieldType.slider, minValue: 1, maxValue: 7),
    FormFieldData(label: 'Barnacles', type: InputFieldType.slider, minValue: 1, maxValue: 7),
    FormFieldData(label: 'Seaweed Beach', type: InputFieldType.slider, minValue: 1, maxValue: 7),
    FormFieldData(label: 'Seaweed Rocks', type: InputFieldType.slider, minValue: 1, maxValue: 7),
    FormFieldData(label: 'Kelp Beach', type: InputFieldType.slider, minValue: 1, maxValue: 7),
    FormFieldData(label: 'Bugs', type: InputFieldType.slider, minValue: 1, maxValue: 7),
    FormFieldData(label: 'Snails', type: InputFieldType.slider, minValue: 1, maxValue: 7),
    FormFieldData(label: 'Oysters', type: InputFieldType.slider, minValue: 1, maxValue: 7),
    FormFieldData(label: 'Clams', type: InputFieldType.slider, minValue: 1, maxValue: 7),
    FormFieldData(label: 'Limpets', type: InputFieldType.slider, minValue: 1, maxValue: 7),
    FormFieldData(label: 'Turtles', type: InputFieldType.slider, minValue: 1, maxValue: 7),
    FormFieldData(label: 'Mussels', type: InputFieldType.slider, minValue: 1, maxValue: 7),

    FormFieldData(label: 'Bluffs Grade', type: InputFieldType.slider, minValue: 1, maxValue: 9),
    FormFieldData(label: 'Garbage', type: InputFieldType.slider, minValue: 1, maxValue: 9),
    FormFieldData(label: 'People', type: InputFieldType.slider, minValue: 0, maxValue: 5),


    // Single Choice questions
    FormFieldData(label: 'Best Tide', type: InputFieldType.singleChoice, options: ['Low', 'Mid', 'High', "Don't Matter"]),
    FormFieldData(label: 'Parking', type: InputFieldType.singleChoice, options: ['Parked on the beach', '1 minute', '5 minutes', '10 minutes', '30 minutes', '1 hour plus', 'Boat access only']),
    FormFieldData(label: 'Rock Type', type: InputFieldType.singleChoice, options: ['Igneous', 'Sedimentary', 'Metamorphic']),
    FormFieldData(label: 'Shape', type: InputFieldType.singleChoice, options: ['Concave', 'Convex', 'Isthmus', 'Horseshoe', 'Straight']),

    // Numerical Input questions
    FormFieldData(label: 'Width', type: InputFieldType.number),
    FormFieldData(label: 'Length', type: InputFieldType.number),
    FormFieldData(label: 'Bluff Height', type: InputFieldType.number),

    // Text Input questions (comma-separated, result in List<String>)
    FormFieldData(label: 'Birds', type: InputFieldType.text),
    FormFieldData(label: 'Treasure', type: InputFieldType.text),
    FormFieldData(label: 'New Items', type: InputFieldType.text),
    FormFieldData(label: 'Tree types', type: InputFieldType.text),

    // Multi-Choice questions
    FormFieldData(label: 'Bluff Comp', type: InputFieldType.multiChoice, options: ['Sand', 'Rock', 'Thick Brush', 'Grass']),
    FormFieldData(label: 'Man Made', type: InputFieldType.multiChoice, options: ['Seawall', 'Sewar Line', 'Walkway', 'Garbage Cans', 'Tents', 'Picnic Tables', 'Benches', 'Houses', 'Playground', 'Bathrooms', 'Campground', 'Protective Structure To Escape the Weather', 'Boat Dock', 'Boat Launch']),
    FormFieldData(label: 'Shade', type: InputFieldType.multiChoice, options: ['in the morning', 'in the evening', 'in the afternoon', 'none']),
    FormFieldData(label: 'Which Shells', type: InputFieldType.multiChoice, options: ['Butter Clam', 'Mussel', 'Crab', 'Oyster', 'Whelks', 'Turban', 'Sand dollars', 'Cockles', 'Starfish', 'Limpets']),
  ];
  // --- End of form questions ---

  @override
  void initState() {
    super.initState();
    // Default values for new beach creation
    _countryController.text = 'Canada'; // Default to Canada
    _provinceController.text = 'British Columbia'; // Default to BC

    // If we're adding a contribution, disable text controllers and use the beach's location
    if (widget.beachId != null) {
      // You may need to load the beach's details here to populate the text controllers
      // For now, we assume these fields are read-only for contributions
      _beachNameController.text = 'Existing Beach'; // Placeholder
      _shortDescriptionController.text = 'Adding a new contribution.'; // Placeholder
      // Also, we don't fetch location if it's already provided
      _currentLocation = widget.initialLocation;
    } else if (widget.initialLocation != null) {
      // If we are creating a new beach from a map tap
      _currentLocation = widget.initialLocation;
      _reverseGeocodeLocation(_currentLocation!.latitude, _currentLocation!.longitude);
    } else {
      // Standard new beach creation, get current GPS location
      _getCurrentLocationAndGeocode();
    }
  }

  // --- Geolocation and Reverse Geocoding ---
  Future<void> _getCurrentLocationAndGeocode() async {
    setState(() {
      _gettingLocation = true;
    });
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        setState(() {
          // This is a direct assignment to LatLng from Geolocator's Position
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
        await _reverseGeocodeLocation(_currentLocation!.latitude, _currentLocation!.longitude);
      } else {
        _showSnackBar('Location permission denied. Cannot auto-fill location details.');
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      _showSnackBar('Failed to get current location: ${e.toString()}');
    } finally {
      setState(() {
        _gettingLocation = false;
      });
    }
  }

  Future<void> _reverseGeocodeLocation(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        setState(() {
          _municipalityController.text = place.locality ?? '';
          _provinceController.text = place.administrativeArea ?? '';
          _countryController.text = place.country ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error reverse geocoding: $e');
      _showSnackBar('Failed to get address details for location.');
    }
  }


  @override
  void dispose() {
    _beachNameController.dispose();
    _shortDescriptionController.dispose();
    _countryController.dispose();
    _provinceController.dispose();
    _municipalityController.dispose();
    _pageController.dispose(); // Dispose the PageController
    super.dispose();
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();

    if (pickedFiles.isNotEmpty) {
      setState(() {
        _mainBeachImageFiles = pickedFiles.map((xfile) => File(xfile.path)).toList();
      });
    }
  }

  // Navigate to scanner and get results back
  Future<void> _scanForIdentifications() async {
    final List<ConfirmedIdentification>? confirmed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScannerScreen()),
    );

    if (confirmed != null && confirmed.isNotEmpty) {
      setState(() {
        _scannerConfirmedIdentifications = confirmed;
      });
      _showSnackBar('Received ${confirmed.length} confirmed identifications!');
    } else if (confirmed != null && confirmed.isEmpty) {
      _showSnackBar('No identifications confirmed.');
    }
  }


  Future<void> _saveNewBeach() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please fill in all required fields.');
      return;
    }

    _formKey.currentState!.save(); // Save all form fields

    final beachDataService = Provider.of<BeachDataService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid;

    if (userId == null) {
      _showSnackBar('You must be logged in to add a beach.');
      return;
    }
    if (_mainBeachImageFiles.isEmpty) {
      _showSnackBar('Please select at least one beach photo.');
      return;
    }
    if (_currentLocation == null) {
      _showSnackBar('Getting location. Please try again in a moment or grant permission.');
      await _getCurrentLocationAndGeocode(); // Try getting location again
      return;
    }

    // Check for latitude/longitude swap from the raw data
    final double lat = _currentLocation!.latitude;
    final double lon = _currentLocation!.longitude;

    if (lat < -90 || lat > 90) {
      _showSnackBar('Location data is invalid. Latitude is out of range. Please try again.');
      debugPrint('Location Data Error: Final lat=$lat, lon=$lon');
      return;
    }

    _showSnackBar('Saving beach data');

    try {
      // 1. Upload main beach image
      List<String> mainImageUrls = [];
      for (var imageFile in _mainBeachImageFiles) {
        final String? imageUrl = await beachDataService.uploadImage(imageFile);
        if (imageUrl != null) {
          mainImageUrls.add(imageUrl);
        }
      }
      if (mainImageUrls.isEmpty) {
        _showSnackBar('Failed to upload any beach images.');
        return;
      }


      // Convert dynamic text inputs (like "Birds") into List<String>
      Map<String, dynamic> processedUserAnswers = Map.from(_formData);
      for (var field in _formFields) {
        if (field.type == InputFieldType.text && processedUserAnswers.containsKey(field.label)) {
          String rawValue = processedUserAnswers[field.label] as String? ?? '';
          processedUserAnswers[field.label] = rawValue.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        }
      }

      // 2. Create the initial Contribution object
      final contribution = Contribution(
        userId: userId,
        timestamp: Timestamp.now(),
        latitude: lat,
        longitude: lon,
        contributedImageUrls: mainImageUrls,
        userAnswers: processedUserAnswers,
        aiConfirmedFloraFauna: _scannerConfirmedIdentifications,
        aiConfirmedRockTypes: [], // Will be populated when rock AI is ready
      );

      // New Logic: Check if we are adding to an existing beach or creating a new one
      if (widget.beachId != null) {
        // We are adding a contribution to an existing beach
        await beachDataService.addContribution(
          beachId: widget.beachId!,
          contribution: contribution,
        );
        _showSnackBar('Contribution added successfully!');
      } else {
        // We are creating a brand new beach
        final geoHasher = GeoHasher();
        final initialBeach = Beach(
          id: '', // ID will be generated by Firestore
          name: _beachNameController.text,
          latitude: lat,
          longitude: lon,
          geohash: geoHasher.encode(lon, lat, precision: 9),
          country: _countryController.text,
          province: _provinceController.text,
          municipality: _municipalityController.text,
          description: _shortDescriptionController.text,
          imageUrls: mainImageUrls,
          timestamp: Timestamp.now(),
          lastAggregated: Timestamp.now(),
          totalContributions: 1,
          aggregatedMetrics: _getAggregatedMetricsFromContribution(contribution),
          aggregatedSingleChoices: _getAggregatedSingleChoicesFromContribution(contribution),
          aggregatedMultiChoices: _getAggregatedMultiChoicesFromContribution(contribution),
          aggregatedTextItems: _getAggregatedTextItemsFromContribution(contribution),
          identifiedFloraFaunaCounts: _getAggregatedFloraFaunaCountsFromContribution(contribution),
          identifiedRockTypesComposition: {},
          identifiedBeachComposition: {},
          discoveryQuestions: [],
          educationalInfo: 'Initial information for this beach.',
          contributedDescriptions: [_shortDescriptionController.text],
        );

        final String? beachId = await beachDataService.addBeach(
          initialBeach: initialBeach,
          initialContribution: contribution,
        );

        if (beachId != null) {
          _showSnackBar('Beach saved successfully!');
        } else {
          _showSnackBar('Failed to save beach data.');
        }
      }

      Navigator.pop(context); // Go back after saving

    } catch (e) {
      print('Error during save new beach: $e');
      _showSnackBar('An error occurred: ${e.toString()}');
    }
  }

  // --- Helper methods to get aggregated data for the *first* contribution ---
  Map<String, double> _getAggregatedMetricsFromContribution(Contribution contribution) {
    Map<String, double> metrics = {};
    for (var field in _formFields) {
      if ((field.type == InputFieldType.slider || field.type == InputFieldType.number) &&
          contribution.userAnswers.containsKey(field.label)) {
        final value = contribution.userAnswers[field.label];
        if (value != null && value is num) {
          metrics[field.label] = value.toDouble();
        }
      }
    }
    return metrics;
  }

  Map<String, String> _getAggregatedSingleChoicesFromContribution(Contribution contribution) {
    Map<String, String> choices = {};
    for (var field in _formFields) {
      if (field.type == InputFieldType.singleChoice && contribution.userAnswers.containsKey(field.label)) {
        // Corrected line: Only add the value if it's not null.
        final value = contribution.userAnswers[field.label];
        if (value != null && value is String) {
          choices[field.label] = value;
        }
      }
    }
    return choices;
  }

  Map<String, List<String>> _getAggregatedMultiChoicesFromContribution(Contribution contribution) {
    Map<String, List<String>> choices = {};
    for (var field in _formFields) {
      if (field.type == InputFieldType.multiChoice && contribution.userAnswers.containsKey(field.label)) {
        final value = contribution.userAnswers[field.label];
        if (value != null) {
          choices[field.label] = List<String>.from(value);
        }
      }
    }
    return choices;
  }

  Map<String, List<String>> _getAggregatedTextItemsFromContribution(Contribution contribution) {
    Map<String, List<String>> textItems = {};
    for (var field in _formFields) {
      bool isBasicDetail = ['Beach Name', 'Short Description', 'Country', 'Province', 'Municipality'].contains(field.label);
      if (field.type == InputFieldType.text && contribution.userAnswers.containsKey(field.label) && !isBasicDetail) {
        final value = contribution.userAnswers[field.label];
        if (value != null) {
          textItems[field.label] = List<String>.from(value);
        }
      }
    }
    return textItems;
  }

  Map<String, int> _getAggregatedFloraFaunaCountsFromContribution(Contribution contribution) {
    Map<String, int> counts = {};
    for (var confirmed in contribution.aiConfirmedFloraFauna) {
      counts[confirmed.commonName] = (counts[confirmed.commonName] ?? 0) + 1;
    }
    return counts;
  }


  @override
  Widget build(BuildContext context) {
    final bool isNewBeach = widget.beachId == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isNewBeach ? 'Add New Beach' : 'Add Contribution'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
      ),
      body: _gettingLocation
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                children: _buildPages(isNewBeach),
              ),
            ),
            // The "Save" button remains at the bottom
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: _saveNewBeach,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(isNewBeach ? 'Save New Beach' : 'Add Contribution'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPages(bool isNewBeach) {
    List<Widget> pages = [];
    int fieldIndex = 0;

    // Page 1: Core Details, Image Picker, and Scanner
    pages.add(
      ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          TextFormField(
            controller: _beachNameController,
            decoration: InputDecoration(labelText: 'Beach Name', hintText: 'Enter Here'),
            validator: isNewBeach ? (value) => value!.isEmpty ? 'Please enter a beach name' : null : null,
            onSaved: (value) => _formData['Beach Name'] = value,
            readOnly: !isNewBeach, // Make read-only for contributions
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _shortDescriptionController,
            decoration: InputDecoration(labelText: 'Short Description', hintText: 'Enter Here'),
            maxLines: 3,
            validator: isNewBeach ? (value) => value!.isEmpty ? 'Please enter a description' : null : null,
            onSaved: (value) => _formData['Short Description'] = value,
            readOnly: !isNewBeach,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _countryController,
            decoration: InputDecoration(labelText: 'Country', hintText: 'Enter Here'),
            validator: isNewBeach ? (value) => value!.isEmpty ? 'Please enter country' : null : null,
            onSaved: (value) => _formData['Country'] = value,
            readOnly: !isNewBeach,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _provinceController,
            decoration: InputDecoration(labelText: 'Province', hintText: 'Enter Here'),
            validator: isNewBeach ? (value) => value!.isEmpty ? 'Please enter province' : null : null,
            onSaved: (value) => _formData['Province'] = value,
            readOnly: !isNewBeach,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _municipalityController,
            decoration: InputDecoration(labelText: 'Municipality', hintText: 'Enter Here'),
            validator: isNewBeach ? (value) => value!.isEmpty ? 'Please enter municipality' : null : null,
            onSaved: (value) => _formData['Municipality'] = value,
            readOnly: !isNewBeach,
          ),
          const SizedBox(height: 16),
          Text('Location: ${_currentLocation?.latitude.toStringAsFixed(4)}, ${_currentLocation?.longitude.toStringAsFixed(4)}',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),

          ListTile(
            title: const Text('Main Beach Photo'),
            trailing: _mainBeachImageFiles.isEmpty
                ? const Icon(Icons.add_a_photo)
                : Image.file(_mainBeachImageFiles.first, width: 50, height: 50, fit: BoxFit.cover),
            onTap: _pickImage,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _scanForIdentifications,
            icon: const Icon(Icons.camera_alt),
            label: Text('Scan Flora/Fauna (${_scannerConfirmedIdentifications.length} confirmed)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
            ),
          ),
          const SizedBox(height: 16),
          if (_scannerConfirmedIdentifications.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Confirmed Scans:', style: Theme.of(context).textTheme.titleSmall),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: _scannerConfirmedIdentifications.map((id) {
                    final confirmedId = id;
                    return Chip(
                      label: Text(confirmedId.commonName),
                      onDeleted: () {
                        setState(() {
                          _scannerConfirmedIdentifications.remove(id);
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
        ],
      ),
    );

    // Grouping the rest of the fields by type as pages
    List<FormFieldData> currentPageFields = [];
    InputFieldType? currentType;

    while (fieldIndex < _formFields.length) {
      final field = _formFields[fieldIndex];
      if (currentType == null) {
        currentType = field.type;
        currentPageFields.add(field);
      } else if (field.type == currentType) {
        currentPageFields.add(field);
      } else {
        // Start a new page for the new field type
        pages.add(_buildFormPage(currentPageFields));
        currentPageFields = [field];
        currentType = field.type;
      }
      fieldIndex++;
    }
    // Add the last page
    if (currentPageFields.isNotEmpty) {
      pages.add(_buildFormPage(currentPageFields));
    }

    return pages;
  }

  Widget _buildFormPage(List<FormFieldData> fields) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: fields.map((field) {
        switch (field.type) {
          case InputFieldType.text:
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: TextFormField(
                decoration: InputDecoration(labelText: field.label, hintText: 'Enter Here'),
                initialValue: field.initialValue,
                onSaved: (value) => _formData[field.label] = value,
              ),
            );
          case InputFieldType.number:
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: TextFormField(
                decoration: InputDecoration(labelText: field.label, hintText: 'Enter Here'),
                keyboardType: TextInputType.number,
                initialValue: field.initialValue?.toString(),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter a number';
                  if (int.tryParse(value) == null) return 'Please enter a valid number';
                  return null;
                },
                onSaved: (value) => _formData[field.label] = int.tryParse(value ?? '0'),
              ),
            );
          case InputFieldType.slider:
            if (!_formData.containsKey(field.label)) {
              _formData[field.label] = field.minValue ?? 0;
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${field.label}: ${(_formData[field.label] ?? field.minValue ?? 0).round()}', style: Theme.of(context).textTheme.bodyLarge),
                  Slider(
                    value: (_formData[field.label] ?? field.minValue ?? 0).toDouble(),
                    min: (field.minValue ?? 0).toDouble(),
                    max: (field.maxValue ?? 5).toDouble(),
                    divisions: (field.maxValue ?? 5) - (field.minValue ?? 0),
                    label: (_formData[field.label] ?? field.minValue ?? 0).round().toString(),
                    onChanged: (double value) {
                      setState(() {
                        _formData[field.label] = value.round();
                      });
                    },
                    onChangeEnd: (double value) {
                      _formData[field.label] = value.round();
                    },
                  ),
                ],
              ),
            );
          case InputFieldType.singleChoice:
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: _buildSingleChoiceDropdown(field.label, field.options!),
            );
          case InputFieldType.multiChoice:
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: _buildMultiChoiceChips(field.label, field.options!),
            );
          case InputFieldType.imagePicker:
          case InputFieldType.scannerConfirmation:
            return const SizedBox.shrink();
        }
      }).toList(),
    );
  }

  // --- Helper for Single Choice Dropdown ---
  Widget _buildSingleChoiceDropdown(String label, List<String> options) {
    // OLD CODE: This line forced a default value if one wasn't present.
    // if (!_formData.containsKey(label) || !_formData[label].toString().isNotEmpty) {
    //   _formData[label] = options.first; // Default to the first option
    // }

    // NEW CODE: This ensures a null value is possible initially
    if (!_formData.containsKey(label)) {
      _formData[label] = null;
    }

    return DropdownButtonFormField<String>(
      decoration: InputDecoration(labelText: label),
      value: _formData[label] as String?,
      items: options.map((String option) {
        return DropdownMenuItem<String>(
          value: option,
          child: Text(option),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _formData[label] = newValue;
        });
      },
      onSaved: (newValue) => _formData[label] = newValue,
    );
  }

  // --- Helper for Multi-Choice Chips ---
  Widget _buildMultiChoiceChips(String label, List<String> options) {
    if (!_formData.containsKey(label)) {
      _formData[label] = <String>[]; // Initialize as empty list if not present
    }
    List<String> selectedOptions = List<String>.from(_formData[label] ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: options.map((option) {
            final bool isSelected = selectedOptions.contains(option);
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (bool selected) {
                setState(() {
                  if (selected) {
                    selectedOptions.add(option);
                  } else {
                    selectedOptions.remove(option);
                  }
                  _formData[label] = selectedOptions; // Update formData
                });
              },
              selectedColor: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
              checkmarkColor: Theme.of(context).colorScheme.secondary,
            );
          }).toList(),
        ),
      ],
    );
  }
}