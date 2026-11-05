import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'face_photo_normalizer.dart';

enum FaceEnrollmentStep {
  front('សូមមើលត្រង់ទៅកាមេរ៉ា'),
  blink('សូមព្រិចភ្នែក រួចបើកភ្នែកវិញ'),
  lookUp('សូមងើបមុខចុះ'),
  lookDown('សូមងើបមុខឡើង'),
  turnRight('សូមបង្វែរមុខទៅស្តាំ'),
  turnLeft('សូមបង្វែរមុខទៅឆ្វេង');

  const FaceEnrollmentStep(this.instruction);

  final String instruction;

  int get number => index + 1;
  static const total = 6;

  FaceEnrollmentStep? get next =>
      index + 1 == values.length ? null : values[index + 1];
}

/// Immutable snapshot of the current validation state, driven by the
/// detection pipeline and consumed by the UI overlay.
class FaceValidationState {
  final FaceEnrollmentStep step;
  final bool faceDetected;
  final bool inBounds;
  final bool faceLargeEnough;
  final bool lookingStraight;
  final bool eyesOpen;
  final bool eyesClassified;
  final bool blinkCompleted;
  final bool tiltDetected;
  final bool tiltDirectionMatches;
  final bool turnDetected;
  final bool turnDirectionMatches;
  final bool stable;
  final bool cameraFrameReceived;
  final double progress;
  final String? errorMessage;

  const FaceValidationState({
    this.step = FaceEnrollmentStep.front,
    this.faceDetected = false,
    this.inBounds = false,
    this.faceLargeEnough = false,
    this.lookingStraight = false,
    this.eyesOpen = false,
    this.eyesClassified = false,
    this.blinkCompleted = false,
    this.tiltDetected = false,
    this.tiltDirectionMatches = false,
    this.turnDetected = false,
    this.turnDirectionMatches = false,
    this.stable = false,
    this.cameraFrameReceived = false,
    this.progress = 0.0,
    this.errorMessage,
  });

  bool get isValid => faceDetected && inBounds && stable;
}

class FaceEnrollmentController extends ChangeNotifier {
  FaceEnrollmentController({
    required this.controller,
    required this.overlayRect,
    FaceEnrollmentStep initialStep = FaceEnrollmentStep.front,
    this.requiredStableFrames = 10,
    this.eulerToleranceDegrees = 12.0,
    this.minFaceSize = 0.14,
  }) : _step = initialStep,
       _state = FaceValidationState(step: initialStep),
       _detector = FaceDetector(
         options: FaceDetectorOptions(
           enableContours: false,
           enableLandmarks: true,
           enableClassification: true,
           enableTracking: true,
           performanceMode: FaceDetectorMode.accurate,
         ),
       );

  final CameraController controller;

  /// Visual screen rect (in widget coordinates) that the face must fit inside.
  final Rect overlayRect;

  final int requiredStableFrames;
  final double eulerToleranceDegrees;
  final double minFaceSize;

  final FaceDetector _detector;

  bool _isStreaming = false;
  bool _isProcessing = false;
  bool _disposed = false;
  bool _waitingForCapture = false;
  int _stableCount = 0;
  bool _eyesWereOpen = false;
  bool _eyesWereClosed = false;
  bool _blinkCompleted = false;
  FaceEnrollmentStep _step;

  FaceValidationState _state;
  FaceValidationState get state => _state;

  final _milestoneController = StreamController<FaceEnrollmentStep>.broadcast();
  Stream<FaceEnrollmentStep> get milestones => _milestoneController.stream;

  Future<void> start() async {
    if (_waitingForCapture ||
        _isStreaming ||
        controller.value.isStreamingImages) {
      return;
    }
    _isStreaming = true;
    try {
      await controller.startImageStream(_onFrame);
    } catch (error) {
      _isStreaming = false;
      _updateState(
        FaceValidationState(
          step: _step,
          errorMessage: 'Could not start camera detection: $error',
        ),
      );
      rethrow;
    }
  }

