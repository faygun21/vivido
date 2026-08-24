abstract final class AppConfig {
  static const String appName = 'Vivido';

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000/api/v1',
  );

  static const String tileBaseUrl = String.fromEnvironment(
    'TILE_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
