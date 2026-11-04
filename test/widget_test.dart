import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:face_detection/face_store.dart';
import 'package:face_detection/face_enrollment.dart';
import 'package:face_detection/face_identity_service.dart';
import 'package:face_detection/face_photo_normalizer.dart';
import 'package:face_detection/main.dart';

void main() {
  test('captured photos are rotated upright before face validation', () async {
    final directory = await Directory.systemTemp.createTemp('face-photo-test');
    final source = File('${directory.path}/capture.jpg');
    final rotated = img.Image(width: 8, height: 4)
      ..exif.imageIfd.orientation = 6;
    await source.writeAsBytes(img.encodeJpg(rotated));

    final normalizedPath = await normalizeFacePhoto(source.path);
    final normalized = img.decodeImage(
      await File(normalizedPath).readAsBytes(),
    );

    expect(normalized, isNotNull);
    expect(normalized!.width, 4);
    expect(normalized.height, 8);
    expect(normalized.exif.imageIfd.hasOrientation, isFalse);

    await directory.delete(recursive: true);
  });

  test('enrollment steps cover the requested face actions', () {
    expect(FaceEnrollmentStep.total, 6);
    expect(
      const FaceValidationState().cameraFrameReceived,
      isFalse,
      reason: 'The scanner must distinguish startup from a completed scan.',
    );
    expect(FaceEnrollmentStep.front.next, FaceEnrollmentStep.blink);
    expect(FaceEnrollmentStep.blink.next, FaceEnrollmentStep.lookUp);
    expect(FaceEnrollmentStep.lookUp.next, FaceEnrollmentStep.lookDown);
    expect(FaceEnrollmentStep.lookDown.next, FaceEnrollmentStep.turnRight);
    expect(FaceEnrollmentStep.turnRight.next, FaceEnrollmentStep.turnLeft);
    expect(FaceEnrollmentStep.turnLeft.next, isNull);
  });

  testWidgets('app loads users from the local store', (tester) async {
    final store = _FakeFaceStore();
    await tester.pumpWidget(
      MyApp(store: store, identityService: _FakeFaceIdentityService()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Users'), findsOneWidget);
    expect(find.text('No users yet'), findsOneWidget);
    expect(find.text('Face Enrollment'), findsNothing);
    expect(find.byTooltip('About face recognition'), findsOneWidget);
    expect(find.byTooltip('Verify a face'), findsOneWidget);
  });

  testWidgets('a user is saved to the local store', (tester) async {
    final store = _FakeFaceStore();
    await tester.pumpWidget(
      MyApp(store: store, identityService: _FakeFaceIdentityService()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add user').first);
    await tester.pumpAndSettle();
    expect(find.text('6 face photos required'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('user-name-field')),
      'Alex Morgan',
    );
    await tester.tap(find.text('Save user'));
    await tester.pumpAndSettle();

    expect(find.text('Alex Morgan'), findsOneWidget);
    expect(find.text('Face not saved'), findsOneWidget);
    expect(store.users.single.name, 'Alex Morgan');
  });

  testWidgets('enrolled photos can be viewed and shared with confirmation', (
    tester,
  ) async {
    final store = _FakeFaceStore()
      ..users.add(
        const RegisteredUser(
          id: 'user-1',
          name: 'Alex Morgan',
          faceImagePaths: [
            '/private/faces/user-1-0.jpg',
            '/private/faces/user-1-1.jpg',
            '/private/faces/user-1-2.jpg',
            '/private/faces/user-1-3.jpg',
          ],
        ),
      );
    await tester.pumpWidget(
      MyApp(store: store, identityService: _FakeFaceIdentityService()),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('face photos saved'), findsNothing);
    expect(find.textContaining('tap to view'), findsNothing);
    await tester.tap(find.byTooltip('View Alex Morgan face photos'));
    await tester.pumpAndSettle();

    expect(find.text('Alex Morgan face photos'), findsOneWidget);
    expect(find.text('Facing camera'), findsOneWidget);
    expect(find.text('Blink sample'), findsOneWidget);
    expect(find.text('Turned to one side'), findsOneWidget);
    expect(find.text('Turned to the other side'), findsOneWidget);

    await tester.tap(find.byTooltip('Share face photos'));
    await tester.pumpAndSettle();
    expect(find.text('Share face photos?'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Facing camera'));
    await tester.pumpAndSettle();
    expect(find.text('Facing camera'), findsOneWidget);
  });

  testWidgets('the app explains local matching can be wrong', (tester) async {
    await tester.pumpWidget(
      MyApp(
        store: _FakeFaceStore(),
        identityService: _FakeFaceIdentityService(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('About face recognition'));
    await tester.pumpAndSettle();

    expect(find.text('On-device face recognition'), findsOneWidget);
    expect(
      find.textContaining('face-embedding model compares'),
      findsOneWidget,
    );
    expect(find.textContaining('must not be used by itself'), findsOneWidget);
  });

  testWidgets(
    'recognition errors stay concise until technical details are opened',
    (tester) async {
      final store = _FakeFaceStore()
        ..users.add(const RegisteredUser(id: 'user-1', name: 'Alex Morgan'));
      await tester.pumpWidget(
        MyApp(store: store, identityService: _UnavailableFaceIdentityService()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Face recognition couldn’t start.'), findsOneWidget);
      expect(
        find.textContaining('TfLiteInterpreterOptionsCreate'),
        findsNothing,
      );

      await tester.tap(find.text('Technical details'));
      await tester.pumpAndSettle();

      expect(
        find.text('Exception: TfLiteInterpreterOptionsCreate is missing'),
        findsOneWidget,
      );
    },
  );
}

class _UnavailableFaceIdentityService extends _FakeFaceIdentityService {
  @override
  Future<void> prepare(List<RegisteredUser> users) async {
    throw Exception('TfLiteInterpreterOptionsCreate is missing');
  }
}

class _FakeFaceStore implements FaceStore {
  final List<RegisteredUser> users = [];
  int _nextId = 0;

  @override
  Future<RegisteredUser> createUser(String name) async {
    final user = RegisteredUser(id: 'user-${_nextId++}', name: name);
    users.add(user);
    return user;
  }

  @override
  Future<RegisteredUser> enrollUser(String userId, List<XFile> images) async {
    final index = users.indexWhere((user) => user.id == userId);
    final user = RegisteredUser(
      id: userId,
      name: users[index].name,
      faceImagePaths: List.generate(
        images.length,
        (index) => '/private/faces/$userId-$index.jpg',
      ),
    );
    users[index] = user;
    return user;
  }

  @override
  Future<List<RegisteredUser>> listUsers() async => List.of(users);
}

class _FakeFaceIdentityService implements FaceIdentityService {
  int _nextSessionId = 0;

  @override
  Future<void> prepare(List<RegisteredUser> users) async {}

  @override
  String createEnrollmentSession() => 'pending-test-${_nextSessionId++}';

  @override
  Future<void> addEnrollmentSample({
    required String sessionId,
    required RegisteredUser user,
    required String imagePath,
    required int sampleIndex,
  }) async {}

  @override
  Future<void> completeEnrollment({
    required String sessionId,
    required RegisteredUser user,
  }) async {}

  @override
  Future<void> cancelEnrollment(String sessionId) async {}

  @override
  Future<String?> recognizeImage(String imagePath) async => null;
}
