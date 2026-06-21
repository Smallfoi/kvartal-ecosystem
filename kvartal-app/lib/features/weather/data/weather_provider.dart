import 'dart:math' show pow;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../map/data/location_provider.dart';

/// Текущая погода для точки (реальные данные MET Norway).
/// Морозный коэффициент к баллам тут НЕ считается — это отдельная фича (D-20).
class WeatherData {
  final double tempC;
  final double feelsLikeC;
  final double windSpeedKmh;
  final int windDirDeg;
  final int precipProbabilityPct;
  final int humidityPct;
  final int weatherCode; // WMO weather code (маппим из symbol_code met.no)

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

// MET Norway (api.met.no): бесплатно, без ключа, коммерческое использование
// разрешено (CC-BY 4.0) и — главное — РЕАЛЬНО доступен из РФ. Заменил Open-Meteo
// (D-20), который из РФ не грузился (соединение висло) и был только non-commercial.
// Требования met.no: осмысленный User-Agent с контактом, координаты ≤4 знаков,
// не частить (кэш на стороне провайдера ~раз в час). Зовём напрямую с клиента.
const _metNoUrl =
    'https://api.met.no/weatherapi/locationforecast/2.0/compact';

Future<WeatherData> _fetchWeather(LatLng at) async {
  final dio = Dio();
  final res = await dio.get<Map<String, dynamic>>(
    _metNoUrl,
    queryParameters: {
      'lat': at.latitude.toStringAsFixed(4),
      'lon': at.longitude.toStringAsFixed(4),
    },
    options: Options(
      receiveTimeout: const Duration(seconds: 15),
      // met.no без User-Agent с контактом блокирует запрос (403).
      headers: const {
        'User-Agent': 'STAW-Kvartal/1.0 (github.com/Smallfoi/kvartal-ecosystem)',
      },
    ),
  );

  final series =
      (res.data?['properties']?['timeseries'] as List?) ?? const [];
  if (series.isEmpty) {
    return const WeatherData(
      tempC: 0,
      feelsLikeC: 0,
      windSpeedKmh: 0,
      windDirDeg: 0,
      precipProbabilityPct: 0,
      humidityPct: 0,
      weatherCode: 0,
    );
  }

  final data0 =
      ((series.first as Map<String, dynamic>)['data'] as Map<String, dynamic>?) ??
          const {};
  final details =
      (data0['instant']?['details'] as Map<String, dynamic>?) ?? const {};
  final next1 = (data0['next_1_hours'] as Map<String, dynamic>?) ?? const {};
  final next1Details =
      (next1['details'] as Map<String, dynamic>?) ?? const {};
  final symbol = (next1['summary']?['symbol_code'] as String?) ?? '';

  final temp = (details['air_temperature'] as num?)?.toDouble() ?? 0;
  final windKmh = ((details['wind_speed'] as num?)?.toDouble() ?? 0) * 3.6;

  return WeatherData(
    tempC: temp,
    feelsLikeC: _windChill(temp, windKmh),
    windSpeedKmh: windKmh,
    windDirDeg: (details['wind_from_direction'] as num?)?.round() ?? 0,
    precipProbabilityPct:
        (next1Details['probability_of_precipitation'] as num?)?.round() ?? 0,
    humidityPct: (details['relative_humidity'] as num?)?.round() ?? 0,
    weatherCode: _wmoFromSymbol(symbol),
  );
}

/// «Ощущается как» — ветрохолодовой индекс (важно бегунам в мороз). Формула
/// Канады применима при T≤10°C и ветре ≥4.8 км/ч; иначе ≈ температура.
double _windChill(double tempC, double windKmh) {
  if (tempC > 10 || windKmh < 4.8) return tempC;
  final v = pow(windKmh, 0.16).toDouble();
  return 13.12 + 0.6215 * tempC - 11.37 * v + 0.3965 * tempC * v;
}

/// MET Norway `symbol_code` ("partlycloudy_day", "lightsnow", …) → ближайший
/// WMO-код, чтобы существующий UI (`weatherIcon`/`weatherLabel` по WMO) работал
/// без изменений.
int _wmoFromSymbol(String symbol) {
  final s = symbol.split('_').first; // отбрасываем _day/_night/_polartwilight
  if (s == 'clearsky') return 0;
  if (s == 'fair') return 1;
  if (s == 'partlycloudy') return 2;
  if (s == 'cloudy') return 3;
  if (s.contains('fog')) return 45;
  if (s.contains('thunder')) return 95;
  if (s.contains('sleet')) return 66;
  if (s.contains('snow')) return 71;
  if (s.contains('rainshowers') || s.contains('heavyrain')) return 80;
  if (s.contains('drizzle')) return 51;
  if (s.contains('rain')) return 61;
  return 3; // по умолчанию — облачно
}

/// Погода по позиции игрока (если нет — центр Якутска).
/// НЕ блокируемся на GPS (`getCurrentPosition` без таймаута может висеть → погода
/// вечно «…») и НЕ `watch`-им стрим (иначе перезапуск на каждый GPS-тик). Берём
/// НЕблокирующий снимок: есть позиция — по ней, нет — центр Якутска (погоде
/// хватает координат уровня города).
final weatherProvider = FutureProvider.autoDispose<WeatherData>((ref) async {
  final snapshot = ref.read(positionStreamProvider).valueOrNull;
  final pos = snapshot?.toLatLng ?? yakutskCenter;
  return _fetchWeather(pos);
});
