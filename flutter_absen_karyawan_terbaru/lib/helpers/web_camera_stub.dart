import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Stub implementation for non-web platforms (mobile/desktop).
/// Web camera features are not available. The regular `camera` package is used instead.

class WebCameraController {
  bool get isInitialized => false;
  String get viewType => '';

  Future<void> initialize() async {
    // No-op on non-web platforms
  }

  Future<Uint8List?> capture() async {
    return null;
  }

  void dispose() {}
}

Widget buildWebCameraPreview(WebCameraController controller) {
  return const Center(
    child: Text(
      'Web camera not available on this platform.\nUse the camera package instead.',
      style: TextStyle(color: Colors.white54),
      textAlign: TextAlign.center,
    ),
  );
}
