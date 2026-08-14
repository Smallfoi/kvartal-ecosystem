import 'package:flutter_test/flutter_test.dart';
import 'package:kvartal_app/features/tools/logic/interval_plan.dart';

void main() {
  group('buildIntervalPlan', () {
    test('8 раундов 30/30: 8 работ + 7 отдыхов = 15 шагов', () {
      final plan = buildIntervalPlan(workSec: 30, restSec: 30, rounds: 8);
      expect(plan.length, 15);
      expect(plan.first.phase, IntervalPhase.work);
      expect(plan.first.round, 1);
      // последний шаг — работа последнего раунда, без хвостового отдыха
      expect(plan.last.phase, IntervalPhase.work);
      expect(plan.last.round, 8);
    });

    test('1 раунд — только работа, без отдыха', () {
      final plan = buildIntervalPlan(workSec: 60, restSec: 30, rounds: 1);
      expect(plan.length, 1);
      expect(plan.single.phase, IntervalPhase.work);
    });

    test('нулевой отдых → только шаги работы', () {
      final plan = buildIntervalPlan(workSec: 40, restSec: 0, rounds: 5);
      expect(plan.length, 5);
      expect(plan.every((s) => s.phase == IntervalPhase.work), isTrue);
    });

    test('суммарная длительность', () {
      final plan = buildIntervalPlan(workSec: 30, restSec: 30, rounds: 8);
      // 8*30 + 7*30 = 450
      expect(intervalPlanTotalSec(plan), 450);
    });

    test('чередование фаз', () {
      final plan = buildIntervalPlan(workSec: 20, restSec: 10, rounds: 3);
      // work,rest,work,rest,work
      expect(
        plan.map((s) => s.phase).toList(),
        [
          IntervalPhase.work,
          IntervalPhase.rest,
          IntervalPhase.work,
          IntervalPhase.rest,
          IntervalPhase.work,
        ],
      );
    });
  });

  group('metronomeIntervalMs', () {
    test('60 шагов/мин = 1000 мс', () {
      expect(metronomeIntervalMs(60), 1000);
    });
    test('180 шагов/мин = 333 мс', () {
      expect(metronomeIntervalMs(180), 333);
    });
    test('защита от нуля', () {
      expect(metronomeIntervalMs(0), 0);
    });
  });
}
