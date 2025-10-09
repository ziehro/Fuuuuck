// lib/services/api/mlkit_service.dart
import 'dart:io';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:flutter/foundation.dart';

class MLKitService {
  final ImageLabeler _imageLabeler = ImageLabeler(
    options: ImageLabelerOptions(
      confidenceThreshold: 0.5, // Only show results above 50% confidence
    ),
  );

  /// Identify objects/scenes in an image
  Future<List<Map<String, dynamic>>> identifyImage(File imageFile) async {
    try {
      debugPrint('Processing image with ML Kit...');

      final inputImage = InputImage.fromFile(imageFile);
      final labels = await _imageLabeler.processImage(inputImage);

      debugPrint('Found ${labels.length} labels');

      // Convert to format similar to iNaturalist for compatibility
      final results = labels.map((label) {
        return {
          'taxon': {
            'id': label.label.hashCode, // Generate a unique ID
            'name': label.label,
            'preferred_common_name': label.label,
            'default_photo': {
              'url': '', // No photo available from ML Kit
            },
          },
          'score': label.confidence,
          'confidence': label.confidence,
        };
      }).toList();

      // Sort by confidence (highest first)
      results.sort((a, b) =>
          (b['confidence'] as double).compareTo(a['confidence'] as double)
      );

      return results;
    } catch (e) {
      debugPrint('Error processing image with ML Kit: $e');
      throw Exception('Failed to analyze image: $e');
    }
  }

  /// Get more details about a label (placeholder for future enhancement)
  Future<Map<String, dynamic>?> getLabelDetails(String labelText) async {
    // ML Kit doesn't provide detailed info like iNaturalist
    // You could potentially integrate with Wikipedia API here
    return {
      'wikipedia_summary': 'For detailed information about $labelText, '
          'please search online resources.',
    };
  }

  void dispose() {
    _imageLabeler.close();
  }
}

// Alternative: Use with custom models
// For better marine life detection, you could train a custom TensorFlow Lite model
class CustomMLKitService {
  ImageLabeler? _customLabeler;

  Future<void> initialize() async {
    // If you have a custom TFLite model for marine species
    const modelPath = 'assets/ml/marine_species_model.tflite';

    _customLabeler = ImageLabeler(
      options: LocalLabelerOptions(
        modelPath: modelPath,
        confidenceThreshold: 0.5,
      ),
    );
  }

  Future<List<Map<String, dynamic>>> identifyImage(File imageFile) async {
    if (_customLabeler == null) {
      throw Exception('Custom model not initialized');
    }

    final inputImage = InputImage.fromFile(imageFile);
    final labels = await _customLabeler!.processImage(inputImage);

    return labels.map((label) {
      return {
        'taxon': {
          'id': label.label.hashCode,
          'name': label.label,
          'preferred_common_name': label.label,
          'default_photo': {'url': ''},
        },
        'score': label.confidence,
        'confidence': label.confidence,
      };
    }).toList();
  }

  void dispose() {
    _customLabeler?.close();
  }
}