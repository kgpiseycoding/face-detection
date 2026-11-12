import 'package:shared_preferences/shared_preferences.dart';

abstract final class AppConfig {
  static const baseUrl = String.fromEnvironment(
    'HRM_BASE_URL',
    defaultValue: 'http://154.26.134.117:8082',
  );

  static const _baseUrlPreferenceKey = 'hrm_base_url';

  static const apiKey =
      '629887b2ab4a0af05e687f4f9904d8e4e61ebb0b3a6ebb7ea272e392616f9456';

  static Future<String> loadBaseUrl() async {
    final preferences = await SharedPreferences.getInstance();
    final savedBaseUrl = preferences.getString(_baseUrlPreferenceKey);
    return savedBaseUrl == null || savedBaseUrl.trim().isEmpty
        ? baseUrl
        : savedBaseUrl;
  }

  static Future<void> saveBaseUrl(String value) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(_baseUrlPreferenceKey, value)) {
      throw Exception('Could not save the HRM server URL.');
    }
  }
}
