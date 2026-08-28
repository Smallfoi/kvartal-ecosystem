import 'package:latlong2/latlong.dart';

/// Лёгкий фильтр Калмана для сглаживания GPS-трека (подход как в Strava/Nike).
///
/// Идея: каждый фикс GPS «зашумлён», и степень доверия к нему задаётся его
/// точностью (accuracy, м) — чем хуже точность, тем меньше вес у фикса. Между
/// фиксами неопределённость растёт со «скоростью процесса» q (м/с), чтобы
/// фильтр успевал следовать за реальным движением, а не вяз на месте.
///
/// Координаты держим в градусах, дисперсию — в м². Это корректно: коэффициент
/// усиления k безразмерный (отношение дисперсий) и применяется к разнице в
/// градусах — классический приём для сглаживания GPS на телефоне.
class GpsKalman {
  /// Скорость процесса, м/с. Для бега ~3 — компромисс «плавно, но не вязко».
  final double processNoise;

  double _lat = 0;
  double _lng = 0;
  double _variance = -1; // м²; <0 — фильтр ещё не инициализирован
  int _timestampMs = 0;

  GpsKalman({this.processNoise = 3.0});

  bool get isEmpty => _variance < 0;

  /// Сбросить состояние (новый забег → чистый фильтр).
  void reset() => _variance = -1;

  /// Принять сырой фикс GPS и вернуть сглаженную точку.
  LatLng process({
    required double lat,
    required double lng,
    required double accuracy,
    required int timestampMs,
  }) {
    final acc = accuracy < 1 ? 1.0 : accuracy;

    if (_variance < 0) {
      // Первый фикс — берём как есть, дисперсия = точность².
      _lat = lat;
      _lng = lng;
      _variance = acc * acc;
      _timestampMs = timestampMs;
      return LatLng(_lat, _lng);
    }

    // Предсказание: за время dt неопределённость подросла.
    final dtMs = timestampMs - _timestampMs;
    if (dtMs > 0) {
      _variance += dtMs * processNoise * processNoise / 1000.0;
      _timestampMs = timestampMs;
    }

    // Коррекция: смешиваем прогноз и новый фикс по коэффициенту усиления.
    final k = _variance / (_variance + acc * acc);
    _lat += k * (lat - _lat);
    _lng += k * (lng - _lng);
    _variance = (1 - k) * _variance;

    return LatLng(_lat, _lng);
  }
}
