// lib/util/shell_icons.dart
import 'package:flutter/material.dart';
import 'package:mybeachbook/services/shell_image_service.dart';

class ShellIcons {
  static final ShellImageService _service = ShellImageService();

  static Future<void> initialize() async {
    await _service.initialize();
  }

  static ImageProvider? getImageProvider(String shellName) {
    return _service.getShellImage(shellName);
  }

  static bool get isReady => _service.isInitialized;
}