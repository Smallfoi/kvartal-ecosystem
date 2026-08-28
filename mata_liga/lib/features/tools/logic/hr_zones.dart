/// Чистая логика пульсовых зон. Без UI и зависимостей — легко тестируется.
///
/// Формулы рекомендательные: максимум пульса по возрасту (220 − возраст),
/// зоны — проценты от максимума или метод Карвонена (если задан пульс покоя).
library;

/// Максимальный пульс по возрасту (220 − возраст), кламп в диапазон [100; 220].
int maxHrByAge(int age) {
  final hr = 220 - age;
  if (hr < 100) return 100;
  if (hr > 220) return 220;
  return hr;
}

/// Одна пульсовая зона: индекс (1..5), название, назначение, границы в уд/мин и %.
class HrZone {
  final int index;
  final String name;
  final String purpose;
  final int lowBpm;
  final int highBpm;
  final int lowPct;
  final int highPct;

  const HrZone({
    required this.index,
    required this.name,
    required this.purpose,
    required this.lowBpm,
    required this.highBpm,
    required this.lowPct,
    required this.highPct,
  });
}

const _zoneBounds = <({int low, int high, String name, String purpose})>[
  (low: 50, high: 60, name: 'Z1 · Восстановление', purpose: 'разминка, заминка, лёгкий бег'),
  (low: 60, high: 70, name: 'Z2 · Жиросжигание', purpose: 'аэробная база, долгий спокойный бег'),
  (low: 70, high: 80, name: 'Z3 · Аэробная', purpose: 'выносливость, темповый бег'),
  (low: 80, high: 90, name: 'Z4 · Порог', purpose: 'на грани, интервалы'),
  (low: 90, high: 100, name: 'Z5 · Максимум', purpose: 'предельная нагрузка, короткие отрезки'),
];

/// Пять пульсовых зон. Если задан корректный [restHr] (0 < restHr < maxHr) —
/// считаем по методу Карвонена (резерв пульса), иначе — простой % от [maxHr].
List<HrZone> hrZones({required int maxHr, int? restHr}) {
  final useKarvonen = restHr != null && restHr > 0 && restHr < maxHr;

  int bpmAt(int pct) {
    if (useKarvonen) {
      return (restHr + (maxHr - restHr) * pct / 100).round();
    }
    return (maxHr * pct / 100).round();
  }

  return [
    for (var i = 0; i < _zoneBounds.length; i++)
      HrZone(
        index: i + 1,
        name: _zoneBounds[i].name,
        purpose: _zoneBounds[i].purpose,
        lowPct: _zoneBounds[i].low,
        highPct: _zoneBounds[i].high,
        lowBpm: bpmAt(_zoneBounds[i].low),
        highBpm: bpmAt(_zoneBounds[i].high),
      ),
  ];
}
