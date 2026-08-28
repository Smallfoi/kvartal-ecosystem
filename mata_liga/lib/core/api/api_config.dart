import 'package:flutter/foundation.dart' show kReleaseMode;

class ApiConfig {
  ApiConfig._();

  /// Release-сборки (apk/ipa/web) → боевой backend; debug → локальный dev.
  /// Переопределить: --dart-define=KVARTAL_API_BASE_URL=https://.../v1
  static const _prodBaseUrl = 'https://api.mata-club.ru/v1';
  static const _devBaseUrl = 'http://127.0.0.1:8000/v1';
  static const baseUrl = String.fromEnvironment(
    'KVARTAL_API_BASE_URL',
    defaultValue: kReleaseMode ? _prodBaseUrl : _devBaseUrl,
  );

  static const connectTimeout = Duration(seconds: 6);
  static const receiveTimeout = Duration(seconds: 10);

  /// Относительный media-URL (`/media/...`) → абсолютный (origin без `/v1`).
  /// Пустую строку и абсолютные URL возвращаем как есть. Удобно для аватаров/фото.
  static String resolveMedia(String? url) {
    if (url == null || url.isEmpty || url.startsWith('http')) return url ?? '';
    final origin = baseUrl.replaceFirst(RegExp(r'/v1/?$'), '');
    return url.startsWith('/') ? '$origin$url' : '$origin/$url';
  }
}
