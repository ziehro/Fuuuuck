// lib/screens/scanner_screen.dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:path/path.dart' show join;
import 'package:fuuuuck/services/api/inaturalist_service.dart';
// For debugPrint
import 'package:fuuuuck/models/confirmed_identification.dart';


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
  List<dynamic> _identificationResults = []; // iNaturalist raw results
  String? _identificationError;

  // List to hold confirmed identifications by the user
  final List<ConfirmedIdentification> _confirmedIdentifications = [];

  // State to manage selected suggestions for confirmation
  final Set<int> _selectedSuggestionIndices = {};

  // --- Zoom related variables ---
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;
  double _currentZoomLevel = 1.0;
  double _initialZoomLevel = 1.0; // To store zoom at start of gesture


  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        debugPrint('No cameras found.');
        _showSnackBar('No cameras found on this device.');
        return;
      }
      CameraDescription selectedCamera = _cameras!.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras![0], // Fallback to first camera if no back camera
      );

      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.high, // Changed to high for better scan quality
        enableAudio: false,
      );

      _initializeControllerFuture = _controller!.initialize().then((_) async {
        if (!mounted) {
          return;
        }
        // Get zoom levels after initialization
        _minZoomLevel = await _controller!.getMinZoomLevel();
        _maxZoomLevel = await _controller!.getMaxZoomLevel();
        _currentZoomLevel = _minZoomLevel; // Start at minimum zoom
        await _controller!.setZoomLevel(_currentZoomLevel); // Apply initial zoom

        setState(() {}); // Rebuild to show camera preview
      });
    } on CameraException catch (e) {
      debugPrint('Error initializing camera: $e');
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
    if (_controller == null || !_controller!.value.isInitialized) {
      debugPrint('Controller not initialized.');
      _showSnackBar('Camera not ready.');
      return;
    }
    if (_controller!.value.isTakingPicture) {
      return;
    }

    try {
      setState(() {
        _isProcessingImage = true; // Start loading indicator
        _identificationError = null; // Clear previous errors
        _identificationResults = []; // Clear previous results
        _selectedSuggestionIndices.clear(); // Clear selections
      });

      await _initializeControllerFuture; // Wait for controller to initialize
      final image = await _controller!.takePicture(); // Take the picture

      // Get a temporary directory to store the image
      final directory = await getTemporaryDirectory();
      final path = join(directory.path, '${DateTime.now()}.jpg'); // Save as JPG
      await image.saveTo(path);

      setState(() {
        _imagePath = path; // Store the path to display/process later
      });

      debugPrint('Picture taken and saved to: $_imagePath');

      // --- Integrate iNaturalist API call here ---
      final inatService = INaturalistService();
      try {
        debugPrint('Attempting iNaturalist API call...');
        final results = await inatService.identifyImage(File(path));
        setState(() {
          _identificationResults = results;
        });
        debugPrint('iNaturalist Results: $results');
        if (results.isEmpty) {
          _showSnackBar('No identification results found.');
        } else {
          _showSnackBar('Identification complete! Review suggestions.');
        }
      } catch (e) {
        setState(() {
          // Ensure we display the specific error message from the service
          _identificationError = e.toString().replaceFirst('Exception: ', '');
        });
        debugPrint('Identification error caught in ScannerScreen: $e');
        _showSnackBar('Identification failed: ${e.toString().replaceFirst('Exception: ', '')}');
      }

    } on CameraException catch (e) {
      debugPrint('Error taking picture: $e');
      _showSnackBar('Error taking picture: ${e.description}');
    } finally {
      // ** NEW: Ensure processing state is always reset **
      if (mounted) {
        setState(() {
          _isProcessingImage = false;
        });
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

      _confirmedIdentifications.add(
        ConfirmedIdentification(
          commonName: commonName,
          scientificName: scientificName,
          taxonId: taxonId,
          imageUrl: imageUrl,
        ),
      );
    }
    // Clear results and selections after confirmation, ready for next scan
    setState(() {
      _identificationResults.clear();
      _selectedSuggestionIndices.clear();
      _imagePath = null; // Clear image preview too
      _showSnackBar('Confirmed ${_selectedSuggestionIndices.length} item(s)!');
      debugPrint('Confirmed Identifications: ${_confirmedIdentifications.map((e) => e.commonName).toList()}');
    });
    // Here you would typically push _confirmedIdentifications to your
    // data collection mechanism (e.g., a temporary list for the current beach session)
  }

  void _clearResults() {
    setState(() {
      _identificationResults = [];
      _imagePath = null;
      _identificationError = null;
      _selectedSuggestionIndices.clear();
    });
  }

  // --- Zoom Gesture Handlers ---
  void _handleScaleStart(ScaleStartDetails details) {
    _initialZoomLevel = _currentZoomLevel;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    // Calculate the new zoom level based on the initial zoom and the scale gesture
    double newZoomLevel = _initialZoomLevel * details.scale;

    // Clamp the zoom level to the camera's min and max zoom levels
    newZoomLevel = newZoomLevel.clamp(_minZoomLevel, _maxZoomLevel);

    // Only update if the zoom level has actually changed significantly
    if ((newZoomLevel - _currentZoomLevel).abs() > 0.005) {
      _controller!.setZoomLevel(newZoomLevel);
      setState(() {
        _currentZoomLevel = newZoomLevel;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initializeControllerFuture == null || _controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<void>(
      future: _initializeControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (_controller!.value.isInitialized) {
            final mediaSize = MediaQuery.of(context).size;
            final cameraAspectRatio = _controller!.value.aspectRatio;

            double scale = cameraAspectRatio / (mediaSize.width / mediaSize.height);
            if (cameraAspectRatio < mediaSize.width / mediaSize.height) {
              scale = (mediaSize.height / mediaSize.width) / cameraAspectRatio; // Corrected calculation
            }

            return Stack(
              children: [
                // Camera Preview filling the entire screen without distortion
                ClipRect(
                  child: OverflowBox(
                    maxWidth: double.infinity,
                    maxHeight: double.infinity,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: mediaSize.width * scale,
                      height: mediaSize.height * scale,
                      // --- Wrap CameraPreview in GestureDetector for zoom ---
                      child: GestureDetector(
                        onScaleStart: _handleScaleStart,
                        onScaleUpdate: _handleScaleUpdate,
                        child: CameraPreview(_controller!),
                      ),
                      // --- End GestureDetector wrap ---
                    ),
                  ),
                ),

                // Processing Indicator
                if (_isProcessingImage)
                  Container(
                    color: Colors.black.withOpacity(0.5),
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(color: Colors.white),
                  ),

                // Error Message Overlay
                if (_identificationError != null)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.7),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Error: $_identificationError',
                            style: const TextStyle(color: Colors.redAccent, fontSize: 18),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Identification Results Overlay (for confirmation)
                if (_identificationResults.isNotEmpty && !_isProcessingImage)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 10,
                    left: 10,
                    right: 10,
                    bottom: 10, // Extend to bottom to allow scroll
                    child: Card(
                      color: Theme.of(context).cardTheme.color?.withOpacity(0.9) ?? Colors.white.withOpacity(0.9),
                      margin: EdgeInsets.zero,
                      shape: Theme.of(context).cardTheme.shape,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Confirm Identified Species:',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18, color: Theme.of(context).appBarTheme.foregroundColor),
                            ),
                            const SizedBox(height: 8),
                            Expanded( // Use Expanded to make the list scrollable
                              child: ListView.builder(
                                shrinkWrap: true, // Important for nested list views
                                itemCount: _identificationResults.length,
                                itemBuilder: (context, index) {
                                  final result = _identificationResults[index];
                                  final taxon = result['taxon'];
                                  final String name = taxon['preferred_common_name'] ?? taxon['name'] ?? 'Unknown';
                                  final String scientificName = taxon['name'] ?? '';
                                  final double score = result['score'] ?? 0.0;
                                  final String photoUrl = taxon['default_photo'] != null ? taxon['default_photo']['url'] : '';

                                  final bool isSelected = _selectedSuggestionIndices.contains(index);

                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedSuggestionIndices.remove(index);
                                        } else {
                                          _selectedSuggestionIndices.add(index);
                                        }
                                      });
                                    },
                                    child: Card(
                                      color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.7) : Colors.grey[200],
                                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Row(
                                          children: [
                                            if (photoUrl.isNotEmpty)
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(4),
                                                child: Image.network(
                                                  photoUrl,
                                                  width: 50,
                                                  height: 50,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) =>
                                                  const Icon(Icons.broken_image, size: 50),
                                                ),
                                              )
                                            else
                                              Icon(Icons.image_not_supported, size: 50, color: Colors.grey[600]),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    name,
                                                    style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        color: isSelected ? Colors.white : Colors.black87),
                                                  ),
                                                  Text(
                                                    scientificName,
                                                    style: TextStyle(
                                                        fontStyle: FontStyle.italic,
                                                        fontSize: 12,
                                                        color: isSelected ? Colors.white70 : Colors.black54),
                                                  ),
                                                  Text(
                                                    'Confidence: ${(score * 100).toStringAsFixed(1)}%',
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color: isSelected ? Colors.white70 : Colors.black54),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (isSelected) Icon(Icons.check_circle, color: Theme.of(context).colorScheme.secondary),
                                          ],
                                        ),
                                      ),
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
                                  onPressed: _selectedSuggestionIndices.isEmpty ? null : _confirmSelectedIdentifications,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).floatingActionButtonTheme.backgroundColor,
                                    foregroundColor: Theme.of(context).floatingActionButtonTheme.foregroundColor,
                                  ),
                                  child: Text('Confirm (${_selectedSuggestionIndices.length})'),
                                ),
                                ElevatedButton(
                                  onPressed: _clearResults,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Cancel'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Camera capture button (remains at the bottom)
                Positioned(
                  bottom: 20.0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FloatingActionButton(
                      onPressed: _isProcessingImage || _identificationResults.isNotEmpty ? null : _takePicture,
                      backgroundColor: _isProcessingImage || _identificationResults.isNotEmpty
                          ? Colors.grey // Dim button while disabled
                          : Theme.of(context).floatingActionButtonTheme.backgroundColor,
                      foregroundColor: Theme.of(context).floatingActionButtonTheme.foregroundColor, // Disable button while processing or showing results
                      child: _isProcessingImage
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Icon(Icons.camera_alt),
                    ),
                  ),
                ),
                // Display captured image (for testing purposes, hidden when results show)
                if (_imagePath != null && !_isProcessingImage && _identificationResults.isEmpty && _identificationError == null)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 20,
                    right: 20,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.black.withOpacity(0.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_imagePath!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          } else {
            return const Center(child: Text('Failed to initialize camera.'));
          }
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}