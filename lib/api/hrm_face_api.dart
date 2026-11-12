import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../constants/face_angles.dart';
import 'hrm_api_exception.dart';

class HrmFaceApi {
  HrmFaceApi({
    required String baseUrl,
    required String apiKey,
    http.Client? client,
  }) : _baseUri = _parseBaseUri(baseUrl),
       apiKey = apiKey.trim(),
       _client = client ?? http.Client(),
       _ownsClient = client == null;

  Uri _baseUri;
  final String apiKey;
  final http.Client _client;
  final bool _ownsClient;

  String get baseUrl => _baseUri.toString();
  bool get hasApiKey => apiKey.trim().isNotEmpty;
  bool get hasPlaceholderBaseUrl => _baseUri.host == 'hrm-uat.yourcompany.com';

  void updateBaseUrl(String baseUrl) {
    _baseUri = _parseBaseUri(baseUrl);
  }

  static void validateBaseUrl(String baseUrl) {
    _parseBaseUri(baseUrl);
  }

  void close() {
    if (_ownsClient) _client.close();
  }

  Future<Object?> angles() => _get(_uri(['face-angles', 'angles']));

  Future<Object?> employees({
    String search = '',
    String status = 'ACTIVE',
    int page = 0,
    int size = 500,
  }) {
    if (page < 0 || size <= 0) {
      throw ArgumentError('page must be >= 0 and size must be > 0.');
    }
    return _get(
      _uri(
        ['employees'],
        {'search': search, 'status': status, 'page': '$page', 'size': '$size'},
      ),
    );
  }

  Future<Object?> employeeAngles(String code) {
    _validateCode(code);
    return _get(_uri(['employees', code, 'face-angles']));
  }

  Future<Uint8List> employeeAngleImage(String code, String angle) async {
    _validateCode(code);
    _validateAngle(angle);
    final response = await _client
        .get(
          _uri(['employees', code, 'face-angles', angle, 'image']),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _decode(response);
      throw HrmApiException(
        statusCode: response.statusCode,
        message: 'The HRM image request failed.',
      );
    }

    final contentType = response.headers['content-type']
        ?.split(';')
        .first
        .trim()
        .toLowerCase();
    final bytes = response.bodyBytes;
    if (contentType != 'image/jpeg' ||
        bytes.length < 4 ||
        bytes.length > 5 * 1024 * 1024 ||
        bytes[0] != 0xff ||
        bytes[1] != 0xd8 ||
        bytes[bytes.length - 2] != 0xff ||
        bytes[bytes.length - 1] != 0xd9) {
      throw const FormatException(
        'The HRM face-angle endpoint did not return a valid JPEG image.',
      );
    }
    return bytes;
  }

  String angleImageUrl(String code, String angle) {
    _validateCode(code);
    _validateAngle(angle);
    return _uri(['employees', code, 'face-angles', angle, 'image']).toString();
  }

  Future<Object?> uploadAngle(
    String code,
    String angle,
    Uint8List jpeg, {
    String source = 'MOBILE_CAPTURE',
  }) async {
    _validateCode(code);
    _validateAngle(angle);
    if (jpeg.isEmpty) {
      throw ArgumentError.value(jpeg, 'jpeg', 'Must not be empty.');
    }

    final request =
        http.MultipartRequest(
            'POST',
            _uri(['employees', code, 'face-angles', angle]),
          )
          ..headers.addAll(_headers)
          ..fields['source'] = source
          ..files.add(
            http.MultipartFile.fromBytes(
              'image',
              jpeg,
              filename: '$angle.jpg',
              contentType: MediaType('image', 'jpeg'),
            ),
          );
    final streamedResponse = await _client
        .send(request)
        .timeout(const Duration(seconds: 45));
    final response = await http.Response.fromStream(streamedResponse);
    return _decode(response);
  }

  Map<String, String> get _headers => {'X-API-KEY': apiKey};

  Uri _uri(List<String> parts, [Map<String, String>? query]) {
    final baseSegments = _baseUri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();

    print('Base Segments: $baseSegments');
    return _baseUri.replace(
      pathSegments: [...baseSegments, 'api', 'face-recognition', ...parts],
      queryParameters: query,
    );
  }

  Future<Object?> _get(Uri uri) async {
    final response = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 30));
    return _decode(response);
  }

  Object? _decode(http.Response response) {
    Object? body;
    if (response.bodyBytes.isNotEmpty) {
      try {
        body = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        body = null;
      }
    }

    String? serverMessage;
    var apiReportedFailure = false;
    if (body is Map<String, dynamic>) {
      final message = body['message'] ?? body['error'];
      if (message is String) serverMessage = message;
      apiReportedFailure = body['success'] == false || body['error'] != null;
      final data = body['data'];
      final errors = data is Map<String, dynamic> ? data['errors'] : null;
      if (errors is Map<String, dynamic> && errors.isNotEmpty) {
        final details = errors.entries
            .map((entry) => '${entry.key}: ${entry.value}')
            .join('; ');
        serverMessage = [
          if (serverMessage != null && serverMessage.isNotEmpty) serverMessage,
          details,
        ].join(' — ');
      }
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        apiReportedFailure) {
      throw HrmApiException(
        statusCode: response.statusCode,
        message: serverMessage ?? '',
      );
    }

    if (body is Map<String, dynamic> && body.containsKey('data')) {
      return body['data'];
    }
    return body;
  }

  void _validateCode(String code) {
    if (code.trim().isEmpty) {
      throw ArgumentError.value(code, 'code', 'Must not be empty.');
    }
  }

  void _validateAngle(String angle) {
    if (!faceAngleKeys.contains(angle)) {
      throw ArgumentError.value(angle, 'angle', 'Unknown face angle.');
    }
  }

  static Uri _parseBaseUri(String baseUrl) {
    final uri = Uri.parse(baseUrl.trim());
    if (!uri.hasScheme ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw ArgumentError.value(
        baseUrl,
        'baseUrl',
        'Must be an absolute HTTP or HTTPS URL without credentials, query, or fragment.',
      );
    }
    return uri;
  }
}
