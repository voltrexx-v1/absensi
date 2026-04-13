import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

/// Web-specific camera controller using HTML5 getUserMedia API.
/// This bypasses Flutter's `camera` package entirely and uses the browser's
/// native webcam API, which is far more reliable on web.

class WebCameraController {
  html.VideoElement? _video;
  html.MediaStream? _stream;
  String? _viewType;
  bool _initialized = false;

  bool get isInitialized => _initialized;
  String get viewType => _viewType ?? '';

  Future<void> initialize() async {
    _viewType = 'webcam-live-${DateTime.now().millisecondsSinceEpoch}';

    _video = html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..setAttribute('playsinline', 'true')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover'
      ..style.transform = 'scaleX(-1)'; // Mirror for selfie mode

    _stream = await html.window.navigator.mediaDevices!.getUserMedia({
      'video': {
        'facingMode': 'user',
        'width': {'ideal': 640},
        'height': {'ideal': 480},
      },
      'audio': false,
    });

    _video!.srcObject = _stream;
    await _video!.onLoadedMetadata.first;

    // Register as platform view for HtmlElementView
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType!,
      (int viewId) => _video!,
    );

    _initialized = true;
  }

  /// Capture a single frame from the webcam as JPEG bytes.
  Future<Uint8List?> capture() async {
    if (_video == null || !_initialized) return null;

    final canvas = html.CanvasElement(
      width: _video!.videoWidth,
      height: _video!.videoHeight,
    );

    // Mirror the capture to match the preview
    final ctx = canvas.context2D;
    ctx.translate(canvas.width!.toDouble(), 0);
    ctx.scale(-1, 1);
    ctx.drawImage(_video!, 0, 0);

    // Convert canvas to JPEG data URL, then to bytes
    final dataUrl = canvas.toDataUrl('image/jpeg', 0.85);
    final base64Str = dataUrl.split(',').last;
    return base64Decode(base64Str);
  }

  void dispose() {
    _stream?.getTracks().forEach((track) => track.stop());
    _video?.srcObject = null;
    _video = null;
    _initialized = false;
  }
}

/// Builds a live webcam preview widget using HtmlElementView.
Widget buildWebCameraPreview(WebCameraController controller) {
  if (!controller.isInitialized) {
    return const Center(child: CircularProgressIndicator(color: Colors.amber));
  }
  return ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: HtmlElementView(viewType: controller.viewType),
  );
}
