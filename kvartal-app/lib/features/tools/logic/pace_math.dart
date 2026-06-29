/// Чистая математика для бегового конвертера: темп ↔ скорость и связка
/// дистанция / время / темп. Без UI и зависимостей — легко тестируется.
///
/// Темп везде хранится как «секунд на километр» (double), скорость — км/ч.
library;

/// Скорость (км/ч) из темпа (секунд на километр). 0 при некорректном вводе.
double speedKmhFromPace(double secPerKm) {
  if (secPerKm <= 0) return 0;
  return 3600 / secPerKm;
}

/// Темп (секунд на километр) из скорости (км/ч). 0 при некорректном вводе.
double paceSecPerKmFromSpeed(double kmh) {
  if (kmh <= 0) return 0;
  return 3600 / kmh;
}

/// Время (секунды) на дистанцию [km] в темпе [secPerKm].
double timeSecFromDistancePace(double km, double secPerKm) => km * secPerKm;

/// Темп (сек/км) по дистанции [km] и времени [timeSec].
double paceSecPerKmFromDistanceTime(double km, double timeSec) {
  if (km <= 0) return 0;
  return timeSec / km;
}

/// Дистанция (км) по времени [timeSec] и темпу [secPerKm].
double distanceKmFromTimePace(double timeSec, double secPerKm) {
  if (secPerKm <= 0) return 0;
  return timeSec / secPerKm;
}

/// Темп в формате «м:сс» из секунд на километр. «—» при некорректном вводе.
String formatPace(double secPerKm) {
  if (secPerKm <= 0 || secPerKm.isInfinite || secPerKm.isNaN) return '—';
  final total = secPerKm.round();
  final m = total ~/ 60;
  final s = total % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Время «ч:мм:сс» (или «м:сс», если меньше часа) из секунд.
String formatDuration(double seconds) {
  if (seconds <= 0 || seconds.isInfinite || seconds.isNaN) return '—';
  final total = seconds.round();
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '$m:${s.toString().padLeft(2, '0')}';
}
