import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../map/data/location_provider.dart';

/// Текущая погода для точки (реальные данные Open-Meteo).
/// Морозный коэффициент к баллам тут НЕ считается — это отдельная фича (D-20).
class WeatherData {
  final double tempC;
  final double feelsLikeC;
  final double windSpeedKmh;
  final int windDirDeg;
  final int precipProbabilityPct;
  final int humidityPct;
  final int weatherCode; // WMO weather code

  const WeatherData({
    required this.tempC,
    required this.feelsLikeC,
    required this.windSpeedKmh,
    required this.windDirDeg,
    required this.precipProbabilityPct,
    required this.humidityPct,
    required this.weatherCode,
  });
}

// Open-Meteo: бесплатно, без ключа и без санкционных ограничений (как карта, D-19).
// Зовём напрямую с клиента — бэкенд не нужен. Прокси через свой backend — опция на будущее (§12 launch).
const _openMeteoUrl = 'https://api.open-meteo.com/v1/forecast';

Future<WeatherData> _fetchWeather(LatLng at) async {
  final dio = Dio();
  final res = await dio.get<Map<String, dynamic>>(
    _openMeteoUrl,
    queryParameters: {
      'latitude': at.latitude,
      'longitude': at.longitude,
      'current':
          'temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,wind_direction_10m',
      'hourly': 'precipitation_probability',
      'wind_speed_unit': 'kmh',
      'timezone': 'auto',
      'forecast_days': 1,
    },
    options: Options(
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 10),
    ),
  );

  final data = res.data ?? const {};
  final current = (data['current'] as Map<String, dynamic>?) ?? const {};

  return WeatherData(
    tempC: (current['temperature_2m'] as num?)?.toDouble() ?? 0,
    feelsLikeC: (current['apparent_temperature'] as num?)?.toDouble() ??
        (current['temperature_2m'] as num?)?.toDouble() ??
        0,
    windSpeedKmh: (current['wind_speed_10m'] as num?)?.toDouble() ?? 0,
    windDirDeg: (current['wind_direction_10m'] as num?)?.round() ?? 0,
    precipProbabilityPct: _currentHourPrecipProbability(data, current),
    humidityPct: (current['relative_humidity_2m'] as num?)?.round() ?? 0,
    weatherCode: (current['weather_code'] as num?)?.toInt() ?? 0,
  );
}

// Вероятность осадков отдаётся почасово — берём значение текущего часа.
int _currentHourPrecipProbability(
  Map<String, dynamic> data,
  Map<String, dynamic> current,
) {
  final hourly = data['hourly'] as Map<String, dynamic>?;
  if (hourly == null) return 0;
  final times = (hourly['time'] as List?) ?? const [];
  final probs = (hourly['precipitation_probability'] as List?) ?? const [];
  final nowHour = current['time'] as String?;
  final idx = nowHour == null ? -1 : times.indexOf(nowHour);
  if (idx >= 0 && idx < probs.length && probs[idx] != null) {
    return (probs[idx] as num).round();
  }
  if (probs.isNotEmpty && probs.first != null) {
    return (probs.first as num).round();
  }
  return 0;
}

/// Погода по текущей позиции игрока (если нет — центр Якутска).
final weatherProvider = FutureProvider.autoDispose<WeatherData>((ref) async {
  final pos = ref.watch(positionStreamProvider).valueOrNull?.toLatLng ??
      yakutskCenter;
  return _fetchWeather(pos);
});
