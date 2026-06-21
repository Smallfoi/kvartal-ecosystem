import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_config.dart';
import '../../map/data/location_provider.dart';

/// Морозный коэффициент (якутская специфика, CLAUDE.md): чем холоднее — тем
/// больше бонус к очкам за бег. Бонус начинается ниже -10°C, потолок ×2.0.
/// Окно/наклон подкрутим по тесту (как и территории).
double frostMultiplier(double tempC) {
  if (tempC >= -10) return 1.0;
  final bonus = ((-tempC) - 10) / 10 * 0.2; // каждые ~10° холода = +0.2
  final m = 1.0 + bonus;
  if (m < 1.0) return 1.0;
  if (m > 2.0) return 2.0;
  return double.parse(m.toStringAsFixed(2));
}

class Weather {
  final double tempC;
  const Weather(this.tempC);
  double get multiplier => frostMultiplier(tempC);
}

/// Текущая погода по координатам пользователя. Источник — **MET Norway**
/// (api.met.no): бесплатно, без ключа, коммерческое использование разрешено
/// (CC-BY 4.0; нужен User-Agent + атрибуция) — выбран по той же логике, что
/// карта (D-19): без платных/санкционных провайдеров. Кэшируется; обновляется
/// раз в ~20 мин (погода меняется медленно, и met.no просит не частить).
class WeatherNotifier extends StateNotifier<Weather?> {
  final Ref ref;
  Timer? _timer;

  WeatherNotifier(this.ref) : super(null) {
    refresh();
    _timer = Timer.periodic(const Duration(minutes: 20), (_) => refresh());
  }

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      // met.no требует осмысленный User-Agent с контактом, иначе блокирует.
      headers: const {
        'User-Agent': 'STAW-Kvartal/1.0 (github.com/Smallfoi/kvartal-ecosystem)',
      },
    ),
  );

  Future<void> refresh() async {
    var lat = yakutskCenter.latitude;
    var lng = yakutskCenter.longitude;
    try {
      final pos = await ref.read(currentPositionProvider.future);
      if (pos != null) {
        lat = pos.latitude;
        lng = pos.longitude;
      }
    } catch (_) {
      // нет позиции — берём центр Якутска
    }
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://api.met.no/weatherapi/locationforecast/2.0/compact',
        // met.no просит обрезать координаты до 4 знаков (лучше кэшируется).
        queryParameters: {
          'lat': lat.toStringAsFixed(4),
          'lon': lng.toStringAsFixed(4),
        },
      );
      final series =
          (response.data?['properties']?['timeseries'] as List?) ?? const [];
      if (series.isEmpty) return;
      final t = series.first?['data']?['instant']?['details']?['air_temperature'];
      final temp = (t as num?)?.toDouble();
      if (temp != null) state = Weather(temp);
    } catch (_) {
      // офлайн/ошибка — оставляем прошлое значение (или null)
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final weatherProvider =
    StateNotifierProvider<WeatherNotifier, Weather?>((ref) => WeatherNotifier(ref));
