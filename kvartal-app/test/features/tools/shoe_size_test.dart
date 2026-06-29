import 'package:flutter_test/flutter_test.dart';
import 'package:kvartal_app/features/tools/logic/shoe_size.dart';

void main() {
  group('sizesFromFootCm', () {
    test('EU по формуле Paris point', () {
      // (25 + 1.5) * 1.5 = 39.75
      expect(sizesFromFootCm(25).eu, closeTo(39.75, 0.001));
    });

    test('Mondopoint = длина стопы', () {
      expect(sizesFromFootCm(26).mondo, 26);
    });

    test('режим «для бега» добавляет +0.5 EU', () {
      final normal = sizesFromFootCm(25);
      final running = sizesFromFootCm(25, running: true);
      expect(running.eu, closeTo(normal.eu + 0.5, 0.001));
    });

    test('EU растёт с длиной стопы', () {
      expect(sizesFromFootCm(26).eu > sizesFromFootCm(25).eu, isTrue);
    });

    test('порядок систем: UK < US(муж) < US(жен)', () {
      final s = sizesFromFootCm(26);
      expect(s.uk < s.usMen, isTrue);
      expect(s.usMen < s.usWomen, isTrue);
    });
  });

  group('roundHalf', () {
    test('округляет до ближайшего 0.5', () {
      expect(roundHalf(39.75), 40.0);
      expect(roundHalf(40.25), 40.5);
      expect(roundHalf(7.654), 7.5);
      expect(roundHalf(41.0), 41.0);
    });
  });
}
