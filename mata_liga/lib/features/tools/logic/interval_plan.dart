/// Чистая логика интервального таймера: построение последовательности фаз.
/// Без UI и зависимостей — легко тестируется.
library;

enum IntervalPhase { work, rest }

/// Один шаг плана: фаза, номер раунда (с 1) и длительность в секундах.
class IntervalStep {
  final IntervalPhase phase;
  final int round;
  final int seconds;
  const IntervalStep({
    required this.phase,
    required this.round,
    required this.seconds,
  });
}

/// Строит план: для каждого раунда — работа, затем отдых.
/// Отдых после последнего раунда НЕ добавляется. Нулевые длительности пропускаются.
List<IntervalStep> buildIntervalPlan({
  required int workSec,
  required int restSec,
  required int rounds,
}) {
  final steps = <IntervalStep>[];
  for (var r = 1; r <= rounds; r++) {
    if (workSec > 0) {
      steps.add(IntervalStep(phase: IntervalPhase.work, round: r, seconds: workSec));
    }
    if (restSec > 0 && r < rounds) {
      steps.add(IntervalStep(phase: IntervalPhase.rest, round: r, seconds: restSec));
    }
  }
  return steps;
}

/// Суммарная длительность плана в секундах.
int intervalPlanTotalSec(List<IntervalStep> plan) =>
    plan.fold(0, (sum, step) => sum + step.seconds);

/// Интервал метронома (миллисекунд между ударами) для каденса [spm] (шагов/мин).
int metronomeIntervalMs(int spm) {
  if (spm <= 0) return 0;
  return (60000 / spm).round();
}
