import '../data/weather_provider.dart';

/// «Лучшее время для пробежки» (дизайн-проект погоды, утверждён 2026-08-21).
///
/// Каждый час ближайших [lookaheadHours] получает оценку 0–100 по четырём
/// факторам (температура «ощущается как», осадки, ветер, светлое время),
/// окно — два часа подряд с максимальной суммой. Якутская специфика: зимой
/// сравниваем по ветрохолоду, а не по термометру.
class RunWindow {
  final DateTime start;
  final DateTime end; // конец окна (не включительно): start + 2 часа
  final int score; // средняя оценка окна 0..100
  final String summary; // «+14° · без осадков · слабый ветер»

  const RunWindow({
    required this.start,
    required this.end,
    required this.score,
    required this.summary,
  });
}

/// Оценка одного часа для бега: 100 — идеально, 0 — не стоит.
int runScore(HourForecast h) {
  double s = 100;

  // Температура: идеал +5…+15 по «ощущается как». Мороз мягче штрафуем
  // (в Якутске бегают и в −20), жара опаснее для бега.
  final t = h.feelsLikeC;
  if (t < 5) {
    s -= (5 - t) * 2.2;
  } else if (t > 15) {
    s -= (t - 15) * 3.0;
    if (t > 25) s -= (t - 25) * 3.0;
  }

  // Осадки — главный штраф: вероятность и фактический объём (мм/ч).
  s -= h.precipProbPct * 0.45;
  s -= h.precipMm * 22;

  // Ветер: до 10 км/ч — комфорт, дальше штраф, после 25 — усиленный.
  if (h.windKmh > 10) {
    s -= (h.windKmh - 10) * 1.4;
    if (h.windKmh > 25) s -= (h.windKmh - 25) * 1.6;
  }

  // Светлое время: глухая ночь — вниз, вечер после работы — небольшой бонус.
  final hr = h.timeLocal.hour;
  if (hr >= 23 || hr < 5) {
    s -= 28;
  } else if (hr >= 17 && hr <= 20) {
    s += 6;
  }

  return s.clamp(0, 100).round();
}

/// Лучшее двухчасовое окно в ближайших [lookaheadHours] часах.
/// null — если данных меньше двух часов.
RunWindow? bestRunWindow(List<HourForecast> hourly, {int lookaheadHours = 18}) {
  final hours = hourly.take(lookaheadHours).toList();
  if (hours.length < 2) return null;

  var bestI = 0;
  var bestSum = -1;
  for (var i = 0; i + 1 < hours.length; i++) {
    final sum = runScore(hours[i]) + runScore(hours[i + 1]);
    if (sum > bestSum) {
      bestSum = sum;
      bestI = i;
    }
  }

  final a = hours[bestI];
  final b = hours[bestI + 1];
  return RunWindow(
    start: a.timeLocal,
    end: b.timeLocal.add(const Duration(hours: 1)),
    score: (bestSum / 2).round(),
    summary: _summary(a),
  );
}

String _summary(HourForecast h) {
  final t = h.feelsLikeC.round();
  final temp = t > 0 ? '+$t°' : '$t°';
  final precip = (h.precipProbPct > 30 || h.precipMm > 0.2)
      ? 'возможны осадки'
      : 'без осадков';
  final w = h.windKmh.round();
  final wind = w < 10 ? 'слабый ветер' : 'ветер $w км/ч';
  return '$temp · $precip · $wind';
}
