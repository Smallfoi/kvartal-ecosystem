import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/data/me_stats_provider.dart';
import '../../run/data/completed_runs_provider.dart';

/// Уровни бегуна по пожизненным километрам (Ф4, утверждено 31.08.2026).
///
/// Уровень никогда не отбирается: километры только копятся. Номер дивизиона —
/// сверху вниз, как в FIFA Rivals: «Лайм» = I, новичок в «Асфальте» = VII.
enum RunnerLevel {
  asphalt('Асфальт', 0),
  dvory('Дворы', 50),
  ulitsa('Улица', 250),
  prospekt('Проспект', 1000),
  rayon('Район', 2500),
  gorod('Город', 5000),
  lime('Лайм', 15000);

  final String title;

  /// Нижняя граница уровня, пожизненные км.
  final int minKm;

  const RunnerLevel(this.title, this.minKm);

  static RunnerLevel fromKm(double km) {
    var level = RunnerLevel.asphalt;
    for (final l in RunnerLevel.values) {
      if (km >= l.minKm) level = l;
    }
    return level;
  }

  /// Номер дивизиона (I — высший «Лайм», VII — стартовый «Асфальт»).
  String get roman =>
      const ['VII', 'VI', 'V', 'IV', 'III', 'II', 'I'][index];

  /// Следующий уровень (null на «Лайме» — статус вечный, потолка нет).
  RunnerLevel? get next =>
      this == RunnerLevel.lime ? null : RunnerLevel.values[index + 1];
}

/// Уровень текущего бегуна — из пожизненных км общего бэка (/me/stats).
final runnerLevelProvider = FutureProvider.autoDispose<RunnerLevel>((ref) async {
  final stats = await ref.watch(meStatsProvider.future);
  return RunnerLevel.fromKm(stats.totalKm);
});

/// Форма недели: пн–вс, был ли в этот день бег (по локальной истории пробежек).
final weekFormProvider = Provider.autoDispose<List<bool>>((ref) {
  final runs = ref.watch(completedRunsProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final monday = today.subtract(Duration(days: today.weekday - 1));
  final form = List<bool>.filled(7, false);
  for (final run in runs) {
    final d = DateTime(
      run.finishedAt.year,
      run.finishedAt.month,
      run.finishedAt.day,
    );
    final diff = d.difference(monday).inDays;
    if (diff >= 0 && diff < 7) form[diff] = true;
  }
  return form;
});
