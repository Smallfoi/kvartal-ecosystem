import 'package:flutter_test/flutter_test.dart';
import 'package:liga_app/features/weather/data/weather_provider.dart';
import 'package:liga_app/features/weather/domain/run_window.dart';

HourForecast h({
  int hour = 12,
  double feels = 10,
  double wind = 5,
  int prob = 0,
  double mm = 0,
}) =>
    HourForecast(
      timeLocal: DateTime(2026, 8, 21, hour),
      tempC: feels,
      feelsLikeC: feels,
      windKmh: wind,
      precipProbPct: prob,
      precipMm: mm,
      wmo: 0,
    );

void main() {
  group('runScore', () {
    test('идеальные условия дают максимум', () {
      expect(runScore(h(hour: 18, feels: 12)), greaterThanOrEqualTo(95));
    });

    test('дождь штрафует сильнее, чем ясный час', () {
      final dry = runScore(h(feels: 12));
      final wet = runScore(h(feels: 12, prob: 80, mm: 1.5));
      expect(wet, lessThan(dry - 40));
    });

    test('якутский мороз: −29 по ощущению хуже, чем −10', () {
      expect(runScore(h(feels: -29)), lessThan(runScore(h(feels: -10))));
    });

    test('жара штрафуется жёстче лёгкой прохлады', () {
      expect(runScore(h(feels: 30)), lessThan(runScore(h(feels: 0))));
    });

    test('сильный ветер валит оценку', () {
      expect(runScore(h(wind: 35)), lessThan(runScore(h(wind: 5)) - 30));
    });

    test('глухая ночь штрафуется', () {
      expect(runScore(h(hour: 2)), lessThan(runScore(h(hour: 18))));
    });

    test('оценка в пределах 0..100', () {
      expect(runScore(h(feels: -60, wind: 60, prob: 100, mm: 10, hour: 3)), 0);
      expect(runScore(h(hour: 18, feels: 12)), lessThanOrEqualTo(100));
    });
  });

  group('bestRunWindow', () {
    test('меньше двух часов — null', () {
      expect(bestRunWindow([h()]), isNull);
      expect(bestRunWindow(const []), isNull);
    });

    test('выбирает сухой тёплый вечер, а не дождливый день', () {
      final hours = [
        for (var i = 8; i < 17; i++) h(hour: i, feels: 14, prob: 70, mm: 0.8),
        h(hour: 17, feels: 14),
        h(hour: 18, feels: 13),
        for (var i = 19; i < 24; i++) h(hour: i, feels: 8, prob: 50, mm: 0.4),
      ];
      final w = bestRunWindow(hours)!;
      expect(w.start.hour, 17);
      expect(w.end.hour, 19);
      expect(w.summary, contains('без осадков'));
    });

    test('окно не выходит за lookahead', () {
      final hours = [
        for (var i = 0; i < 24; i++)
          h(hour: i, feels: i < 20 ? -20.0 : 15.0), // «лучшие» часы в конце
      ];
      final w = bestRunWindow(hours, lookaheadHours: 12)!;
      expect(w.start.hour, lessThan(12));
    });

    test('summary формируется по первому часу окна', () {
      final w = bestRunWindow([h(hour: 17, feels: 14, wind: 4), h(hour: 18, feels: 13)])!;
      expect(w.summary, '+14° · без осадков · слабый ветер');
    });
  });
}
