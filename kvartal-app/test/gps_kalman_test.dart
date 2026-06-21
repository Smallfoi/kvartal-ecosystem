import 'package:flutter_test/flutter_test.dart';
import 'package:kvartal_app/features/run/data/gps_kalman.dart';

void main() {
  group('GpsKalman', () {
    int ts = 0;
    setUp(() => ts = 0);

    test('первый фикс проходит без изменений', () {
      final k = GpsKalman();
      final p = k.process(lat: 62.0, lng: 129.0, accuracy: 5, timestampMs: ++ts);
      expect(p.latitude, 62.0);
      expect(p.longitude, 129.0);
    });

    test('резкий выброс сглаживается (метка не телепортируется)', () {
      final k = GpsKalman();
      k.process(lat: 62.0, lng: 129.0, accuracy: 5, timestampMs: (ts += 1000));
      // Внезапный «прыжок» на ~0.001° при той же точности.
      final p = k.process(
        lat: 62.001,
        lng: 129.0,
        accuracy: 5,
        timestampMs: (ts += 1000),
      );
      // Результат строго между старой и новой точкой — выброс задемпфирован.
      expect(p.latitude, greaterThan(62.0));
      expect(p.latitude, lessThan(62.001));
    });

    test('серия одинаковых точек сходится к ним', () {
      final k = GpsKalman();
      for (var i = 0; i < 20; i++) {
        k.process(lat: 62.0, lng: 129.0, accuracy: 5, timestampMs: (ts += 1000));
      }
      final p = k.process(
        lat: 62.0,
        lng: 129.0,
        accuracy: 5,
        timestampMs: (ts += 1000),
      );
      expect(p.latitude, closeTo(62.0, 1e-6));
      expect(p.longitude, closeTo(129.0, 1e-6));
    });

    test('reset() возвращает фильтр в исходное состояние', () {
      final k = GpsKalman();
      k.process(lat: 62.0, lng: 129.0, accuracy: 5, timestampMs: ++ts);
      expect(k.isEmpty, isFalse);
      k.reset();
      expect(k.isEmpty, isTrue);
      // После сброса следующий фикс снова проходит как первый.
      final p = k.process(lat: 60.0, lng: 30.0, accuracy: 5, timestampMs: ++ts);
      expect(p.latitude, 60.0);
      expect(p.longitude, 30.0);
    });
  });
}
