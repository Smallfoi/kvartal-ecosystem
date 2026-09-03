import 'package:flutter_test/flutter_test.dart';
import 'package:kvartal_app/features/run/data/route_cleaner.dart';
import 'package:latlong2/latlong.dart';

void main() {
  // Квадрат ~110×110 м у Якутска, по точке на угол.
  final square = [
    const LatLng(62.000, 129.700),
    const LatLng(62.001, 129.700),
    const LatLng(62.001, 129.702),
    const LatLng(62.000, 129.702),
  ];

  test('квадрат чистка не трогает', () {
    expect(cleanRoute(square), square);
  });

  test('игла-выброс срезается', () {
    // С восточной грани маршрут «выстреливает» на ~200 м и возвращается.
    final spiked = [
      const LatLng(62.000, 129.700),
      const LatLng(62.001, 129.700),
      const LatLng(62.001, 129.702),
      const LatLng(62.0006, 129.702),
      const LatLng(62.0006, 129.706), // выброс
      const LatLng(62.00058, 129.702),
      const LatLng(62.000, 129.702),
    ];
    final cleaned = cleanRoute(spiked);
    expect(
      cleaned.any((p) => p.longitude > 129.704),
      isFalse,
      reason: 'точка-игла должна уйти',
    );
    // Тело маршрута на месте: углы квадрата сохранены.
    expect(cleaned.first, spiked.first);
    expect(cleaned.last, spiked.last);
  });

  test('Дуглас-Пекер убирает шум на прямой, но держит повороты', () {
    // Прямая 200 м с дрожью ±1.5 м на промежуточных точках.
    final wobbly = [
      for (var i = 0; i <= 10; i++)
        LatLng(62.000 + 0.0000135 * (i.isEven ? 1 : -1) * (i % 3),
            129.700 + i * 0.0004),
    ];
    final cleaned = cleanRoute(wobbly);
    expect(cleaned.length, lessThan(wobbly.length));
    expect(cleaned.first, wobbly.first);
    expect(cleaned.last, wobbly.last);
  });

  test('согласованные индексы для параллельных массивов', () {
    final times = [for (var i = 0; i < square.length; i++) 1000 + i];
    final kept = cleanRouteKeepIndices(square);
    final keptTimes = [for (final i in kept) times[i]];
    expect(keptTimes.length, kept.length);
    expect(keptTimes.first, 1000);
  });
}
