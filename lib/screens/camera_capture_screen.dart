import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import '../constants/face_angles.dart';

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({
    super.key,
    required this.targetAngle,
    this.employeeName,
    this.autoCaptureAll = false,
  });

  final String targetAngle;
  final String? employeeName;
  final bool autoCaptureAll;

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableClassification: true,
    ),
  );

  CameraController? _controller;
  bool _isInitializing = true;
  bool _isProcessingFrame = false;
  bool _isCapturing = false;
  bool _isSwitchingCamera = false;
  bool _faceDetected = false;
  bool _poseMatches = false;
  int _matchingFrames = 0;
  int _sequenceIndex = 0;
  int _faceCount = 0;
  final List<String> _capturedPaths = [];
  List<CameraDescription> _cameras = const [];
  CameraDescription? _activeCamera;
  String? _errorMessage;

  static const _requiredStableFrames = 8;

  String get _currentAngle => widget.autoCaptureAll
      ? faceAngleKeys[_sequenceIndex]
      : widget.targetAngle;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera({CameraDescription? camera}) async {
    CameraController? controller;
    try {
      final permission = await Permission.camera.request();
      if (!permission.isGranted) {
        throw const _CameraSetupException(
          'ត្រូវការការអនុញ្ញាតប្រើកាមេរ៉ា។ សូមអនុញ្ញាតក្នុងការកំណត់ទូរស័ព្ទ។',
        );
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw const _CameraSetupException('រកមិនឃើញកាមេរ៉ាទេ។');
      }
      final selectedCamera =
          camera ??
          cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
            orElse: () => cameras.first,
          );
      if (mounted) {
        setState(() {
          _cameras = cameras;
          _activeCamera = selectedCamera;
        });
      }
      controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      await controller.startImageStream(_processFrame);
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _isSwitchingCamera = false;
          _errorMessage = null;
        });
      }
    } on _CameraSetupException catch (error) {
      await controller?.dispose();
      _controller = null;
      _setCameraError(error.message);
    } on Object {
      await controller?.dispose();
      _controller = null;
      _setCameraError(
        'មិនអាចបើកកាមេរ៉ាបានទេ។ សូមពិនិត្យការអនុញ្ញាតប្រើកាមេរ៉ា។',
      );
    }
  }

  Future<void> _switchCamera() async {
    if (_isSwitchingCamera || _isCapturing || _cameras.length < 2) return;
    final nextLensDirection =
        _activeCamera?.lensDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    final matchingCameras = _cameras.where(
      (camera) => camera.lensDirection == nextLensDirection,
    );
    if (matchingCameras.isEmpty) return;
    final nextCamera = matchingCameras.first;
    final controller = _controller;
    setState(() {
      _isSwitchingCamera = true;
      _isInitializing = true;
      _faceDetected = false;
      _faceCount = 0;
      _poseMatches = false;
    });
    _controller = null;
    if (controller != null) {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      await controller.dispose();
    }
    if (!mounted) return;
    await _initializeCamera(camera: nextCamera);
  }

  void _setCameraError(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
      _isInitializing = false;
    });
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_isProcessingFrame || _isCapturing || _controller == null) return;
    _isProcessingFrame = true;
    try {
      final input = _toInputImage(image);
      if (input == null) return;
      final faces = await _detector.processImage(input);
      if (!mounted) return;
      final faceDetected = faces.isNotEmpty;
      final match = faces.length == 1 && _matchesTarget(faces.single);
      _matchingFrames = match ? _matchingFrames + 1 : 0;
      if (faceDetected != _faceDetected ||
          faces.length != _faceCount ||
          match != _poseMatches) {
        setState(() {
          _faceDetected = faceDetected;
          _faceCount = faces.length;
          _poseMatches = match;
        });
      }
      if (widget.autoCaptureAll &&
          match &&
          _matchingFrames >= _requiredStableFrames &&
          !_isCapturing) {
        unawaited(_capture());
      }
    } on Object {
      _matchingFrames = 0;
      if (mounted) {
        setState(() {
          _faceDetected = false;
          _faceCount = 0;
          _poseMatches = false;
        });
      }
    } finally {
      _isProcessingFrame = false;
    }
  }

  bool _matchesTarget(Face face) {
    final yaw = face.headEulerAngleY;
    final pitch = face.headEulerAngleX;
    if (yaw == null || pitch == null) return false;

    // Starting values: tune yaw/pitch thresholds against real device samples.
    const turnThreshold = 15.0;
    const tiltThreshold = 10.0;
    final facingForward = yaw.abs() <= turnThreshold;
    final pitchNeutral = pitch.abs() <= tiltThreshold;

    return switch (_currentAngle) {
      'straight' => facingForward && pitchNeutral,
      'blink' =>
        facingForward &&
            pitchNeutral &&
            (face.leftEyeOpenProbability ?? 1) < 0.3 &&
            (face.rightEyeOpenProbability ?? 1) < 0.3,
      'left' => yaw < -turnThreshold,
      'right' => yaw > turnThreshold,
      'up' => pitch > tiltThreshold,
      'down' => pitch < -tiltThreshold,
      _ => false,
    };
  }

  InputImage? _toInputImage(CameraImage image) {
    if (image.planes.isEmpty) return null;
    final rotation = _rotationForCamera(_controller!.description);

    late final Uint8List bytes;
    late final InputImageFormat inputFormat;
    late final int bytesPerRow;
    if (Platform.isIOS) {
      if (image.format.group != ImageFormatGroup.bgra8888 ||
          image.planes.length != 1) {
        return null;
      }
      bytes = image.planes.first.bytes;
      inputFormat = InputImageFormat.bgra8888;
      bytesPerRow = image.planes.first.bytesPerRow;
    } else if (image.format.group == ImageFormatGroup.yuv420 &&
        image.planes.length == 3) {
      bytes = _yuv420ToNv21(image);
      inputFormat = InputImageFormat.nv21;
      bytesPerRow = image.width;
    } else if (image.format.group == ImageFormatGroup.nv21 &&
        image.planes.length == 1) {
      bytes = image.planes.first.bytes;
      inputFormat = InputImageFormat.nv21;
      bytesPerRow = image.width;
    } else {
      return null;
    }

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: inputFormat,
        bytesPerRow: bytesPerRow,
      ),
    );
  }

  InputImageRotation _rotationForCamera(CameraDescription camera) {
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
          InputImageRotation.rotation0deg;
    }
    const deviceOrientations = {
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };
    final deviceRotation =
        deviceOrientations[_controller!.value.deviceOrientation] ?? 0;
    final rotation = camera.lensDirection == CameraLensDirection.front
        ? (camera.sensorOrientation + deviceRotation) % 360
        : (camera.sensorOrientation - deviceRotation + 360) % 360;
    return InputImageRotationValue.fromRawValue(rotation) ??
        InputImageRotation.rotation0deg;
  }

  Uint8List _yuv420ToNv21(CameraImage image) {
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final chromaWidth = (image.width + 1) ~/ 2;
    final chromaHeight = (image.height + 1) ~/ 2;
    final ySize = image.width * image.height;
    final nv21 = Uint8List(ySize + chromaWidth * chromaHeight * 2);

    for (var row = 0; row < image.height; row++) {
      final rowStart = row * yPlane.bytesPerRow;
      nv21.setRange(
        row * image.width,
        (row + 1) * image.width,
        yPlane.bytes,
        rowStart,
      );
    }

    var offset = ySize;
    final uPixelStride = uPlane.bytesPerPixel ?? 1;
    final vPixelStride = vPlane.bytesPerPixel ?? 1;
    for (var row = 0; row < chromaHeight; row++) {
      for (var column = 0; column < chromaWidth; column++) {
        final uIndex = row * uPlane.bytesPerRow + column * uPixelStride;
        final vIndex = row * vPlane.bytesPerRow + column * vPixelStride;
        nv21[offset++] = vPlane.bytes[vIndex];
        nv21[offset++] = uPlane.bytes[uIndex];
      }
    }
    return nv21;
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !_poseMatches || _isCapturing) return;
    setState(() => _isCapturing = true);
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      final file = await controller.takePicture();
      if (!mounted) return;
      if (!widget.autoCaptureAll) {
        Navigator.of(context).pop(file.path);
        return;
      }

      _capturedPaths.add(file.path);
      if (_sequenceIndex + 1 == faceAngleKeys.length) {
        Navigator.of(context).pop(List<String>.of(_capturedPaths));
        return;
      }

      setState(() {
        _sequenceIndex++;
        _matchingFrames = 0;
        _faceDetected = false;
        _faceCount = 0;
        _poseMatches = false;
        _isCapturing = false;
      });
      await controller.startImageStream(_processFrame);
    } on Object catch (error, stackTrace) {
      debugPrint('Camera capture failed: $error\n$stackTrace');
      if (mounted) {
        final controller = _controller;
        if (controller != null &&
            controller.value.isInitialized &&
            !controller.value.isStreamingImages) {
          try {
            await controller.startImageStream(_processFrame);
          } on Object catch (restartError, restartStackTrace) {
            debugPrint(
              'Could not restart camera stream: '
              '$restartError\n$restartStackTrace',
            );
          }
        }
        if (!mounted) return;
        setState(() {
          _isCapturing = false;
          _matchingFrames = 0;
          _poseMatches = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('មិនអាចថតរូបនេះបានទេ។ សូមព្យាយាមម្ដងទៀត។'),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) {
      if (controller.value.isStreamingImages) {
        unawaited(controller.stopImageStream());
      }
      unawaited(controller.dispose());
    }
    unawaited(_detector.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final label = faceAngleLabelsKm[_currentAngle] ?? _currentAngle;
    final angleIndex = faceAngleKeys.indexOf(_currentAngle);
    final step = angleIndex < 0 ? 1 : angleIndex + 1;
    final status = _faceCount > 1
        ? 'សូមឲ្យមានមនុស្សម្នាក់ប៉ុណ្ណោះក្នុងស៊ុមកាមេរ៉ា។'
        : !_faceDetected
        ? 'រកមិនឃើញមុខទេ។ សូមចូលមកជិត និងរកកន្លែងដែលមានពន្លឺល្អ។'
        : _poseMatches
        ? widget.autoCaptureAll
              ? 'ល្អណាស់! សូមនៅស្ងៀម កំពុងថតរូប...'
              : 'សូមនៅស្ងៀមដើម្បីថតរូប។'
        : 'សូមកែសម្រួលក្បាល៖ $label';
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.employeeName?.isNotEmpty == true
              ? widget.employeeName!
              : label,
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          if (_cameras.length > 1)
            IconButton(
              tooltip: 'ប្ដូរកាមេរ៉ា',
              onPressed: _isSwitchingCamera ? null : _switchCamera,
              icon: const Icon(Icons.autorenew_rounded),
            ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_isInitializing)
            const Center(child: CircularProgressIndicator())
          else if (_errorMessage case final message?)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            )
          else if (controller != null && controller.value.isInitialized)
            _buildCameraPreview(controller),
          if (!_isInitializing && _errorMessage == null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _FaceGuidePainter(
                    color: _poseMatches
                        ? const Color(0xFF55D6A4)
                        : const Color(0xFFFF5364),
                  ),
                ),
              ),
            ),
          if (!_isInitializing && _errorMessage == null)
            Positioned(
              top: 12,
              left: 24,
              right: 24,
              child: SafeArea(
                bottom: false,
                child: Text(
                  status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                  ),
                ),
              ),
            ),
          if (!_isInitializing && _errorMessage == null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  decoration: const BoxDecoration(
                    color: Color(0xF20D1019),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          for (
                            var index = 0;
                            index < faceAngleKeys.length;
                            index++
                          )
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: index == faceAngleKeys.length - 1
                                      ? 0
                                      : 8,
                                ),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: index < step - 1
                                        ? const Color(0xFF55D6A4)
                                        : index == step - 1 && _poseMatches
                                        ? const Color(0xFF55D6A4)
                                        : const Color(0xFF3B3E49),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'ជំហាន $step ក្នុង ${faceAngleKeys.length} · $label',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed:
                              widget.autoCaptureAll ||
                                  !_poseMatches ||
                                  _isCapturing
                              ? null
                              : _capture,
                          icon: _isCapturing
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.camera_alt_outlined),
                          label: Text(
                            _isCapturing
                                ? 'កំពុងថត...'
                                : widget.autoCaptureAll
                                ? _poseMatches
                                      ? 'កំពុងថតដោយស្វ័យប្រវត្តិ...'
                                      : 'កែទីតាំងមុខ ដើម្បីថតដោយស្វ័យប្រវត្តិ'
                                : 'នៅស្ងៀមដើម្បីថតរូប',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview(CameraController controller) {
    return Center(child: CameraPreview(controller));
  }
}

class _FaceGuidePainter extends CustomPainter {
  const _FaceGuidePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final guide = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.46),
      width: size.width * 0.74,
      height: size.height * 0.47,
    );
    final overlay = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(guide);
    canvas.drawPath(
      overlay,
      Paint()..color = Colors.black.withValues(alpha: 0.48),
    );
    canvas.drawOval(
      guide,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );
  }

  @override
  bool shouldRepaint(_FaceGuidePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _CameraSetupException implements Exception {
  const _CameraSetupException(this.message);

  final String message;
}
