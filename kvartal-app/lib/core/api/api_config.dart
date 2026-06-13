class ApiConfig {
  ApiConfig._();

  static const baseUrl = String.fromEnvironment(
    'KVARTAL_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/v1',
  );

  static const connectTimeout = Duration(seconds: 6);
  static const receiveTimeout = Duration(seconds: 10);
}
