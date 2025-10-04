// lib/screens/add_beach_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mybeachbook/services/gemini_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:dart_geohash/dart_geohash.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart';

import 'package:mybeachbook/services/beach_data_service.dart';
import 'package:mybeachbook/services/auth_service.dart';
import 'package:mybeachbook/models/beach_model.dart';
import 'package:mybeachbook/models/contribution_model.dart';
import 'package:mybeachbook/models/confirmed_identification.dart';
import 'package:mybeachbook/screens/scanner_screen.dart';
import 'package:mybeachbook/util/beach_form_fields.dart';
import 'package:mybeachbook/models/form_data_model.dart';
import 'package:mybeachbook/widgets/add_beach/dynamic_form_page.dart';

class AddBeachScreen extends StatefulWidget {
  final LatLng? initialLocation;
  final String? beachId;

  const AddBeachScreen({super.key, this.initialLocation, this.beachId});

  @override
  State<AddBeachScreen> createState() => _AddBeachScreenState();
}
class _SaveDialogResult {
  final bool confirmed;
  final bool includeAiImage;
  const _SaveDialogResult(this.confirmed, this.includeAiImage);
}

class _AddBeachScreenState extends State<AddBeachScreen>
    with AutomaticKeepAliveClientMixin<AddBeachScreen> {
  @override
  bool get wantKeepAlive => true;

  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  final FocusNode _descriptionFocusNode = FocusNode();
  final FocusNode _beachNameFocusNode = FocusNode();

  final TextEditingController _beachNameController = TextEditingController();
  final TextEditingController _shortDescriptionController =
  TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _provinceController = TextEditingController();
  final TextEditingController _municipalityController = TextEditingController();

  // Add specific controllers for the numeric fields that are losing values
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _lengthController = TextEditingController();
  final TextEditingController _bluffHeightController = TextEditingController();

  List<String> _localImagePaths = [];
  List<ConfirmedIdentification> _scannerConfirmedIdentifications = [];

  final Map<String, dynamic> _formData = {};
  LatLng? _currentLocation;
  bool _gettingLocation = false;
  bool _isSaving = false;
  int _currentPageIndex = 0;
  String _appBarTitle = "Add New Beach";
  final GeminiService _geminiService = GeminiService();

  // Grouped form fields for each page
  late final List<FormFieldData> _floraFields;
  late final List<FormFieldData> _faunaFields;
  late final List<FormFieldData> _woodFields;
  late final List<FormFieldData> _compositionFields;
  late final List<FormFieldData> _otherFields;

  @override
  void initState() {
    super.initState();
    _groupFormFields();
    _initializeScreen();
    _setupNumberFieldListeners();
  }

  void _setupNumberFieldListeners() {
    // Set up listeners to sync the controllers with form data
    _widthController.addListener(() {
      final value = _widthController.text.isEmpty ? null : double.tryParse(_widthController.text);
      if (value != null) {
        _formData['Width'] = value;
      } else {
        _formData.remove('Width');
      }
    });

    _lengthController.addListener(() {
      final value = _lengthController.text.isEmpty ? null : double.tryParse(_lengthController.text);
      if (value != null) {
        _formData['Length'] = value;
      } else {
        _formData.remove('Length');
      }
    });

    _bluffHeightController.addListener(() {
      final value = _bluffHeightController.text.isEmpty ? null : double.tryParse(_bluffHeightController.text);
      if (value != null) {
        _formData['Bluff Height'] = value;
      } else {
        _formData.remove('Bluff Height');
      }
    });
  }

  void _groupFormFields() {
    _floraFields = beachFormFields
        .where((f) =>
        ['Seaweed Beach', 'Seaweed Rocks', 'Kelp Beach', 'Tree types']
            .contains(f.label))
        .toList();
    _faunaFields = beachFormFields
        .where((f) => [
      'Anemones',
      'Barnacles',
      'Bugs',
      'Snails',
      'Oysters',
      'Clams',
      'Limpets',
      'Turtles',
      'Mussels',
      'Birds',
      'Which Shells'
    ].contains(f.label))
        .toList();
    _woodFields = beachFormFields
        .where((f) => ['Kindling', 'Firewood', 'Logs', 'Trees'].contains(f.label))
        .toList();
    _compositionFields = beachFormFields
        .where((f) => [
      'Width',
      'Length',
      'Sand',
      'Pebbles',
      'Baseball Rocks',
      'Rocks',
      'Boulders',
      'Stone',
      'Coal',
      'Mud',
      'Midden',
      'Islands',
      'Bluff Height',
      'Bluffs Grade',
      'Shape',
      'Bluff Comp',
      'Rock Type'
    ].contains(f.label))
        .toList();
    _otherFields = beachFormFields
        .where((f) =>
    !_floraFields.contains(f) &&
        !_faunaFields.contains(f) &&
        !_woodFields.contains(f) &&
        !_compositionFields.contains(f))
        .toList();
  }

  void _initializeScreen() {
    _countryController.text = 'Canada';
    _provinceController.text = 'British Columbia';

    _beachNameController.addListener(() {
      if (widget.beachId == null) {
        setState(() {
          _appBarTitle = _beachNameController.text.isNotEmpty
              ? _beachNameController.text
              : "Add New Beach";
        });
      }
    });

    _pageController.addListener(() {
      setState(() {
        _currentPageIndex = _pageController.page?.round() ?? 0;
      });
    });

    if (widget.beachId != null) {
      _appBarTitle = "Add Contribution";
      _beachNameController.text = 'Existing Beach';
      _currentLocation = widget.initialLocation;
      WidgetsBinding.instance.addPostFrameCallback(
              (_) => FocusScope.of(context).requestFocus(_descriptionFocusNode));
    } else if (widget.initialLocation != null) {
      _currentLocation = widget.initialLocation;
      _reverseGeocodeLocation(
          _currentLocation!.latitude, _currentLocation!.longitude);
      WidgetsBinding.instance.addPostFrameCallback(
              (_) => FocusScope.of(context).requestFocus(_beachNameFocusNode));
    } else {
      _getCurrentLocationAndGeocode();
      WidgetsBinding.instance.addPostFrameCallback(
              (_) => FocusScope.of(context).requestFocus(_beachNameFocusNode));
    }
  }

  // --- Geolocation and Reverse Geocoding ---
  Future<void> _getCurrentLocationAndGeocode() async {
    setState(() => _gettingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        setState(() =>
        _currentLocation = LatLng(position.latitude, position.longitude));
        await _reverseGeocodeLocation(
            _currentLocation!.latitude, _currentLocation!.longitude);
      } else {
        _showSnackBar('Location permission denied.');
      }
    } catch (e) {
      _showSnackBar('Failed to get current location: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Future<void> _reverseGeocodeLocation(
      double latitude, double longitude) async {
    try {
      List<Placemark> placemarks =
      await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        setState(() {
          _municipalityController.text = place.locality ?? '';
          _provinceController.text = place.administrativeArea ?? '';
          _countryController.text = place.country ?? '';
        });
      }
    } catch (e) {
      _showSnackBar('Failed to get address details.');
    }
  }

  // --- Image & Scanner ---
  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null) {
      setState(() => _localImagePaths = [pickedFile.path]);
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Photo Library'),
              onTap: () {
                _pickImage(ImageSource.gallery);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Camera'),
              onTap: () {
                _pickImage(ImageSource.camera);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanForIdentifications() async {
    final List<ConfirmedIdentification>? confirmed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScannerScreen()),
    );
    if (confirmed != null) {
      setState(() => _scannerConfirmedIdentifications = confirmed);
      _showSnackBar('Received ${confirmed.length} identifications.');
    }
  }

  // --- Save confirmation dialog (with AI checkbox) ---


  Future<_SaveDialogResult?> _showSaveConfirmDialog() async {
    bool includeAi = false; // default OFF
    return showDialog<_SaveDialogResult>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Save Beach'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Are you sure you answered every question?'),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: includeAi,
                  onChanged: (v) => setState(() => includeAi = v ?? false),
                  title: const Text('Include an AI-generated image'),
                  subtitle: const Text('Optional (default off)'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context)
                    .pop(const _SaveDialogResult(false, false)),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context)
                    .pop(_SaveDialogResult(true, includeAi)),
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Save Logic ---
  Future<void> _saveNewBeach() async {
    if (_isSaving) return;

    final res = await _showSaveConfirmDialog();
    if (res == null || res.confirmed != true) return;
    final bool includeAiImage = res.includeAiImage;

    setState(() => _isSaving = true);
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please fill in all required fields.');
      setState(() => _isSaving = false);
      return;
    }
    _formKey.currentState!.save();

    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.currentUser == null) {
      _showSnackBar('You must be logged in.');
      setState(() => _isSaving = false);
      return;
    }
    if (_localImagePaths.isEmpty) {
      _showSnackBar('Please select at least one photo.');
      setState(() => _isSaving = false);
      return;
    }
    if (_currentLocation == null) {
      _showSnackBar('Could not determine location.');
      setState(() => _isSaving = false);
      return;
    }

    // Avoid trying to upload when offline
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      _showSnackBar('No internet connection. Try again when you are online.');
          setState(() => _isSaving = false);
    return;
    }

    try {
    final beachDataService =
    Provider.of<BeachDataService>(context, listen: false);
    _formData['Short Description'] = _shortDescriptionController.text;

    List<String> imageUrls = [];

    if (includeAiImage) {
    final aiPrompt = _buildAiImagePrompt();
    _showSnackBar('Uploading photo(s) and generating AI image...');
    final combined = await beachDataService.uploadUserAndAiImages(
    beachId: widget.beachId ?? 'new', // ok pre-ID
    userImageFile: File(_localImagePaths.first),
    aiPrompt: aiPrompt,
    );
    imageUrls = [combined['user']!, combined['ai']!];
    } else {
    _showSnackBar('Uploading photo(s)...');
    imageUrls = await beachDataService.uploadImages(_localImagePaths);
    }

    if (imageUrls.isEmpty) {
    _showSnackBar('Failed to upload images.');
    setState(() => _isSaving = false);
    return;
    }

    final contribution = Contribution(
    userId: authService.currentUser!.uid,
    userEmail: authService.currentUser!.email ?? '',
    timestamp: Timestamp.now(),
    latitude: _currentLocation!.latitude,
    longitude: _currentLocation!.longitude,
    contributedImageUrls: imageUrls,
    userAnswers: _formData,
    aiConfirmedFloraFauna: _scannerConfirmedIdentifications,
    aiConfirmedRockTypes: [],
    );

    if (widget.beachId != null) {
    await beachDataService.addContribution(
    beachId: widget.beachId!,
    contribution: contribution,
    userLatitude: _currentLocation!.latitude,
    userLongitude: _currentLocation!.longitude,
    );
    _showSnackBar('Contribution added successfully!');
    } else {
    _showSnackBar('Generating AI description...');
    final String aiDescription =
    await _geminiService.generateBeachDescription(
    beachName: _beachNameController.text,
    userAnswers: _formData,
    );

    final initialBeach = Beach(
    id: '',
    name: _beachNameController.text,
    latitude: _currentLocation!.latitude,
    longitude: _currentLocation!.longitude,
    // GeoHasher.encode expects (longitude, latitude)
    geohash: GeoHasher().encode(
    _currentLocation!.longitude,
    _currentLocation!.latitude,
    precision: 9,
    ),
    country: _countryController.text,
    province: _provinceController.text,
    municipality: _municipalityController.text,
    description: _shortDescriptionController.text,
    aiDescription: aiDescription,
    imageUrls: imageUrls,
    timestamp: Timestamp.now(),
    lastAggregated: Timestamp.now(),
    totalContributions: 0,
    aggregatedMetrics: {},
    aggregatedSingleChoices: {},
    aggregatedMultiChoices: {},
    aggregatedTextItems: {},
    identifiedFloraFauna: {},
    identifiedRockTypesComposition: {},
    identifiedBeachComposition: {},
    discoveryQuestions: [],
    educationalInfo: '',
    contributedDescriptions: [_shortDescriptionController.text],
    );

    await beachDataService.addBeach(
    initialBeach: initialBeach,
    initialContribution: contribution,
    );
    _showSnackBar('Beach saved successfully!');
    }

    if (mounted) Navigator.pop(context);
    } catch (e) {
    _showSnackBar('An error occurred: ${e.toString()}');
    } finally {
    if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- AI Prompt builder (uses concrete beach data) ---
  String _buildAiImagePrompt() {
    final parts = <String>[];

    // Title / where
    final beachName = _beachNameController.text.trim();
    final whereBits = [
      _municipalityController.text.trim(),
      _provinceController.text.trim(),
      _countryController.text.trim(),
    ].where((s) => s.isNotEmpty).join(', ');

    if (beachName.isNotEmpty) {
      parts.add('Photorealistic coastal landscape of "$beachName".');
    }
    if (whereBits.isNotEmpty) {
      parts.add('Location: $whereBits.');
    }

    // Short description (user text)
    final short = _shortDescriptionController.text.trim();
    if (short.isNotEmpty) parts.add('User notes: $short.');

    // Flora/fauna from scanner (top items)
    if (_scannerConfirmedIdentifications.isNotEmpty) {
      final names = _scannerConfirmedIdentifications
          .map((e) => e.commonName.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (names.isNotEmpty) {
        final limited = names.length > 6 ? names.sublist(0, 6) : names;
        parts.add(
            'Visible flora/fauna to include if natural to the scene: ${limited.join(", ")}.');
      }
    }

    // Structured features from form (numerics → intensity words)
    String lvl(num v) {
      if (v <= 1) return 'none';
      if (v <= 2) return 'a little';
      if (v <= 3) return 'some';
      if (v <= 4) return 'moderate';
      if (v <= 5) return 'a lot';
      return 'abundant';
    }

    void addIfNum(String label, String pretty) {
      final raw = _formData[label];
      if (raw is num && raw > 1) {
        parts.add('$pretty: ${lvl(raw)}.');
      }
    }

    // Common composition sliders
    addIfNum('Sand', 'Sand');
    addIfNum('Pebbles', 'Pebbles');
    addIfNum('Rocks', 'Rocks');
    addIfNum('Baseball Rocks', 'Baseball-sized rocks');
    addIfNum('Boulders', 'Boulders');
    addIfNum('Stone', 'Stone');
    addIfNum('Mud', 'Mud');
    addIfNum('Coal', 'Coal fragments');
    addIfNum('Midden', 'Shell midden');
    addIfNum('Islands', 'Nearby islets');
    addIfNum('Seaweed Beach', 'Washed-up seaweed on beach');
    addIfNum('Seaweed Rocks', 'Seaweed on intertidal rocks');
    addIfNum('Kelp Beach', 'Kelp on shore');
    addIfNum('Kindling', 'Small driftwood');
    addIfNum('Firewood', 'Driftwood');
    addIfNum('Logs', 'Large logs');
    addIfNum('Trees', 'Trees near shore');

    // Text fields we can pass through plainly if present
    void addIfText(String label, String prefix) {
      final raw = _formData[label];
      if (raw is String && raw.trim().isNotEmpty) {
        parts.add('$prefix ${raw.trim()}.');
      }
    }

    addIfText('Rock Type', 'Dominant rock type:');
    addIfText('Bluff Comp', 'Bluff composition:');
    addIfText('Shape', 'Shoreline shape:');

    // Guardrails for realism
    parts.addAll([
      'Time of day neutral; natural colors; no people; no text or logos.',
      'Angle: eye-level to slight wide angle; weather fair and believable.',
      'Only include features listed above; avoid adding structures or elements not specified.',
    ]);

    return parts.join(' ');
  }

  // --- UI & Build ---
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isNewBeach = widget.beachId == null;
    final List<String> pageTitles = [
      "Details",
      "Flora",
      "Fauna",
      "Wood",
      "Composition",
      "Other"
    ];

    _appBarTitle = "Add Contribution";
    if (isNewBeach && _currentPageIndex == 0) {
      _appBarTitle = _beachNameController.text.isNotEmpty
          ? _beachNameController.text
          : "Add New Beach";
    } else if (_currentPageIndex > 0) {
      _appBarTitle = pageTitles[_currentPageIndex];
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final bool shouldPop = await _showExitConfirmationDialog() ?? false;
        if (shouldPop && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_appBarTitle),
          actions: [
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(color: Colors.white),
              )
            else
              IconButton(icon: const Icon(Icons.save), onPressed: _saveNewBeach),
          ],
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
                  onPageChanged: (index) =>
                      setState(() => _currentPageIndex = index),
                  children: [
                    _buildDetailsPage(isNewBeach),
                    DynamicFormPage(
                        fields: _floraFields, formData: _formData),
                    DynamicFormPage(
                        fields: _faunaFields, formData: _formData),
                    DynamicFormPage(
                        fields: _woodFields, formData: _formData),
                    DynamicFormPage(
                      fields: _compositionFields,
                      formData: _formData,
                      widthController: _widthController,
                      lengthController: _lengthController,
                      bluffHeightController: _bluffHeightController,
                    ),
                    DynamicFormPage(
                        fields: _otherFields, formData: _formData),
                  ],
                ),
              ),
              _buildPageNavigator(pageTitles),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsPage(bool isNewBeach) {
    return KeepAlivePage(
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          TextFormField(
            controller: _beachNameController,
            focusNode: _beachNameFocusNode,
            decoration: const InputDecoration(labelText: 'Beach Name'),
            validator: isNewBeach
                ? (v) => v!.isEmpty ? 'Please enter a name' : null
                : null,
            onSaved: (v) => _formData['Beach Name'] = v,
            readOnly: !isNewBeach,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _shortDescriptionController,
            focusNode: _descriptionFocusNode,
            decoration: const InputDecoration(
                labelText: 'Short Description', border: OutlineInputBorder()),
            maxLines: 3,
            onSaved: (v) => _formData['Short Description'] = v,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _countryController,
            decoration: const InputDecoration(labelText: 'Country'),
            validator:
            isNewBeach ? (v) => v!.isEmpty ? 'Required' : null : null,
            onSaved: (v) => _formData['Country'] = v,
            readOnly: !isNewBeach,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _provinceController,
            decoration: const InputDecoration(labelText: 'Province'),
            validator:
            isNewBeach ? (v) => v!.isEmpty ? 'Required' : null : null,
            onSaved: (v) => _formData['Province'] = v,
            readOnly: !isNewBeach,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _municipalityController,
            decoration: const InputDecoration(labelText: 'Municipality'),
            validator:
            isNewBeach ? (v) => v!.isEmpty ? 'Required' : null : null,
            onSaved: (v) => _formData['Municipality'] = v,
            readOnly: !isNewBeach,
          ),
          const SizedBox(height: 16),
          Text(
            'Location: ${_currentLocation?.latitude.toStringAsFixed(4)}, ${_currentLocation?.longitude.toStringAsFixed(4)}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Main Beach Photo'),
            trailing: _localImagePaths.isEmpty
                ? const Icon(Icons.add_a_photo)
                : Image.file(
              File(_localImagePaths.first),
              width: 50,
              height: 50,
              fit: BoxFit.cover,
            ),
            onTap: _showImagePickerOptions,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _scanForIdentifications,
            icon: const Icon(Icons.camera_alt),
            label: Text(
                'Scan Flora/Fauna (${_scannerConfirmedIdentifications.length} confirmed)'),
          ),
          if (_scannerConfirmedIdentifications.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: _scannerConfirmedIdentifications
                    .map((id) => Chip(
                  label: Text(id.commonName),
                  onDeleted: () => setState(() =>
                      _scannerConfirmedIdentifications.remove(id)),
                ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPageNavigator(List<String> pageTitles) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Theme.of(context).primaryColor.withAlpha(25),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentPageIndex > 0)
            TextButton.icon(
              icon: const Icon(Icons.arrow_back),
              label: Text(pageTitles[_currentPageIndex - 1]),
              onPressed: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.ease),
            ),
          const Spacer(),
          if (_currentPageIndex < pageTitles.length - 1)
            TextButton.icon(
              label: Text(pageTitles[_currentPageIndex + 1]),
              icon: const Icon(Icons.arrow_forward),
              onPressed: () => _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.ease),
            ),
        ],
      ),
    );
  }

  Future<bool?> _showExitConfirmationDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text('Do you want to discard your changes?'),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes')),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  void dispose() {
    _beachNameController.dispose();
    _shortDescriptionController.dispose();
    _countryController.dispose();
    _provinceController.dispose();
    _municipalityController.dispose();
    _widthController.dispose();
    _lengthController.dispose();
    _bluffHeightController.dispose();
    _pageController.dispose();
    _descriptionFocusNode.dispose();
    _beachNameFocusNode.dispose();
    super.dispose();
  }
}

class KeepAlivePage extends StatefulWidget {
  final Widget child;
  const KeepAlivePage({super.key, required this.child});

  @override
  State<KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<KeepAlivePage>
    with AutomaticKeepAliveClientMixin<KeepAlivePage> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}