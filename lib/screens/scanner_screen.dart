// lib/screens/scanner_screen.dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:path/path.dart' show join;
import 'package:mybeachbook/services/api/inaturalist_service.dart';
import 'package:mybeachbook/models/confirmed_identification.dart';
import 'package:mybeachbook/screens/add_beach_screen.dart';

import '../services/api/mlkit_service.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  Future<void>? _initializeControllerFuture;
  String? _imagePath;
  bool _isProcessingImage = false;
  List<dynamic> _identificationResults = [];
  String? _identificationError;

  final List<ConfirmedIdentification> _confirmedIdentifications = [];
  final Set<int> _selectedSuggestionIndices = {};

  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;
  double _currentZoomLevel = 1.0;
  double _initialZoomLevel = 1.0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        _showSnackBar('No cameras found on this device.');
        return;
      }
      CameraDescription selectedCamera = _cameras!.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras![0],
      );

      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      _initializeControllerFuture = _controller!.initialize().then((_) async {
        if (!mounted) return;
        _minZoomLevel = await _controller!.getMinZoomLevel();
        _maxZoomLevel = await _controller!.getMaxZoomLevel();
        _currentZoomLevel = _minZoomLevel;
        await _controller!.setZoomLevel(_currentZoomLevel);
        setState(() {});
      });
    } on CameraException catch (e) {
      _showSnackBar('Error initializing camera: ${e.description}');
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isTakingPicture) return;

    try {
      setState(() {
        _isProcessingImage = true;
        _identificationError = null;
        _identificationResults = [];
        _selectedSuggestionIndices.clear();
      });

      await _initializeControllerFuture;
      final image = await _controller!.takePicture();
      final path = join((await getTemporaryDirectory()).path, '${DateTime.now()}.jpg');
      await image.saveTo(path);

      setState(() => _imagePath = path);

      final mlkitService = MLKitService();
      final results = await mlkitService.identifyImage(File(path));
      setState(() {
        _identificationResults = results;
        if (results.isEmpty) _showSnackBar('No identification results found.');
      });
    } catch (e) {
      setState(() {
        _identificationError = e.toString().replaceFirst('Exception: ', '');
      });
      _showSnackBar('Identification failed: $_identificationError');
    } finally {
      if (mounted) {
        setState(() => _isProcessingImage = false);
      }
    }
  }

  void _confirmSelectedIdentifications() {
    if (_selectedSuggestionIndices.isEmpty) {
      _showSnackBar('No items selected to confirm.');
      return;
    }

    for (int index in _selectedSuggestionIndices) {
      final result = _identificationResults[index];
      final taxon = result['taxon'];
      final String commonName = taxon['preferred_common_name'] ?? taxon['name'] ?? 'Unknown';
      final String scientificName = taxon['name'] ?? 'Unknown Scientific Name';
      final int taxonId = taxon['id'];
      final String imageUrl = taxon['default_photo'] != null ? taxon['default_photo']['url'] : '';

      // Avoid adding duplicates
      if (!_confirmedIdentifications.any((item) => item.taxonId == taxonId)) {
        _confirmedIdentifications.add(
          ConfirmedIdentification(
            commonName: commonName,
            scientificName: scientificName,
            taxonId: taxonId,
            imageUrl: imageUrl,
          ),
        );
      }
    }

    setState(() {
      _showSnackBar('Confirmed ${_selectedSuggestionIndices.length} item(s)!');
      _identificationResults.clear();
      _selectedSuggestionIndices.clear();
      _imagePath = null;
    });
  }

  void _clearResults() {
    setState(() {
      _identificationResults = [];
      _imagePath = null;
      _identificationError = null;
      _selectedSuggestionIndices.clear();
    });
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _initialZoomLevel = _currentZoomLevel;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    double newZoomLevel = (_initialZoomLevel * details.scale).clamp(_minZoomLevel, _maxZoomLevel);
    if ((newZoomLevel - _currentZoomLevel).abs() > 0.005) {
      _controller!.setZoomLevel(newZoomLevel);
      setState(() => _currentZoomLevel = newZoomLevel);
    }
  }

  // NEW: Handle the "Done" button with dialog
  Future<void> _handleDone() async {
    if (_confirmedIdentifications.isEmpty) {
      // No identifications, just go back
      Navigator.of(context).pop();
      return;
    }

    // Show dialog asking what to do with the identifications
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('What would you like to do?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You have identified ${_confirmedIdentifications.length} ${_confirmedIdentifications.length == 1 ? 'item' : 'items'}:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...(_confirmedIdentifications.take(3).map((item) => Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                child: Text('• ${item.commonName}'),
              ))),
              if (_confirmedIdentifications.length > 3)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                  child: Text('... and ${_confirmedIdentifications.length - 3} more'),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('discard'),
              child: const Text('Discard'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('save'),
              child: const Text('Save for Later'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop('new_beach'),
              icon: const Icon(Icons.add_location_alt),
              label: const Text('Add to New Beach'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    switch (result) {
      case 'new_beach':
      // Navigate to Add Beach Screen with the identifications
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => AddBeachScreen(
              initialIdentifications: _confirmedIdentifications,
            ),
          ),
        );
        break;

      case 'save':
      // TODO: Implement saving to a "saved scans" collection or local storage
        _showSnackBar('Saved ${_confirmedIdentifications.length} identifications');
        Navigator.of(context).pop(_confirmedIdentifications);
        break;

      case 'discard':
      default:
      // Just go back without returning anything
        Navigator.of(context).pop();
        break;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner'),
        actions: [
          if (_confirmedIdentifications.isNotEmpty)
            TextButton.icon(
              onPressed: _handleDone,
              icon: const Icon(Icons.check, color: Colors.white),
              label: Text(
                'Done (${_confirmedIdentifications.length})',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return Stack(
            children: [
              GestureDetector(
                onScaleStart: _handleScaleStart,
                onScaleUpdate: _handleScaleUpdate,
                child: CameraPreview(_controller!),
              ),

              // Confirmed items display at bottom
              if (_confirmedIdentifications.isNotEmpty)
                Positioned(
                  bottom: 90,
                  left: 10,
                  right: 10,
                  child: Card(
                    color: Colors.black.withOpacity(0.7),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Confirmed Identifications',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 4.0,
                            children: _confirmedIdentifications.map((item) {
                              return Chip(
                                label: Text(item.commonName),
                                deleteIconColor: Colors.white,
                                onDeleted: () {
                                  setState(() {
                                    _confirmedIdentifications.remove(item);
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              if (_isProcessingImage)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(color: Colors.white),
                ),

              if (_identificationResults.isNotEmpty && !_isProcessingImage)
                _buildResultsOverlay(),

              Positioned(
                bottom: 20.0,
                left: 0,
                right: 0,
                child: Center(
                  child: FloatingActionButton(
                    onPressed: _isProcessingImage || _identificationResults.isNotEmpty
                        ? null
                        : _takePicture,
                    backgroundColor: _isProcessingImage || _identificationResults.isNotEmpty
                        ? Colors.grey
                        : Theme.of(context).floatingActionButtonTheme.backgroundColor,
                    child: _isProcessingImage
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Icon(Icons.camera_alt),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildResultsOverlay() {
    return Positioned.fill(
      child: Card(
        margin: const EdgeInsets.all(16).copyWith(bottom: 90),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Text('Confirm Identified Item:', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _identificationResults.length,
                  itemBuilder: (context, index) {
                    final result = _identificationResults[index];
                    final taxon = result['taxon'];
                    final name = taxon['preferred_common_name'] ?? taxon['name'] ?? 'Unknown';
                    final photoUrl = taxon['default_photo']?['url'] ?? '';
                    final isSelected = _selectedSuggestionIndices.contains(index);

                    return Card(
                      color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.3) : null,
                      child: ListTile(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedSuggestionIndices.remove(index);
                            } else {
                              _selectedSuggestionIndices.add(index);
                            }
                          });
                        },
                        leading: photoUrl.isNotEmpty
                            ? Image.network(photoUrl, width: 50, height: 50, fit: BoxFit.cover)
                            : const Icon(Icons.image_not_supported, size: 50),
                        title: Text(name),
                        trailing: isSelected ? const Icon(Icons.check_circle) : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton(
                    onPressed: _selectedSuggestionIndices.isEmpty
                        ? null
                        : _confirmSelectedIdentifications,
                    child: Text('Confirm (${_selectedSuggestionIndices.length})'),
                  ),
                  ElevatedButton(
                    onPressed: _clearResults,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}