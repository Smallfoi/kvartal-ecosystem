import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Уровень доступа к геолокации для трекинга маршрута.
/// - denied      — нет даже «при использовании», бегать нельзя;
/// - whenInUse   — только на переднем плане (в фоне трек прервётся);
/// - always      — «Разрешить всё время», фоновый трекинг работает.
enum LocationLevel { denied, whenInUse, always }

/// Тонкая обёртка над permission_handler для геолокации + батареи + бренда.
/// Зачем: фоновый трек маршрута требует фонового разрешения, а агрессивные
/// прошивки (Infinix/Xiaomi/...) ещё и убивают фоновые сервисы — это учитываем.
class LocationAccess {
  LocationAccess._();

  static const _channel = MethodChannel('kvartal/location_service');

  static bool get _mobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static Future<LocationLevel> level() async {
    if (!_mobile) return LocationLevel.always; // desktop/web — для dev не блокируем
    if (await Permission.locationAlways.isGranted) return LocationLevel.always;
    if (await Permission.locationWhenInUse.isGranted) {
      return LocationLevel.whenInUse;
    }
    return LocationLevel.denied;
  }

  /// Базовое разрешение «при использовании» — без него бегать нельзя вообще.
  static Future<LocationLevel> requestWhenInUse() async {
    if (!_mobile) return LocationLevel.always;
    await Permission.locationWhenInUse.request();
    return level();
  }

  /// Фоновое «Разрешить всё время». Вызывать ПОСЛЕ whenInUse.
  /// На Android 11+ система не показывает диалог — придётся вести в настройки.
  static Future<LocationLevel> requestAlways() async {
    if (!_mobile) return LocationLevel.always;
    await Permission.locationAlways.request();
    return level();
  }

  static Future<bool> isBatteryUnrestricted() async {
    if (!_mobile || !Platform.isAndroid) return true;
    try {
      return await Permission.ignoreBatteryOptimizations.isGranted;
    } catch (_) {
      return true;
    }
  }

  /// Системный диалог «не экономить батарею для приложения».
  static Future<bool> requestBatteryUnrestricted() async {
    if (!_mobile || !Platform.isAndroid) return true;
    try {
      final res = await Permission.ignoreBatteryOptimizations.request();
      return res.isGranted;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openSettings() => openAppSettings();

  /// Производитель устройства (lowercase) — для подсказок по «убийцам фона».
  static Future<String> manufacturer() async {
    if (!_mobile || !Platform.isAndroid) return '';
    try {
      final m = await _channel.invokeMethod<String>('getManufacturer');
      return (m ?? '').trim().toLowerCase();
    } catch (_) {
      return '';
    }
  }
}

/// Известные «супер-ограничители» фоновой работы (по dontkillmyapp.com).
/// Если телефон из этого списка — обязательно показать инструкцию по автозапуску.
const aggressiveOemBrands = <String>{
  'transsion', 'infinix', 'tecno', 'itel', // Transsion — самые агрессивные
  'xiaomi', 'redmi', 'poco', // MIUI/HyperOS
  'huawei', 'honor', // EMUI/MagicOS
  'oppo', 'realme', 'oneplus', 'vivo', 'iqoo', // BBK (ColorOS/OriginOS)
  'samsung', // One UI
  'meizu', 'asus', 'sony', 'lenovo', 'motorola', 'blackview', 'wiko', 'nokia',
};

bool isAggressiveOem(String manufacturer) {
  final m = manufacturer.toLowerCase();
  return aggressiveOemBrands.any((b) => m.contains(b));
}

/// Короткая подсказка, что включить на конкретном бренде, чтобы фон не убивали.
String oemBackgroundHint(String manufacturer) {
  final m = manufacturer.toLowerCase();
  if (m.contains('infinix') ||
      m.contains('tecno') ||
      m.contains('itel') ||
      m.contains('transsion')) {
    return 'Настройки → Приложения → КВАРТАЛ: включи «Автозапуск», сними ограничения '
        'фоновой активности; в «Power Marathon/Экономия» добавь приложение в исключения.';
  }
  if (m.contains('xiaomi') || m.contains('redmi') || m.contains('poco')) {
    return 'Настройки → Приложения → КВАРТАЛ: «Автозапуск» — вкл; «Контроль активности» — '
        'без ограничений; «Экономия батареи» — без ограничений.';
  }
  if (m.contains('huawei') || m.contains('honor')) {
    return 'Настройки → Батарея → Запуск приложений → КВАРТАЛ: ручное управление, '
        'включи автозапуск, фоновую работу и вторичный запуск.';
  }
  if (m.contains('oppo') ||
      m.contains('realme') ||
      m.contains('oneplus') ||
      m.contains('vivo') ||
      m.contains('iqoo')) {
    return 'Настройки → Батарея → КВАРТАЛ: разреши фоновую работу и автозапуск; '
        'сними «Умную экономию» для приложения.';
  }
  if (m.contains('samsung')) {
    return 'Настройки → Батарея → Ограничения в фоне: убери КВАРТАЛ из спящих приложений; '
        'в приложении выбери «Без ограничений».';
  }
  return 'В настройках батареи разреши КВАРТАЛ работать в фоне без ограничений '
      'и включи автозапуск, если он есть.';
}
