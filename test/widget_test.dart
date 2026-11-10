import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:face_detection/api/hrm_face_api.dart';
import 'package:face_detection/face_store.dart';
import 'package:face_detection/face_enrollment.dart';
import 'package:face_detection/face_identity_service.dart';
import 'package:face_detection/face_photo_normalizer.dart';
import 'package:face_detection/screens/employee_list_screen.dart';
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
    expect(FaceEnrollmentStep.front.instruction, 'សូមមើលត្រង់ទៅកាមេរ៉ា');
    expect(
      FaceEnrollmentStep.blink.instruction,
      'សូមព្រិចភ្នែក រួចបើកភ្នែកវិញ',
    );
    expect(FaceEnrollmentStep.lookUp.instruction, 'សូមងើយក្បាលឡើងលើ');
    expect(FaceEnrollmentStep.lookDown.instruction, 'សូមឱនក្បាលចុះក្រោម');
    expect(FaceEnrollmentStep.turnRight.instruction, 'សូមបង្វែរមុខទៅស្តាំ');
    expect(FaceEnrollmentStep.turnLeft.instruction, 'សូមបង្វែរមុខទៅឆ្វេង');
    expect(FaceEnrollmentStep.blink.next, FaceEnrollmentStep.lookUp);
    expect(FaceEnrollmentStep.lookUp.next, FaceEnrollmentStep.lookDown);
    expect(FaceEnrollmentStep.lookDown.next, FaceEnrollmentStep.turnRight);
    expect(FaceEnrollmentStep.turnRight.next, FaceEnrollmentStep.turnLeft);
    expect(FaceEnrollmentStep.turnLeft.next, isNull);
  });

  testWidgets('app loads users from the local store', (tester) async {
    final store = _FakeFaceStore();
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/employees')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'employees': [
                {
                  'employeeCode': 'E-EMPTY-STORE',
                  'firstName': 'First',
                  'lastName': 'Employee',
                  'departmentName': 'People',
                },
              ],
            },
          }),
          200,
        );
      }
      return http.Response('Unexpected request: ${request.url}', 404);
    });
    final api = HrmFaceApi(
      baseUrl: 'https://hrm.test',
      apiKey: 'test-key',
      client: client,
    );
    await tester.pumpWidget(
      MyApp(
        store: store,
        identityService: _FakeFaceIdentityService(),
        api: api,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      Localizations.localeOf(tester.element(find.text('មិនទាន់មានបុគ្គលិកទេ'))),
      const Locale('km'),
    );
    expect(find.text('មិនទាន់មានបុគ្គលិកទេ'), findsOneWidget);
    expect(find.text('Face Enrollment'), findsNothing);
    expect(find.text('បន្ថែមបុគ្គលិក'), findsOneWidget);

    await tester.tap(find.text('បន្ថែមបុគ្គលិក'));
    await tester.pumpAndSettle();
    expect(find.text('ជ្រើសរើសបុគ្គលិក'), findsOneWidget);
    expect(find.text('First Employee'), findsOneWidget);

    api.close();
    client.close();
  });

  testWidgets('employee picker labels face enrollment status', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/employees')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'employees': [
                {
                  'employeeCode': 'E-ENROLLED',
                  'firstName': 'Enrolled',
                  'lastName': 'Employee',
                  'departmentName': 'People',
                  'faceEnrolled': true,
                },
                {
                  'employeeCode': 'E-NEEDS',
                  'firstName': 'New',
                  'lastName': 'Employee',
                  'departmentName': 'People',
                  'faceEnrolled': false,
                },
              ],
            },
          }),
          200,
        );
      }
      return http.Response('Unexpected request: ${request.url}', 404);
    });
    final api = HrmFaceApi(
      baseUrl: 'https://hrm.test',
      apiKey: 'test-key',
      client: client,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EmployeeListScreen(
          api: api,
          selectionOnly: true,
          registeredEmployeeCodes: {'E-ENROLLED'},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('បានចុះឈ្មោះមុខរួចហើយ'), findsOneWidget);
    expect(find.text('មិនទាន់ចុះឈ្មោះមុខ'), findsOneWidget);
    expect(find.text('បានបន្ថែមក្នុងកម្មវិធី'), findsOneWidget);
    expect(find.text('មិនទាន់បន្ថែម'), findsOneWidget);

    await tester.tap(find.text('បានបន្ថែម (1)'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('employee-E-ENROLLED')), findsOneWidget);
    expect(find.byKey(const Key('employee-E-NEEDS')), findsNothing);

    await tester.tap(find.text('មិនទាន់បន្ថែម (1)'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('employee-E-ENROLLED')), findsNothing);
    expect(find.byKey(const Key('employee-E-NEEDS')), findsOneWidget);

    api.close();
    client.close();
  });

  testWidgets('main page shows every employee profile saved locally', (
    tester,
  ) async {
    final store = _FakeFaceStore()
      ..users.addAll(const [
        RegisteredUser(
          id: 'employee-one',
          name: 'Employee One',
          employeeCode: 'E-001',
        ),
        RegisteredUser(
          id: 'employee-two',
          name: 'Employee Two',
          employeeCode: 'E-002',
        ),
      ]);
    await tester.pumpWidget(
      MyApp(store: store, identityService: _FakeFaceIdentityService()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Employee One'), findsOneWidget);
    expect(find.text('Employee Two'), findsOneWidget);
  });

  testWidgets('an HRM-only employee image is visible from the user list', (
    tester,
  ) async {
    final store = _FakeFaceStore()
      ..users.add(
        const RegisteredUser(
          id: 'user-hrm',
          name: 'Morm Manuth',
          employeeCode: 'EMP-00144',
          hrmFaceImagePaths: {'straight': '/private/hrm/user-hrm-straight.jpg'},
        ),
      );
    await tester.pumpWidget(
      MyApp(store: store, identityService: _FakeFaceIdentityService()),
    );
    await tester.pumpAndSettle();

    expect(find.text('HRM មិនទាន់គ្រប់ (1/6)'), findsOneWidget);
    expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
    final avatar = tester.widget<Image>(find.byType(Image).first);
    expect(
      (avatar.image as FileImage).file.path,
      '/private/hrm/user-hrm-straight.jpg',
    );

    await tester.tap(find.byIcon(Icons.photo_library_outlined));
    await tester.pumpAndSettle();
    expect(find.text('រូបថតមុខរបស់ Morm Manuth'), findsOneWidget);
    expect(find.text('មើលត្រង់ទៅកាមេរ៉ា'), findsOneWidget);
  });

  testWidgets('main page marks all six cached HRM angles complete', (
    tester,
  ) async {
    final store = _FakeFaceStore()
      ..users.add(
        const RegisteredUser(
          id: 'user-hrm-complete',
          name: 'Complete Employee',
          employeeCode: 'EMP-00145',
          hrmFaceImagePaths: {
            'straight': '/private/hrm/straight.jpg',
            'blink': '/private/hrm/blink.jpg',
            'left': '/private/hrm/left.jpg',
            'right': '/private/hrm/right.jpg',
            'up': '/private/hrm/up.jpg',
            'down': '/private/hrm/down.jpg',
          },
        ),
      );
    await tester.pumpWidget(
      MyApp(store: store, identityService: _FakeFaceIdentityService()),
    );
    await tester.pumpAndSettle();

    expect(find.text('HRM រួចរាល់ (6/6)'), findsOneWidget);
  });

  testWidgets('a user is saved to the local store', (tester) async {
    final store = _FakeFaceStore();
    final profileJpeg = Uint8List.fromList(
      img.encodeJpg(img.Image(width: 2, height: 2)),
    );
    final requestedUris = <Uri>[];
    final client = MockClient((request) async {
      requestedUris.add(request.url);
      if (request.url.path.endsWith('/employees')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'OK',
            'data': {
              'employees': [
                {
                  'employeeCode': 'E-104',
                  'firstName': 'Alex',
                  'lastName': 'Morgan',
                  'latinName': 'Alex Morgan',
                  'departmentName': 'People',
                  'status': 'ACTIVE',
                  'hasPhoto': true,
                },
              ],
              'page': 0,
              'size': 100,
              'totalPages': 1,
              'totalElements': 1,
            },
            'timestamp': '2026-11-06T08:19:44.319904',
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/face-angles/straight/image')) {
        return http.Response.bytes(
          profileJpeg,
          200,
          headers: {'content-type': 'image/jpeg'},
        );
      }
      if (request.url.path.endsWith('/employees/E-104/face-angles')) {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'success': true,
              'message': 'OK',
              'data': {
                'employeeCode': 'E-104',
                'angles': [
                  {
                    'angle': 'straight',
                    'labelEn': 'Looking straight ahead',
                    'labelKm': 'មើលត្រង់',
                    'contentType': 'image/jpeg',
                    'verificationStatus': 'matched',
                  },
                ],
                'missing': ['blink', 'left', 'right', 'up', 'down'],
              },
              'timestamp': '2026-11-05T15:02:44.400139',
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path.endsWith('/face-angles/straight/image')) {
        return http.Response.bytes(
          [0xff, 0xd8, 0xff, 0xd9],
          200,
          headers: {'content-type': 'image/jpeg'},
        );
      }
      return http.Response('Unexpected request: ${request.url}', 404);
    });
    final api = HrmFaceApi(
      baseUrl: 'https://hrm.test',
      apiKey: 'test-key',
      client: client,
    );
    await tester.pumpWidget(
      MyApp(
        store: store,
        identityService: _FakeFaceIdentityService(),
        api: api,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('បន្ថែមបុគ្គលិក').first);
    await tester.pumpAndSettle();
    expect(find.text('ជ្រើសរើសបុគ្គលិក'), findsOneWidget);
    expect(find.text('Alex Morgan'), findsOneWidget);
    expect(
      requestedUris.map((uri) => uri.path),
      contains(
        '/api/face-recognition/employees/E-104/face-angles/straight/image',
      ),
    );
    final employeeAvatar = tester.widget<CircleAvatar>(
      find.byType(CircleAvatar).last,
    );
    expect(employeeAvatar.backgroundImage, isA<MemoryImage>());
    await tester.tap(find.byKey(const Key('employee-E-104')));
    await tester.pumpAndSettle();

    expect(
      requestedUris.map((uri) => uri.path),
      contains('/api/face-recognition/employees/E-104/face-angles'),
    );
    expect(find.text('បានថត 1 ក្នុងចំណោម 6 មុំ'), findsOneWidget);
    expect(find.textContaining('ផ្ទៀងផ្ទាត់ត្រឹមត្រូវ'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
    expect(find.text('Alex Morgan'), findsOneWidget);
    expect(store.users.single.name, 'Alex Morgan');
    expect(store.users.single.employeeCode, 'E-104');
    expect(store.users.single.hrmFaceImagePaths.keys, ['straight']);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('មើលរូបថតមុខរបស់ Alex Morgan'));
    await tester.pumpAndSettle();
    expect(find.text('រូបថតមុំមុខពី HRM'), findsOneWidget);
    expect(find.text('មើលត្រង់ទៅកាមេរ៉ា'), findsOneWidget);
    api.close();
    client.close();
  });

  testWidgets(
    'selecting an existing employee opens setup without duplicating',
    (tester) async {
      final store = _FakeFaceStore()
        ..users.add(
          const RegisteredUser(
            id: 'existing-user',
            name: 'Alex Morgan',
            employeeCode: ' e-104 ',
          ),
        );
      final requestedUris = <Uri>[];
      final client = MockClient((request) async {
        requestedUris.add(request.url);
        if (request.url.path.endsWith('/employees')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'employees': [
                  {
                    'employeeCode': 'E-104',
                    'firstName': 'Alex',
                    'lastName': 'Morgan',
                    'departmentName': 'People',
                    'status': 'ACTIVE',
                  },
                ],
              },
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/employees/E-104/face-angles')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'employeeCode': 'E-104',
                'angles': [],
                'missing': ['straight', 'blink', 'left', 'right', 'up', 'down'],
              },
            }),
            200,
          );
        }
        return http.Response('Unexpected request: ${request.url}', 404);
      });
      final api = HrmFaceApi(
        baseUrl: 'https://hrm.test',
        apiKey: 'test-key',
        client: client,
      );
      await tester.pumpWidget(
        MyApp(
          store: store,
          identityService: _FakeFaceIdentityService(),
          api: api,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('employee-E-104')));
      await tester.pumpAndSettle();

      expect(find.text('Alex Morgan'), findsOneWidget);
      expect(find.text('ថតរូបទាំង ៦ មុំដោយស្វ័យប្រវត្តិ'), findsOneWidget);
      expect(
        requestedUris.map((uri) => uri.path),
        contains('/api/face-recognition/employees/E-104/face-angles'),
      );
      expect(store.users, hasLength(1));
      expect(store.users.single.id, 'existing-user');

      Navigator.of(tester.element(find.text('ថតរូបទាំង ៦ មុំដោយស្វ័យប្រវត្តិ')))
          .pop();
      await tester.pumpAndSettle();
      expect(store.users, hasLength(1));
      expect(find.text('Alex Morgan'), findsOneWidget);

      api.close();
      client.close();
    },
  );

  testWidgets('employee picker explains iPhone local-network failures', (
    tester,
  ) async {
    final client = MockClient((_) async {
      throw const SocketException('Network is unreachable');
    });
    final api = HrmFaceApi(
      baseUrl: 'https://uathrms.svtrucking.biz',
      apiKey: 'test-key',
      client: client,
    );
    await tester.pumpWidget(
      MyApp(
        store: _FakeFaceStore(),
        identityService: _FakeFaceIdentityService(),
        api: api,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('បន្ថែមបុគ្គលិក').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('uathrms.svtrucking.biz'), findsOneWidget);
    expect(find.textContaining('កម្មវិធីនេះ'), findsOneWidget);

    api.close();
    client.close();
  });

  testWidgets('employee picker error can scroll on a short screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = MockClient((_) async => http.Response('Unauthorized', 401));
    final api = HrmFaceApi(
      baseUrl: 'https://hrm.test',
      apiKey: 'test-key',
      client: client,
    );
    await tester.pumpWidget(
      MaterialApp(home: EmployeeListScreen(api: api, selectionOnly: true)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('បានបដិសេធ API key'), findsOneWidget);
    expect(find.text('សាកល្បងម្ដងទៀត'), findsOneWidget);
    expect(tester.takeException(), isNull);

    api.close();
    client.close();
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

    expect(find.textContaining('បានរក្សាទុករូបភាពមុខ'), findsNothing);
    expect(find.textContaining('ចុចដើម្បីមើល'), findsNothing);
    await tester.tap(find.byTooltip('មើលរូបថតមុខរបស់ Alex Morgan'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Alex Morgan'), findsOneWidget);
    expect(find.text('មើលត្រង់ទៅកាមេរ៉ា'), findsOneWidget);
    expect(find.text('ព្រិចភ្នែក'), findsOneWidget);
    expect(find.text('បែរមុខទៅម្ខាង'), findsOneWidget);
    expect(find.text('បែរមុខទៅម្ខាងទៀត'), findsOneWidget);

    await tester.tap(find.byTooltip('ចែករំលែករូបថតមុខ'));
    await tester.pumpAndSettle();
    expect(find.text('ចែករំលែករូបថតមុខឬ?'), findsOneWidget);
    expect(find.text('បន្ត'), findsOneWidget);
    await tester.tap(find.text('បោះបង់'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('មើលត្រង់ទៅកាមេរ៉ា'));
    await tester.pumpAndSettle();
    expect(find.text('មើលត្រង់ទៅកាមេរ៉ា'), findsOneWidget);
  });

  testWidgets('the app opens on the local profile list', (tester) async {
    await tester.pumpWidget(
      MyApp(
        store: _FakeFaceStore(),
        identityService: _FakeFaceIdentityService(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('មិនទាន់មានបុគ្គលិកទេ'), findsOneWidget);
    expect(find.text('បន្ថែមបុគ្គលិក'), findsOneWidget);
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

      expect(find.text('មិនអាចចាប់ផ្ដើមការស្គាល់មុខបានទេ។'), findsOneWidget);
      expect(
        find.textContaining('TfLiteInterpreterOptionsCreate'),
        findsNothing,
      );

      await tester.tap(find.text('ព័ត៌មានបច្ចេកទេស'));
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
  Future<RegisteredUser> createUser(String name, {String? employeeCode}) async {
    final user = RegisteredUser(
      id: 'user-${_nextId++}',
      name: name,
      employeeCode: employeeCode,
    );
    users.add(user);
    return user;
  }

  @override
  Future<RegisteredUser> linkUserToEmployee(
    String userId,
    String employeeCode,
  ) async {
    final index = users.indexWhere((user) => user.id == userId);
    final user = RegisteredUser(
      id: userId,
      name: users[index].name,
      faceImagePaths: users[index].faceImagePaths,
      employeeCode: employeeCode,
      hrmFaceImagePaths: users[index].hrmFaceImagePaths,
    );
    users[index] = user;
    return user;
  }

  @override
  Future<RegisteredUser> enrollUser(String userId, List<XFile> images) async {
    final index = users.indexWhere((user) => user.id == userId);
    final user = RegisteredUser(
      id: userId,
      name: users[index].name,
      employeeCode: users[index].employeeCode,
      hrmFaceImagePaths: users[index].hrmFaceImagePaths,
      faceImagePaths: List.generate(
        images.length,
        (index) => '/private/faces/$userId-$index.jpg',
      ),
    );
    users[index] = user;
    return user;
  }

  @override
  Future<RegisteredUser> saveHrmFaceImages(
    String userId,
    Map<String, Uint8List> images, {
    bool replaceExisting = false,
  }) async {
    final index = users.indexWhere((user) => user.id == userId);
    final current = users[index];
    final user = RegisteredUser(
      id: current.id,
      name: current.name,
      employeeCode: current.employeeCode,
      faceImagePaths: current.faceImagePaths,
      hrmFaceImagePaths: {
        if (!replaceExisting) ...current.hrmFaceImagePaths,
        for (final angle in images.keys)
          angle: '/private/hrm/${current.id}-$angle.jpg',
      },
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