  Future<void> stop() async {
    _isStreaming = false;
    if (controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
  }

  void advanceAfterCapture() {
    final next = _step.next;
    if (next == null) return;
    _step = next;
    _stableCount = 0;
    _eyesWereOpen = false;
    _eyesWereClosed = false;
    _blinkCompleted = false;
    _waitingForCapture = false;
    _updateState(FaceValidationState(step: _step));
  }

  void retryCapture() {
    _stableCount = 0;
    _waitingForCapture = false;
    _updateState(FaceValidationState(step: _step));
  }

  /// Runs the entire detect -> validate pipeline off the UI isolate path.
  /// `startImageStream` already delivers frames on a background isolate, and
  /// ML Kit runs natively, so we only guard against concurrent invocations
  /// and avoid any synchronous heavy work on the UI thread.
  Future<void> _onFrame(CameraImage image) async {
    if (_isProcessing || _disposed || _waitingForCapture) return;
    _isProcessing = true;

    try {
      final inputImage = await _toInputImage(image);
      if (inputImage == null) {
        _updateState(
          FaceValidationState(
            step: _step,
            errorMessage:
                'Unsupported camera image format: '
                '${image.format.group}',
          ),
        );
        return;
      }

      final faces = await _detector.processImage(inputImage);
      if (_disposed) return;

      if (faces.isEmpty) {
        _updateState(
          FaceValidationState(step: _step, cameraFrameReceived: true),
        );
        _stableCount = 0;
        return;
      }

      final face = faces.first;
      final validation = _validate(face, inputImage);

      if (validation.isValid) {
        _stableCount++;
      } else {
        _stableCount = 0;
      }

      final progress = (_stableCount / requiredStableFrames)
          .clamp(0.0, 1.0)
          .toDouble();

      final newState = FaceValidationState(
        step: _step,
        faceDetected: true,
        inBounds: validation.inBounds,
        faceLargeEnough: validation.faceLargeEnough,
        lookingStraight: validation.lookingStraight,
        eyesOpen: validation.eyesOpen,
        eyesClassified: validation.eyesClassified,
        blinkCompleted: _blinkCompleted,
        tiltDetected: validation.tiltDetected,
        tiltDirectionMatches: validation.tiltDirectionMatches,
        turnDetected: validation.turnDetected,
        turnDirectionMatches: validation.turnDirectionMatches,
        stable: progress >= 1.0,
        cameraFrameReceived: true,
        progress: progress,
      );
      _updateState(newState);

      if (newState.isValid && !_milestoneController.isClosed) {
        _waitingForCapture = true;
        _milestoneController.add(_step);
        _stableCount = 0;
      }
    } catch (e, st) {
      debugPrint('FaceEnrollmentController error: $e\n$st');
      _updateState(FaceValidationState(step: _step, errorMessage: '$e'));
    } finally {
      _isProcessing = false;
    }
  }

  _Validation _validate(Face face, InputImage inputImage) {
    final eulerX = face.headEulerAngleX ?? 0;
    final eulerY = face.headEulerAngleY ?? 0;
    final eulerZ = face.headEulerAngleZ ?? 0;

    final lookingStraight =
        eulerY.abs() <= eulerToleranceDegrees &&
        eulerZ.abs() <= eulerToleranceDegrees;
    final rollIsValid = eulerZ.abs() <= eulerToleranceDegrees;

    final imageSize = inputImage.metadata!.size;
    final box = face.boundingBox;
    final faceCenterX = (box.left + box.width / 2) / imageSize.width;
    final faceCenterY = (box.top + box.height / 2) / imageSize.height;
    final inBounds =
        (faceCenterX - 0.5).abs() <= 0.34 && (faceCenterY - 0.5).abs() <= 0.34;

    final faceFrac = box.width / imageSize.width;
    final largeEnough = faceFrac >= minFaceSize;
    final leftEyeOpen = face.leftEyeOpenProbability;
    final rightEyeOpen = face.rightEyeOpenProbability;
    final eyesOpen =
        leftEyeOpen != null &&
        rightEyeOpen != null &&
        leftEyeOpen >= 0.55 &&
        rightEyeOpen >= 0.55;
    final eyesClassified = leftEyeOpen != null && rightEyeOpen != null;
    final eyesClosed =
        leftEyeOpen != null &&
        rightEyeOpen != null &&
        leftEyeOpen <= 0.25 &&
        rightEyeOpen <= 0.25;
    if (_step == FaceEnrollmentStep.blink && inBounds && lookingStraight) {
      if (eyesOpen) {
        if (_eyesWereClosed) _blinkCompleted = true;
        _eyesWereOpen = true;
      } else if (eyesClosed && _eyesWereOpen) {
        _eyesWereClosed = true;
      }
    }

    final minTurnDegrees = eulerToleranceDegrees + 8;
    final maxTurnDegrees = eulerToleranceDegrees + 35;
    final hasTilt =
        eulerX.abs() >= minTurnDegrees && eulerX.abs() <= maxTurnDegrees;
    final hasTurned =
        eulerY.abs() >= minTurnDegrees && eulerY.abs() <= maxTurnDegrees;
    final lookingUp = eulerX < 0;
    final lookingRight = eulerY > 0;
    final tiltDirectionMatches = switch (_step) {
      FaceEnrollmentStep.lookUp => lookingUp,
      FaceEnrollmentStep.lookDown => !lookingUp,
      _ => true,
    };
    final turnDirectionMatches = switch (_step) {
      FaceEnrollmentStep.turnRight => lookingRight,
      FaceEnrollmentStep.turnLeft => !lookingRight,
      _ => true,
    };
    final stepIsValid = switch (_step) {
      FaceEnrollmentStep.front => lookingStraight,
      FaceEnrollmentStep.blink =>
        lookingStraight && eyesOpen && _blinkCompleted,
      FaceEnrollmentStep.lookUp => hasTilt && eulerX < 0 && rollIsValid,
      FaceEnrollmentStep.lookDown => hasTilt && eulerX > 0 && rollIsValid,
      FaceEnrollmentStep.turnRight => hasTurned && eulerY > 0 && rollIsValid,
      FaceEnrollmentStep.turnLeft => hasTurned && eulerY < 0 && rollIsValid,
    };

    return _Validation(
      inBounds: inBounds,
      faceLargeEnough: largeEnough,
      lookingStraight: lookingStraight,
      eyesOpen: eyesOpen,
      eyesClassified: eyesClassified,
      tiltDetected: hasTilt,
      tiltDirectionMatches: tiltDirectionMatches,
      turnDetected: hasTurned,
      turnDirectionMatches: turnDirectionMatches,
      isValid: inBounds && largeEnough && stepIsValid,
    );
  }

  Future<InputImage?> _toInputImage(CameraImage image) async {
    final camera = controller.description;
    final rotation = _rotationDegreesForCamera(camera);
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null || image.planes.isEmpty) return null;

    final Uint8List bytes;
    final InputImageFormat inputFormat;
    final int bytesPerRow;
    if (Platform.isIOS) {
      if (image.format.group != ImageFormatGroup.bgra8888 ||
          image.planes.length != 1) {
        throw StateError(
          'iPhone camera must provide one BGRA image plane; received '
          '${image.format.group} with ${image.planes.length} planes.',
        );
      }
      bytes = image.planes.first.bytes;
      inputFormat = InputImageFormat.bgra8888;
      bytesPerRow = image.planes.first.bytesPerRow;
    } else {
      if (image.format.group != ImageFormatGroup.yuv420 ||
          image.planes.length != 3) {
        throw StateError(
          'Android camera must provide three YUV420 image planes; received '
          '${image.format.group} with ${image.planes.length} planes.',
        );
      }
      bytes = _yuv420ToNv21(image);
      inputFormat = InputImageFormat.nv21;
      bytesPerRow = image.width;
    }

    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: inputFormat,
      bytesPerRow: bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  InputImageRotation _rotationDegreesForCamera(CameraDescription camera) {
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
          InputImageRotation.rotation0deg;
    }

    const orientations = {
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };
    final deviceRotation = orientations[controller.value.deviceOrientation];
    if (deviceRotation == null) return InputImageRotation.rotation0deg;

    final rotation = camera.lensDirection == CameraLensDirection.front
        ? (camera.sensorOrientation + deviceRotation) % 360
        : (camera.sensorOrientation - deviceRotation + 360) % 360;
    return InputImageRotationValue.fromRawValue(rotation) ??
        InputImageRotation.rotation0deg;
  }

