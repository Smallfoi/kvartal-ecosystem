import 'package:flutter_test/flutter_test.dart';
import 'package:kvartal_app/features/tools/logic/hr_zones.dart';

void main() {
  group('maxHrByAge', () {
    test('220 − возраст', () {
      expect(maxHrByAge(30), 190);
      expect(maxHrByAge(20), 200);
      expect(maxHrByAge(45), 175);
    });

    test('кламп границ', () {
      expect(maxHrByAge(140), 100); // 220−140=80 → кламп до 100
      expect(maxHrByAge(-10), 220); // 230 → кламп до 220
    });
  });

  group('hrZones — простой процент', () {
    final zones = hrZones(maxHr: 190);

    test('ровно 5 зон с индексами 1..5', () {
      expect(zones.length, 5);
      expect(zones.first.index, 1);
      expect(zones.last.index, 5);
    });

    test('границы по % от максимума', () {
      expect(zones.first.lowBpm, 95); // 50% от 190
      expect(zones.last.highBpm, 190); // 100% от 190
    });

    test('границы зон монотонно растут', () {
      for (final z in zones) {
        expect(z.lowBpm <= z.highBpm, isTrue);
      }
      for (var i = 1; i < zones.length; i++) {
        expect(zones[i].lowBpm >= zones[i - 1].lowBpm, isTrue);
      }
    });
  });

  group('hrZones — Карвонен (с пульсом покоя)', () {
    test('резерв пульса учитывается', () {
      final z = hrZones(maxHr: 190, restHr: 50);
      // Z1 low 50%: 50 + 0.5*(190−50) = 120
      expect(z.first.lowBpm, 120);
      // Z5 high 100%: 50 + 1.0*140 = 190
      expect(z.last.highBpm, 190);
    });

    test('некорректный пульс покоя → откат к простому проценту', () {
      final z = hrZones(maxHr: 190, restHr: 200); // restHr >= maxHr
      expect(z.first.lowBpm, 95);
    });
  });
}
