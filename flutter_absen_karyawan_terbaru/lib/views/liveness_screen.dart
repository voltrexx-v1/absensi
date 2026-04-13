import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/foundation.dart';

class LivenessDetectionScreen extends StatefulWidget {
  const LivenessDetectionScreen({Key? key}) : super(key: key);

  @override
  State<LivenessDetectionScreen> createState() => _LivenessDetectionScreenState();
}

class _LivenessDetectionScreenState extends State<LivenessDetectionScreen> {
  CameraController? _cameraController;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  bool _isBusy = false;
  bool _isStraight = false;
  bool _hasBlinked = false;
  bool _hasSmiled = false;
  
  String _instruction = "Posisikan wajah di tengah dan lihat lurus.";

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (kIsWeb) {
      setState(() => _instruction = "Liveness tidak didukung di Web. Anggap sukses.");
      Future.delayed(const Duration(seconds: 2), () {
        Navigator.pop(context, 'web_mock_path'); // Web mock
      });
      return;
    }

    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => cameras.first);

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      setState(() {});

      _cameraController!.startImageStream((image) {
        if (!_isBusy) {
          _isBusy = true;
          _processImage(image);
        }
      });
    } catch (e) {
      setState(() => _instruction = "Gagal mengakses kamera: $e");
    }
  }

  Future<void> _processImage(CameraImage image) async {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final camera = _cameraController!.description;
      final imageRotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation) ?? InputImageRotation.rotation0deg;
      final inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;

      final planeData = image.planes.map(
        (Plane plane) {
          return InputImageMetadata(
            size: Size((plane.width ?? 0).toDouble(), (plane.height ?? 0).toDouble()),
            rotation: imageRotation,
            format: inputImageFormat,
            bytesPerRow: plane.bytesPerRow,
          );
        },
      ).toList();

      if (planeData.isEmpty) { _isBusy = false; return; }

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: planeData.first,
      );

      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        _updateInstruction("Wajah tidak terdeteksi.");
      } else if (faces.length > 1) {
        _updateInstruction("Terdeteksi lebih dari satu wajah!");
      } else {
        final face = faces.first;
        
        // 1. Straight gaze check
        if (!_isStraight) {
          if ((face.headEulerAngleY ?? 100).abs() < 10 && (face.headEulerAngleZ ?? 100).abs() < 10) {
            _isStraight = true;
            _updateInstruction("Bagus! Sekarang, silakan berkedip (Tutup mata lalu buka).");
          } else {
            _updateInstruction("Lihat lurus ke arah kamera.");
          }
        } 
        // 2. Blink check
        else if (!_hasBlinked) {
          if ((face.leftEyeOpenProbability ?? 1.0) < 0.2 && (face.rightEyeOpenProbability ?? 1.0) < 0.2) {
             _hasBlinked = true;
             _updateInstruction("Bagus! Sekarang, berikan senyuman terbaik Anda.");
          }
        }
        // 3. Smile check
        else if (!_hasSmiled) {
          if ((face.smilingProbability ?? 0.0) > 0.6) {
             _hasSmiled = true;
             _updateInstruction("Liveness Berhasil! Mengambil foto...");
             _captureFrame();
          }
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      _isBusy = false; // Release lock for next frame
    }
  }

  void _updateInstruction(String text) {
    if (_instruction != text) {
      if (mounted) setState(() => _instruction = text);
    }
  }

  Future<void> _captureFrame() async {
    try {
      await _cameraController!.stopImageStream();
      final file = await _cameraController!.takePicture();
      if (mounted) Navigator.pop(context, file.path);
    } catch (e) {
      _updateInstruction("Gagal mengambil foto: $e");
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(_instruction, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_cameraController!),
          // Liveness overlay
          ColorFiltered(
            colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.7), BlendMode.srcOut),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Center(
                  child: Container(
                    width: 300,
                    height: 400,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(150),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                child: Text(_instruction, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStepIndicator("Lurus", _isStraight),
                const SizedBox(width: 10),
                _buildStepIndicator("Kedip", _hasBlinked),
                const SizedBox(width: 10),
                _buildStepIndicator("Senyum", _hasSmiled),
              ],
            ),
          ),
          Positioned(
             top: 40,
             left: 20,
             child: IconButton(
               icon: const Icon(Icons.arrow_back, color: Colors.white),
               onPressed: () => Navigator.pop(context, null),
             )
          )
        ],
      ),
    );
  }

  Widget _buildStepIndicator(String label, bool isDone) {
    return Column(
      children: [
        Icon(isDone ? Icons.check_circle : Icons.radio_button_unchecked, color: isDone ? Colors.green : Colors.white, size: 30),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}