  /// Converts a CameraImage (YUV420, as delivered by Flutter's camera plugin)
  /// into an NV21 byte buffer compatible with ML Kit.
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

  void _updateState(FaceValidationState next) {
    _state = next;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (controller.value.isStreamingImages) {
      unawaited(controller.stopImageStream());
    }
    _milestoneController.close();
    _detector.close();
    super.dispose();
  }
}

class _Validation {
  final bool inBounds;
  final bool faceLargeEnough;
  final bool lookingStraight;
  final bool eyesOpen;
  final bool eyesClassified;
  final bool tiltDetected;
  final bool tiltDirectionMatches;
  final bool turnDetected;
  final bool turnDirectionMatches;
  final bool isValid;

  const _Validation({
    required this.inBounds,
    required this.faceLargeEnough,
    required this.lookingStraight,
    required this.eyesOpen,
    required this.eyesClassified,
    required this.tiltDetected,
    required this.tiltDirectionMatches,
    required this.turnDetected,
    required this.turnDirectionMatches,
    required this.isValid,
  });
}

/// Widget that draws the live camera preview plus a color-coded oval mask.
/// The oval turns green once the face passes all validation checks.
class FaceEnrollmentWidget extends StatefulWidget {
  const FaceEnrollmentWidget({
    super.key,
    required this.controller,
    this.initialStep = FaceEnrollmentStep.front,
    required this.onCaptured,
    required this.onCompleted,
    this.onError,
  });

