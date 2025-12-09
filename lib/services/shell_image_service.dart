// lib/services/shell_image_service.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';

class ShellImageService {
  static final ShellImageService _instance = ShellImageService._internal();
  factory ShellImageService() => _instance;
  ShellImageService._internal();

  final Map<String, ImageProvider> _cachedImages = {};
  bool _isInitialized = false;

  static const Map<String, Map<String, int>> _shellPositions = {
    'Butter Clam': {'row': 0, 'col': 0},
    'Mussel': {'row': 0, 'col': 1},
    'Crab': {'row': 0, 'col': 2},
    'Oyster': {'row': 0, 'col': 3},
    'Whelks': {'row': 0, 'col': 4},
    'Turban': {'row': 1, 'col': 0},
    'Sand dollars': {'row': 1, 'col': 1},
    'Cockles': {'row': 1, 'col': 2},
    'Starfish': {'row': 1, 'col': 3},
    'Limpets': {'row': 1, 'col': 4},
  };

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final ByteData data = await rootBundle.load('assets/shells_grid.png');
      final Uint8List bytes = data.buffer.asUint8List();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image gridImage = frameInfo.image;

      final int gridWidth = gridImage.width;
      final int gridHeight = gridImage.height;

      final double cellWidth = gridWidth / 5.0;
      final double cellHeight = gridHeight / 2.0;

      debugPrint('📏 Grid: ${gridWidth}x${gridHeight}, Cell: ${cellWidth.toStringAsFixed(1)}x${cellHeight.toStringAsFixed(1)}');

      // Get pixel data for circle detection
      final ByteData? pixelData = await gridImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (pixelData == null) {
        throw Exception('Failed to get pixel data');
      }

      for (final entry in _shellPositions.entries) {
        final String shellName = entry.key;
        final int row = entry.value['row']!;
        final int col = entry.value['col']!;

        final int cellX = (col * cellWidth).round();
        final int cellY = (row * cellHeight).round();
        final int cellW = cellWidth.round();
        final int cellH = cellHeight.round();

        // Detect the white circle in this cell
        final circleInfo = _detectCircle(
          pixelData,
          gridWidth,
          gridHeight,
          cellX,
          cellY,
          cellW,
          cellH,
        );

        if (circleInfo != null) {
          // Adjust to crop tighter - reduce radius by 15% and shift center up by 8%
          final int adjustedRadius = (circleInfo['radius']! * 0.85).round();
          final int adjustedCenterY = circleInfo['y']! - (circleInfo['radius']! * 0.15).round();

          debugPrint('🎯 $shellName: Original (${circleInfo['x']}, ${circleInfo['y']}) r${circleInfo['radius']} -> Adjusted (${circleInfo['x']}, $adjustedCenterY) r$adjustedRadius');

          // Extract and mask the circle with adjusted values
          final ui.Image shellImage = await _extractCircularPortion(
            gridImage,
            circleInfo['x']!,
            adjustedCenterY,
            adjustedRadius,
          );

          final ByteData? shellBytes = await shellImage.toByteData(
            format: ui.ImageByteFormat.png,
          );

          if (shellBytes != null) {
            _cachedImages[shellName] = MemoryImage(
              shellBytes.buffer.asUint8List(),
            );
          }

          shellImage.dispose();
        } else {
          debugPrint('❌ $shellName: Could not detect circle');
        }
      }

      gridImage.dispose();
      _isInitialized = true;
      debugPrint('✅ Shell images extracted successfully');
    } catch (e) {
      debugPrint('❌ Error extracting shell images: $e');
    }
  }

  /// Detect white circle in a cell region
  Map<String, int>? _detectCircle(
      ByteData pixelData,
      int imageWidth,
      int imageHeight,
      int cellX,
      int cellY,
      int cellWidth,
      int cellHeight,
      ) {
    // Find bounds of white pixels
    int? minX, maxX, minY, maxY;

    for (int y = cellY; y < cellY + cellHeight && y < imageHeight; y++) {
      for (int x = cellX; x < cellX + cellWidth && x < imageWidth; x++) {
        if (_isWhitePixel(pixelData, x, y, imageWidth)) {
          minX = (minX == null) ? x : (x < minX ? x : minX);
          maxX = (maxX == null) ? x : (x > maxX ? x : maxX);
          minY = (minY == null) ? y : (y < minY ? y : minY);
          maxY = (maxY == null) ? y : (y > maxY ? y : maxY);
        }
      }
    }

    if (minX == null || maxX == null || minY == null || maxY == null) {
      return null;
    }

    // Calculate center and radius
    final int centerX = (minX + maxX) ~/ 2;
    final int centerY = (minY + maxY) ~/ 2;
    final int width = maxX - minX;
    final int height = maxY - minY;
    final int radius = ((width + height) ~/ 4); // Average of width/height divided by 2

    return {
      'x': centerX,
      'y': centerY,
      'radius': radius,
    };
  }

  /// Check if a pixel is white/light (part of the circle background)
  bool _isWhitePixel(ByteData pixelData, int x, int y, int imageWidth) {
    final int offset = (y * imageWidth + x) * 4;

    if (offset + 2 >= pixelData.lengthInBytes) return false;

    final int r = pixelData.getUint8(offset);
    final int g = pixelData.getUint8(offset + 1);
    final int b = pixelData.getUint8(offset + 2);

    // White or very light gray (threshold of 200 for each channel)
    return r > 200 && g > 200 && b > 200;
  }

  /// Extract a circular portion with masking to remove background
  Future<ui.Image> _extractCircularPortion(
      ui.Image sourceImage,
      int centerX,
      int centerY,
      int radius,
      ) async {
    final int size = radius * 2;
    final int x = centerX - radius;
    final int y = centerY - radius;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    // Create circular clipping path
    final Path clipPath = Path()
      ..addOval(Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()));
    canvas.clipPath(clipPath);

    // Draw the extracted portion (only the circular area will show)
    canvas.drawImageRect(
      sourceImage,
      Rect.fromLTWH(x.toDouble(), y.toDouble(), size.toDouble(), size.toDouble()),
      Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      Paint(),
    );

    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(size, size);
    picture.dispose();

    return image;
  }

  ImageProvider? getShellImage(String shellName) {
    return _cachedImages[shellName];
  }

  bool get isInitialized => _isInitialized;
}