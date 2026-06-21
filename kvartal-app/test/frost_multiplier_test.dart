import 'package:flutter_test/flutter_test.dart';
import 'package:kvartal_app/features/weather/data/weather_provider.dart';

void main() {
  group('frostMultiplier (морозный коэффициент)', () {
    test('тепло/умеренный холод → без бонуса (×1.0)', () {
      expect(frostMultiplier(20), 1.0);
      expect(frostMultiplier(0), 1.0);
      expect(frostMultiplier(-10), 1.0); // порог — ещё без бонуса
    });

    test('мороз → растущий бонус', () {
      expect(frostMultiplier(-20), 1.2);
      expect(frostMultiplier(-30), 1.4);
      expect(frostMultiplier(-24), 1.28);
    });

    test('экстремальный холод → потолок ×2.0', () {
      expect(frostMultiplier(-60), 2.0);
      expect(frostMultiplier(-100), 2.0);
    });

    test('Weather.multiplier берёт коэффициент из температуры', () {
      expect(const Weather(-30).multiplier, 1.4);
      expect(const Weather(15).multiplier, 1.0);
    });
  });
}
