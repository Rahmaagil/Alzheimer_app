import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'face_recognition_service.dart';

class FaceCameraScreen extends StatefulWidget {
  final bool isRegistrationMode;

  const FaceCameraScreen({
    super.key,
    this.isRegistrationMode = false,
  });

  @override
  State<FaceCameraScreen> createState() => _FaceCameraScreenState();
}

class _FaceCameraScreenState extends State<FaceCameraScreen> {
  CameraController? _controller;
  late FaceDetector _faceDetector;

  bool _isDetecting = false;
  bool _faceDetected = false;
  bool _isProcessing = false;

  Face? _detectedFace;
  CameraImage? _lastImage;

  @override
  void initState() {
    super.initState();
    _initializeFaceDetection();
    FaceRecognitionService.initialize();
    _initializeCamera();
  }

  void _initializeFaceDetection() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableContours: true,
        enableClassification: true,
      ),
    );
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Aucune camera trouvee sur cet appareil"),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      CameraDescription? frontCamera;
      try {
        frontCamera = cameras.firstWhere(
              (camera) => camera.lensDirection == CameraLensDirection.front,
        );
      } catch (e) {
        frontCamera = cameras.first;
      }

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      await Future.delayed(const Duration(milliseconds: 500));

      await _controller!.startImageStream((CameraImage image) async {
        if (_isDetecting || _isProcessing) return;

        _isDetecting = true;

        try {
          _lastImage = image;

          final inputImage = _convertCameraImage(image);

          if (inputImage != null) {
            final faces = await _faceDetector.processImage(inputImage);

            if (mounted) {
              setState(() {
                _faceDetected = faces.isNotEmpty;
                _detectedFace = faces.isNotEmpty ? faces.first : null;
              });
            }
          }
        } catch (e) {
          // Erreur silencieuse
        } finally {
          _isDetecting = false;
        }
      });

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur camera: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  InputImage? _convertCameraImage(CameraImage image) {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }

      final bytes = allBytes.done().buffer.asUint8List();

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation270deg,
          format: InputImageFormat.yuv420,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  img.Image? _convertToImgImage(CameraImage image) {
    try {
      final width = image.width;
      final height = image.height;
      final imgImage = img.Image(width, height);

      final yPlane = image.planes[0].bytes;
      final uPlane = image.planes[1].bytes;
      final vPlane = image.planes[2].bytes;

      final uvRowStride = image.planes[1].bytesPerRow;
      final uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final yIndex = y * width + x;
          final uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;

          final yValue = yPlane[yIndex];
          final uValue = uPlane[uvIndex];
          final vValue = vPlane[uvIndex];

          final r = (yValue + 1.402 * (vValue - 128)).round().clamp(0, 255);
          final g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128))
              .round()
              .clamp(0, 255);
          final b = (yValue + 1.772 * (uValue - 128)).round().clamp(0, 255);

          imgImage.setPixelRgba(x, y, r, g, b, 255);
        }
      }

      return imgImage;
    } catch (e) {
      return null;
    }
  }

  Future<void> _captureFace() async {
    if (_isProcessing) return;

    if (_lastImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Aucune image capturee. Reessayez."),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final fullImage = _convertToImgImage(_lastImage!);
      if (fullImage == null) {
        _showError("Erreur de conversion d'image");
        setState(() => _isProcessing = false);
        return;
      }

      img.Image faceImage;

      if (_detectedFace != null) {
        final box = _detectedFace!.boundingBox;
        final x = box.left.toInt().clamp(0, fullImage.width - 1);
        final y = box.top.toInt().clamp(0, fullImage.height - 1);
        final w = box.width.toInt().clamp(1, fullImage.width - x);
        final h = box.height.toInt().clamp(1, fullImage.height - y);

        faceImage = img.copyCrop(fullImage, x, y, w, h);
      } else {
        faceImage = fullImage;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Visage non detecte. Traitement en cours..."),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.orange,
          ),
        );
      }

      final embedding = FaceRecognitionService.extractEmbedding(faceImage);

      if (embedding == null) {
        _showError("Impossible d'extraire les caracteristiques du visage");
        setState(() => _isProcessing = false);
        return;
      }

      if (widget.isRegistrationMode) {
        await _showNameDialog(embedding);
      } else {
        final result = await FaceRecognitionService.recognizeFace(embedding);

        if (result != null) {
          _showRecognitionResult(result);
        } else {
          _showError("Visage inconnu");
        }
      }
    } catch (e) {
      _showError("Erreur: $e");
    }

    setState(() => _isProcessing = false);
  }

  Future<void> _showNameDialog(List<double> embedding) async {
    final nameController = TextEditingController();
    final relationController = TextEditingController();
    final phoneController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Enregistrer ce visage"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Nom du proche",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: relationController,
                decoration: const InputDecoration(
                  labelText: "Relation",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.family_restroom),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: "Telephone",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                return;
              }

              final success = await FaceRecognitionService.saveFace(
                name: nameController.text.trim(),
                embedding: embedding,
                relation: relationController.text.trim(),
                phoneNumber: phoneController.text.trim(),
              );

              Navigator.pop(ctx, success);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
            ),
            child: const Text("Enregistrer",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Visage enregistre"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  void _showRecognitionResult(Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Reconnu !"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result['name'],
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E5AAC),
              ),
            ),
            if (result['relation'].toString().isNotEmpty)
              Text(result['relation']),
            if (result['phoneNumber'].toString().isNotEmpty)
              Text(result['phoneNumber']),
            Text("Confiance: ${(result['similarity'] * 100).toInt()}%"),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: CameraPreview(_controller!)),

          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: _faceDetected
                      ? Colors.green.withOpacity(0.9)
                      : Colors.orange.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _faceDetected ? Icons.check_circle : Icons.warning,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _faceDetected
                          ? "Visage detecte - Cliquez pour capturer"
                          : "Positionnez votre visage",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: !_isProcessing ? _captureFace : null,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: !_isProcessing
                        ? const Color(0xFF4A90E2)
                        : Colors.grey,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: _isProcessing
                      ? const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  )
                      : Icon(
                    widget.isRegistrationMode
                        ? Icons.person_add
                        : Icons.face,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}