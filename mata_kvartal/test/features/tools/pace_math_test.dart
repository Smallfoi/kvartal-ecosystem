import 'package:flutter_test/flutter_test.dart';
import 'package:kvartal_app/features/tools/logic/pace_math.dart';

void main() {
  group('pace_math', () {
    test('скорость из темпа', () {
      // 5:00/км = 300 сек/км = 12 км/ч
      expect(speedKmhFromPace(300), closeTo(12, 0.001));
      // 6:00/км = 360 сек/км = 10 км/ч
      expect(speedKmhFromPace(360), closeTo(10, 0.001));
    });

    test('темп из скорости', () {
      expect(paceSecPerKmFromSpeed(12), closeTo(300, 0.001));
      expect(paceSecPerKmFromSpeed(10), closeTo(360, 0.001));
    });

    test('темп↔скорость — обратимость', () {
      final speed = speedKmhFromPace(330);
      expect(paceSecPerKmFromSpeed(speed), closeTo(330, 0.001));
    });

    test('время по дистанции и темпу', () {
      // 10 км в темпе 5:00 (300) = 3000 сек = 50:00
      expect(timeSecFromDistancePace(10, 300), closeTo(3000, 0.001));
      // полумарафон 21.0975 км в темпе 5:00
      expect(
        timeSecFromDistancePace(21.0975, 300),
        closeTo(6329.25, 0.01),
      );
    });

    test('темп по дистанции и времени', () {
      expect(paceSecPerKmFromDistanceTime(10, 3000), closeTo(300, 0.001));
    });

    test('дистанция по времени и темпу', () {
      expect(distanceKmFromTimePace(3000, 300), closeTo(10, 0.001));
    });

    test('форматирование темпа', () {
      expect(formatPace(300), '5:00');
      expect(formatPace(330), '5:30');
      expect(formatPace(305), '5:05');
      expect(formatPace(0), '—');
    });

    test('форматирование времени', () {
      expect(formatDuration(3000), '50:00');
      expect(formatDuration(3661), '1:01:01');
      expect(formatDuration(59), '0:59');
      expect(formatDuration(0), '—');
    });

    test('защита от нуля и отрицательных значений', () {
      expect(speedKmhFromPace(0), 0);
      expect(speedKmhFromPace(-5), 0);
      expect(paceSecPerKmFromSpeed(0), 0);
      expect(paceSecPerKmFromDistanceTime(0, 100), 0);
      expect(distanceKmFromTimePace(100, 0), 0);
    });
  });
}
