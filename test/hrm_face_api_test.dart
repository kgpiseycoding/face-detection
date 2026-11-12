import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:face_detection/api/hrm_api_exception.dart';
import 'package:face_detection/api/hrm_face_api.dart';

void main() {
  test('downloads employee angle JPEG with API key header', () async {
    http.Request? sentRequest;
    final client = MockClient((request) async {
      sentRequest = request;
      return http.Response.bytes(
        Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]),
        200,
        headers: {'content-type': 'image/jpeg'},
      );
    });
    final api = HrmFaceApi(
      baseUrl: 'http://hrm.test',
      apiKey: 'test-key',
      client: client,
    );

    final image = await api.employeeAngleImage('EMP0150', 'straight');

    expect(
      sentRequest!.url.toString(),
      'http://hrm.test/api/face-recognition/employees/'
      'EMP0150/face-angles/straight/image',
    );
    expect(sentRequest!.headers['X-API-KEY'], 'test-key');
    expect(image, [0xff, 0xd8, 0xff, 0xd9]);

    client.close();
  });

  test('uses an updated base URL for subsequent requests', () async {
    http.Request? sentRequest;
    final client = MockClient((request) async {
      sentRequest = request;
      return http.Response('{"employees":[]}', 200);
    });
    final api = HrmFaceApi(
      baseUrl: 'https://old.hrm.test',
      apiKey: 'test-key',
      client: client,
    );

    api.updateBaseUrl('https://new.hrm.test/hrm');
    await api.employees();

    expect(api.baseUrl, 'https://new.hrm.test/hrm');
    expect(
      sentRequest!.url.toString(),
      'https://new.hrm.test/hrm/api/face-recognition/employees'
      '?search&status=ACTIVE&page=0&size=500',
    );

    client.close();
  });

  test('requests active employees with the configured API key', () async {
    http.Request? sentRequest;
    final client = MockClient((request) async {
      sentRequest = request;
      return http.Response(
        jsonEncode({
          'success': true,
          'message': 'OK',
          'data': {
            'employees': [
              {
                'employeeCode': 'EMP0150',
                'firstName': 'Nget',
                'lastName': 'Tim',
              },
            ],
            'page': 0,
            'size': 100,
            'totalPages': 1,
            'totalElements': 1,
          },
        }),
        200,
      );
    });
    final api = HrmFaceApi(
      baseUrl: 'https://uathrms.svtrucking.biz',
      apiKey: '  test-key \n',
      client: client,
    );

    final response = await api.employees(search: 'Tim', size: 100);

    expect(
      sentRequest!.url.toString(),
      'https://uathrms.svtrucking.biz/api/face-recognition/employees'
      '?search=Tim&status=ACTIVE&page=0&size=100',
    );
    expect(sentRequest!.headers['X-API-KEY'], 'test-key');
    expect(response, isA<Map<String, dynamic>>());
    expect(
      (response! as Map<String, dynamic>)['employees'],
      isA<List<dynamic>>(),
    );

    client.close();
  });

  test(
    'uploads a face angle to its exact endpoint as multipart JPEG',
    () async {
      http.Request? sentRequest;
      final client = MockClient((request) async {
        sentRequest = request;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'saved': ['left'],
            },
          }),
          200,
        );
      });
      final api = HrmFaceApi(
        baseUrl: 'https://hrm-uat.test',
        apiKey: 'test-key',
        client: client,
      );

      await api.uploadAngle(
        'EMP0150',
        'left',
        Uint8List.fromList([0xFF, 0xD8, 0xFF]),
      );

      final requestBody = utf8.decode(
        sentRequest!.bodyBytes,
        allowMalformed: true,
      );
      expect(
        sentRequest!.url.toString(),
        'https://hrm-uat.test/api/face-recognition/employees/'
        'EMP0150/face-angles/left',
      );
      expect(sentRequest!.method, 'POST');
      expect(sentRequest!.headers['X-API-KEY'], 'test-key');
      expect(
        sentRequest!.headers['content-type'],
        startsWith('multipart/form-data;'),
      );
      expect(requestBody, contains('name="image"; filename="left.jpg"'));
      expect(requestBody, contains('content-type: image/jpeg'));
      expect(requestBody, contains('name="source"'));
      expect(requestBody, contains('MOBILE_CAPTURE'));

      client.close();
    },
  );

  test(
    'includes server per-image validation errors in the exception',
    () async {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'message': '0 saved, 1 failed',
            'data': {
              'employeeCode': 'EMP0150',
              'saved': {},
              'errors': {
                'image': 'Unknown angle. Use one of straight, blink, left, right, up, down.',
              },
            },
          }),
          200,
        );
      });
      final api = HrmFaceApi(
        baseUrl: 'https://hrm-uat.test',
        apiKey: 'test-key',
        client: client,
      );

      await expectLater(
        api.uploadAngle(
          'EMP0150',
          'left',
          Uint8List.fromList([0xFF, 0xD8, 0xFF]),
        ),
        throwsA(
          isA<HrmApiException>()
              .having((error) => error.statusCode, 'statusCode', 200)
              .having(
                (error) => error.userMessage,
                'userMessage',
                contains('image: Unknown angle.'),
              ),
        ),
      );

      client.close();
    },
  );
}
