abstract final class AppConfig {
  static const baseUrl = String.fromEnvironment(
    'HRM_BASE_URL',
    defaultValue: 'http://154.26.134.117:8082',
  );

  static const apiKey =
      '629887b2ab4a0af05e687f4f9904d8e4e61ebb0b3a6ebb7ea272e392616f9456';
}
