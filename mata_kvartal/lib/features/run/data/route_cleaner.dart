import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Чистка ГОТОВОГО GPS-трека перед сохранением и захватом территории
/// («Идеальный маршрут», 03.09.2026). Два прохода:
///
/// 1. Срез шипов: точка-выброс — это разворот почти на 180° с длинными
///    плечами (маршрут «выстрелил» в сторону и вернулся). Живой поворот
///    бегуна таким не бывает: у него плечи короткие ИЛИ угол тупее.
/// 2. Упрощение Дугласа-Пекера (~3 м): меньше точек в захват, ровнее линия.
///
/// Работает по индексам, чтобы вызывающий мог согласованно отфильтровать
/// параллельные массивы (в Лиге рядом с маршрутом живут времена точек).

const _spikeArmMeters = 30.0; // минимальная длина плеч разворота
const _spikeAngleDeg = 30.0; // угол при вершине острее этого = шип
const _rdpToleranceMeters = 3.0;
const _maxDespikePasses = 3;

/// Индексы точек, которые остаются после чистки. Порядок сохранён.
List<int> cleanRouteKeepIndices(List<LatLng> route) {
  if (route.length < 3) {
    return [for (var i = 0; i < route.length; i++) i];
  }
  // Локальная равнопромежуточная проекция: метры вокруг центра трека.
  final lat0 = route.first.latitude * math.pi / 180;
  final kx = 111320.0 * math.cos(lat0);
  const ky = 110540.0;
  final xs = [for (final p in route) p.longitude * kx];
  final ys = [for (final p in route) p.latitude * ky];

  var keep = [for (var i = 0; i < route.length; i++) i];

  // Проход 1: срезаем шипы (несколько проходов — вершина иглы бывает из
  // двух-трёх точек, за проход уходит по одной).
  for (var pass = 0; pass < _maxDespikePasses; pass++) {
    final next = <int>[keep.first];
    var removed = false;
    for (var j = 1; j < keep.length - 1; j++) {
      final a = next.last, b = keep[j], c = keep[j + 1];
      final abx = xs[b] - xs[a], aby = ys[b] - ys[a];
      final cbx = xs[b] - xs[c], cby = ys[b] - ys[c];
      final ab = math.sqrt(abx * abx + aby * aby);
      final cb = math.sqrt(cbx * cbx + cby * cby);
      if (ab > _spikeArmMeters && cb > _spikeArmMeters) {
        final cosAngle = (abx * cbx + aby * cby) / (ab * cb);
        final angleDeg = math.acos(cosAngle.clamp(-1.0, 1.0)) * 180 / math.pi;
        if (angleDeg < _spikeAngleDeg) {
          removed = true;
          continue; // выброс — точку не берём
        }
      }
      next.add(b);
    }
    next.add(keep.last);
    keep = next;
    if (!removed) break;
  }

  // Проход 2: Дуглас-Пекер по оставшимся.
  final kept = _rdp(keep, xs, ys);
  return kept;
}

/// Удобная форма: сразу чистый маршрут.
List<LatLng> cleanRoute(List<LatLng> route) =>
    [for (final i in cleanRouteKeepIndices(route)) route[i]];

List<int> _rdp(List<int> idx, List<double> xs, List<double> ys) {
  if (idx.length < 3) return idx;
  final marked = <int>{idx.first, idx.last};
  final stack = <(int, int)>[(0, idx.length - 1)];
  while (stack.isNotEmpty) {
    final (lo, hi) = stack.removeLast();
    final a = idx[lo], b = idx[hi];
    var maxD = -1.0;
    var maxJ = -1;
    for (var j = lo + 1; j < hi; j++) {
      final d = _pointToSegment(
        xs[idx[j]], ys[idx[j]], xs[a], ys[a], xs[b], ys[b]);
      if (d > maxD) {
        maxD = d;
        maxJ = j;
      }
    }
    if (maxD > _rdpToleranceMeters && maxJ > 0) {
      marked.add(idx[maxJ]);
      stack.add((lo, maxJ));
      stack.add((maxJ, hi));
    }
  }
  return [for (final i in idx) if (marked.contains(i)) i];
}

double _pointToSegment(
    double px, double py, double ax, double ay, double bx, double by) {
  final dx = bx - ax, dy = by - ay;
  final len2 = dx * dx + dy * dy;
  if (len2 == 0) {
    return math.sqrt((px - ax) * (px - ax) + (py - ay) * (py - ay));
  }
  var t = ((px - ax) * dx + (py - ay) * dy) / len2;
  t = t.clamp(0.0, 1.0);
  final qx = ax + t * dx, qy = ay + t * dy;
  return math.sqrt((px - qx) * (px - qx) + (py - qy) * (py - qy));
}