  final CameraController controller;
  final FaceEnrollmentStep initialStep;
  final Future<void> Function(XFile image, FaceEnrollmentStep step) onCaptured;
  final VoidCallback onCompleted;
  final void Function(Object error)? onError;

  @override
  State<FaceEnrollmentWidget> createState() => _FaceEnrollmentWidgetState();
}

class _FaceEnrollmentWidgetState extends State<FaceEnrollmentWidget> {
  FaceEnrollmentController? _enroller;
  StreamSubscription<FaceEnrollmentStep>? _resultSub;
  bool _initializationScheduled = false;
  bool _captureStarted = false;

  Rect _computeOverlayRect(Size size) {
    final ovalW = math.min(size.width * 0.72, size.height / 1.3);
    final ovalH = ovalW * 1.3;
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: ovalW,
      height: ovalH,
    );
  }

  void _initEnroller(Rect overlayRect) {
    final enroller = FaceEnrollmentController(
      controller: widget.controller,
      overlayRect: overlayRect,
      initialStep: widget.initialStep,
    );
    _enroller = enroller;
    _resultSub = enroller.milestones.listen(
      (step) => unawaited(_captureFace(step)),
      onError: (e) => widget.onError?.call(e),
    );
    enroller.start().catchError((e) {
      widget.onError?.call(e);
    });
  }

  Future<void> _captureFace(FaceEnrollmentStep step) async {
    if (_captureStarted || !mounted) return;
    _captureStarted = true;
    XFile? photo;
    XFile? normalizedPhoto;
    try {
      await _enroller?.stop();
      photo = await widget.controller.takePicture();
      normalizedPhoto = XFile(await normalizeFacePhoto(photo.path));
      await _deleteTemporaryPhoto(photo.path);
      if (!mounted) return;
      await widget.onCaptured(normalizedPhoto, step);
      if (!mounted) return;
      if (step.next == null) {
        await _deleteTemporaryPhoto(normalizedPhoto.path);
        widget.onCompleted();
        return;
      }
      _enroller?.advanceAfterCapture();
      _captureStarted = false;
      await _enroller?.start();
    } catch (error) {
      if (photo != null) {
        await _deleteTemporaryPhoto(photo.path);
      }
      if (normalizedPhoto != null) {
        await _deleteTemporaryPhoto(normalizedPhoto.path);
      }
      if (!mounted) return;
      widget.onError?.call(error);
      _captureStarted = false;
    }
  }

  Future<void> _deleteTemporaryPhoto(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  @override
  void dispose() {
    _resultSub?.cancel();
    _enroller?.dispose();
    super.dispose();
  }

  // Only returns a message if something is wrong (no face, out of bounds, etc.)
  String? _feedbackFor(FaceValidationState state) {
    if (state.errorMessage != null) return state.errorMessage!;
    if (!state.faceDetected) {
      return state.cameraFrameReceived
          ? 'រកមិនឃើញមុខទេ។ សូមចូលជិត និងស្ថិតនៅកន្លែងមានពន្លឺគ្រប់គ្រាន់។'
          : 'កំពុងចាប់ផ្តើមកាមេរ៉ា...';
    }
    if (!state.inBounds) return 'សូមដាក់មុខនៅកណ្ដាលរង្វង់។';
    if (!state.faceLargeEnough) return 'សូមចូលជិតកាមេរ៉ាបន្តិច។';

    // If the face is detected, in bounds, and large enough, return null
    // so the UI knows to hide the status message.
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final enroller = _enroller;
        if (enroller == null) {
          if (!_initializationScheduled) {
            _initializationScheduled = true;
            final overlayRect = _computeOverlayRect(constraints.biggest);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || _enroller != null) return;
              _initEnroller(overlayRect);
              setState(() {});
            });
          }
          return const SizedBox.expand();
        }

        return AnimatedBuilder(
          animation: enroller,
          builder: (context, _) {
            final state = enroller.state;
            final ovalColor = state.isValid
                ? Colors.greenAccent
                : state.faceDetected && state.inBounds
                ? Colors.amberAccent
                : Colors.redAccent;
            
            // Get the status message (null if everything is perfect)
            final feedback = _feedbackFor(state);

            return Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(widget.controller),
                
                // Centered White Name at the top
                Positioned(
                  top: 60,
                  left: 0,
                  right: 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Main Instruction Name
                      Text(
                        state.step.instruction,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 2),
                              blurRadius: 4.0,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                      ),
                      // Message only shows if there is an issue
                      if (feedback != null) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            feedback,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: state.errorMessage != null
                                  ? Colors.redAccent
                                  : Colors.white.withOpacity(0.9),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              shadows: const [
                                Shadow(
                                  offset: Offset(0, 1),
                                  blurRadius: 3.0,
                                  color: Colors.black54,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Cleaner Bottom Progress Bar
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.only(top: 40, bottom: 50, left: 32, right: 32),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.9),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: state.progress,
                            minHeight: 6,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(ovalColor),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'សូមនៅស្ងៀម ដើម្បីថតរូប',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // The Oval Mask
                IgnorePointer(
                  child: CustomPaint(
                    painter: _OvalMaskPainter(
                      rect: enroller.overlayRect,
                      color: ovalColor,
                      progress: state.progress,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _OvalMaskPainter extends CustomPainter {
  final Rect rect;
  final Color color;
  final double progress;

  _OvalMaskPainter({
    required this.rect,
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Dim the background outside the oval
    final dim = Paint()..color = Colors.black.withOpacity(0.6);
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addOval(rect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, dim);

    // Thinner, more elegant oval stroke
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = color;
    canvas.drawOval(rect, stroke);

    // Cleaner progress arc around the oval
    if (progress > 0 && progress < 1) {
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = color
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        rect.inflate(4),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        arc,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OvalMaskPainter old) =>
      old.color != color || old.progress != progress || old.rect != rect;
}