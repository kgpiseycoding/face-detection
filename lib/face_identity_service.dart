import 'dart:io';
import 'dart:math';

import 'package:face_verification/face_verification.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'face_store.dart';

const faceMatchThreshold = 0.70;

abstract interface class FaceIdentityService {
  Future<void> prepare(List<RegisteredUser> users);
  String createEnrollmentSession();
  Future<void> addEnrollmentSample({
    required String sessionId,
    required RegisteredUser user,
    required String imagePath,
    required int sampleIndex,
  });
  Future<void> completeEnrollment({
    required String sessionId,
    required RegisteredUser user,
  });
  Future<void> cancelEnrollment(String sessionId);
  Future<String?> recognizeImage(String imagePath);
}

class LocalFaceIdentityService implements FaceIdentityService {
  LocalFaceIdentityService()
    : _detector = FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate,
          enableTracking: false,
        ),
      );

  final FaceDetector _detector;
  final Random _random = Random.secure();

  bool _isInitialized = false;

  Future<void> _initialize() async {
    if (_isInitialized) return;
    await FaceVerification.instance.init(numThreads: 2);
    _isInitialized = true;
  }

  @override
  Future<void> prepare(List<RegisteredUser> users) async {
    await _initialize();

    final usersById = {for (final user in users) user.id: user};
    final registeredIds = await FaceVerification.instance
        .getAllRegisteredUsers();
    for (final id in registeredIds) {
      if (id.startsWith('pending:') || !usersById.containsKey(id)) {
        await FaceVerification.instance.deleteUserFaces(id);
      }
    }

    for (final user in users) {
      if (user.faceImagePaths.length != 4 && user.faceImagePaths.length != 6) {
        await FaceVerification.instance.deleteUserFaces(user.id);
        continue;
      }

      final expectedImageIds = [
        for (var index = 0; index < user.faceImagePaths.length; index++)
          _storedImageId(index, user.faceImagePaths[index]),
      ];
      var isSynchronized = true;
      for (final imageId in expectedImageIds) {
        if (!await FaceVerification.instance.isFaceRegisteredWithImageId(
          user.id,
          imageId,
        )) {
          isSynchronized = false;
          break;
        }
      }
      if (isSynchronized) continue;

      await FaceVerification.instance.deleteUserFaces(user.id);
      for (var index = 0; index < user.faceImagePaths.length; index++) {
        await _registerSample(
          id: user.id,
          imageId: _storedImageId(index, user.faceImagePaths[index]),
          imagePath: user.faceImagePaths[index],
          name: user.name,
        );
      }
    }
  }

  @override
  String createEnrollmentSession() {
    final nonce = List<int>.generate(
      16,
      (_) => _random.nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return 'pending:$nonce';
  }

  @override
  Future<void> addEnrollmentSample({
    required String sessionId,
    required RegisteredUser user,
    required String imagePath,
    required int sampleIndex,
  }) async {
    await _initialize();
    await _requireOneFace(
      imagePath,
      noFaceMessage:
          'The live camera saw your face, but the saved photo did not pass '
          'the face check. Hold still and try this step again.',
    );
    final imageId = 'pose-$sampleIndex';

    if (sampleIndex == 0) {
      await FaceVerification.instance.deleteUserFaces(sessionId);
    } else {
      await FaceVerification.instance.deleteFaceRecord(sessionId, imageId);
      final matchId = await FaceVerification.instance.verifyFromImagePath(
        imagePath: imagePath,
        threshold: faceMatchThreshold,
        staffId: sessionId,
      );
      if (matchId != sessionId) {
        throw StateError(
          'These face samples do not match. Use the same person for all six '
          'photos, then try again.',
        );
      }
    }

    await _registerSample(
      id: sessionId,
      imageId: imageId,
      imagePath: imagePath,
      name: user.name,
    );
  }

  @override
  Future<void> completeEnrollment({
    required String sessionId,
    required RegisteredUser user,
  }) async {
    await _initialize();
    if (user.faceImagePaths.length != 6) {
      throw StateError('Exactly six face photos are required.');
    }

    await FaceVerification.instance.deleteUserFaces(user.id);
    for (var index = 0; index < user.faceImagePaths.length; index++) {
      await _registerSample(
        id: user.id,
        imageId: _storedImageId(index, user.faceImagePaths[index]),
        imagePath: user.faceImagePaths[index],
        name: user.name,
      );
    }
    await FaceVerification.instance.deleteUserFaces(sessionId);
  }

  @override
  Future<void> cancelEnrollment(String sessionId) async {
    if (!_isInitialized) return;
    await _initialize();
    await FaceVerification.instance.deleteUserFaces(sessionId);
  }

  @override
  Future<String?> recognizeImage(String imagePath) async {
    await _initialize();
    await _requireOneFace(
      imagePath,
      noFaceMessage: 'No face was detected. Center one face in the camera.',
    );
    return FaceVerification.instance.verifyFromImagePath(
      imagePath: imagePath,
      threshold: faceMatchThreshold,
    );
  }

  Future<void> _registerSample({
    required String id,
    required String imageId,
    required String imagePath,
    required String name,
  }) async {
    if (!await File(imagePath).exists()) {
      throw FileSystemException('Face photo is missing', imagePath);
    }
    await FaceVerification.instance.registerFromImagePath(
      id: id,
      imagePath: imagePath,
      imageId: imageId,
      name: name,
    );
  }

  String _storedImageId(int index, String imagePath) {
    final fileName = Uri.file(imagePath).pathSegments.last;
    return 'pose-$index-$fileName';
  }

  Future<void> _requireOneFace(
    String imagePath, {
    required String noFaceMessage,
  }) async {
    if (!await File(imagePath).exists()) {
      throw FileSystemException('Face photo is missing', imagePath);
    }
    final faces = await _detector.processImage(
      InputImage.fromFilePath(imagePath),
    );
    if (faces.isEmpty) {
      throw StateError(noFaceMessage);
    }
    if (faces.length != 1) {
      throw StateError(
        'More than one face was detected. Only one person can be checked at a time.',
      );
    }
  }
}
