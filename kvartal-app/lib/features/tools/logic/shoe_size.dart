/// Чистая логика подбора размера кроссовок из длины стопы (см).
///
/// Все формулы ПРИБЛИЗИТЕЛЬНЫЕ (ориентир): у разных брендов размерные сетки
/// отличаются, поэтому в UI всегда есть подсказка «сверяйтесь с таблицей бренда».
/// Сырые значения не округлены — округление до 0.5 делается при показе ([roundHalf]).
library;

/// Набор размеров для одной длины стопы.
class ShoeSizes {
  final double footCm; // длина стопы, см
  final double mondo; // Mondopoint (= длина стопы в см)
  final double eu; // Paris point
  final double uk;
  final double usMen;
  final double usWomen;

  const ShoeSizes({
    required this.footCm,
    required this.mondo,
    required this.eu,
    required this.uk,
    required this.usMen,
    required this.usWomen,
  });
}

/// Размеры из длины стопы [footCm]. Если [running] = true — добавляем +0.5 EU
/// («для бега берут чуть больше», стопа отекает на длинной дистанции).
ShoeSizes sizesFromFootCm(double footCm, {bool running = false}) {
  // Paris point: EU = длина колодки * 1.5; колодка = стопа + ~1.5 см припуска.
  var eu = (footCm + 1.5) * 1.5;
  if (running) eu += 0.5;
  // UK из EU: EU ≈ UK * 1.27 + 31.3  →  UK = (EU − 31.3) / 1.27
  final uk = (eu - 31.3) / 1.27;
  final usMen = uk + 1; // US (муж) ≈ UK + 1
  final usWomen = usMen + 1.5; // US (жен) ≈ US (муж) + 1.5
  return ShoeSizes(
    footCm: footCm,
    mondo: footCm,
    eu: eu,
    uk: uk,
    usMen: usMen,
    usWomen: usWomen,
  );
}

/// Округление размера до ближайшего 0.5 — для показа в интерфейсе.
double roundHalf(double v) => (v * 2).round() / 2;
