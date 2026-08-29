"""Сверка трека с тропой: прошёл ли человек по ней и за сколько.

Задача звучит просто, но у неё есть цена ошибки в обе стороны. Засчитаем лишнее —
в таблице появится тот, кто рядом проехал на велосипеде. Не засчитаем настоящее —
человек пробежал свою тропу, а приложение сделало вид, что ничего не было; второй
раз он проверять не станет.

Поэтому правил четыре, и все они про здравый смысл:
  1. трек заходит в начало тропы и выходит из её конца — именно в этом порядке;
  2. между ними трек действительно идёт ПО тропе, а не мимо: почти каждая точка
     тропы должна быть кем-то из точек трека «накрыта»;
  3. время считаем от входа до выхода, а не по всему забегу;
  4. невозможная скорость — не попытка.
"""
import math

# Допуск в метрах. Городской GPS в застройке врёт на 10–20 м, поэтому 40 —
# это «человек бежал здесь», а не «человек бежал в соседнем квартале».
TOLERANCE_M = 40.0

# Какую долю точек тропы трек должен накрыть, чтобы считаться прохождением.
# Ниже 0.8 начинают засчитываться срезки: пробежал половину, обрезал угол.
COVERAGE = 0.8

# Быстрее этого человек не бежит. Совпадает с проверкой забегов (S-04).
MAX_SPEED_MS = 40_000 / 3600.0   # 40 км/ч


def haversine_m(a_lat, a_lon, b_lat, b_lon) -> float:
    """Расстояние между двумя точками на земле, в метрах."""
    r = 6371000.0
    p1 = math.radians(a_lat)
    p2 = math.radians(b_lat)
    dp = math.radians(b_lat - a_lat)
    dl = math.radians(b_lon - a_lon)
    h = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(min(1.0, math.sqrt(h)))


def line_length_m(points) -> float:
    total = 0.0
    for i in range(1, len(points)):
        total += haversine_m(points[i - 1][0], points[i - 1][1], points[i][0], points[i][1])
    return total


def bbox(points):
    """Рамка вокруг линии — по ней ищем тропы рядом, без геоиндекса."""
    lats = [p[0] for p in points]
    lons = [p[1] for p in points]
    return min(lats), max(lats), min(lons), max(lons)


def _nearest_index(track, lat, lon, start_from=0):
    """Ближайшая к точке позиция в треке (и расстояние до неё)."""
    best_i, best_d = -1, float("inf")
    for i in range(start_from, len(track)):
        d = haversine_m(track[i][0], track[i][1], lat, lon)
        if d < best_d:
            best_d, best_i = d, i
    return best_i, best_d


def _covered(trail_points, track_slice) -> float:
    """Доля точек тропы, рядом с которыми прошёл трек.

    Именно так проверяется «бежал по тропе, а не мимо»: срезанный угол оставит
    часть точек тропы без пары.
    """
    if not trail_points:
        return 0.0
    hit = 0
    for lat, lon in trail_points:
        for t in track_slice:
            if haversine_m(t[0], t[1], lat, lon) <= TOLERANCE_M:
                hit += 1
                break
    return hit / len(trail_points)


def match(trail_points, track):
    """Найти прохождение тропы в треке.

    track — список [lat, lon, ms]. Возвращает {startIndex, endIndex, startedAtMs,
    durationS} или None, если прохождения нет.
    """
    if len(trail_points) < 2 or len(track) < 2:
        return None

    start_lat, start_lon = trail_points[0][0], trail_points[0][1]
    end_lat, end_lon = trail_points[-1][0], trail_points[-1][1]

    i_start, d_start = _nearest_index(track, start_lat, start_lon)
    if i_start < 0 or d_start > TOLERANCE_M:
        return None

    # Финиш ищем ПОСЛЕ старта: тропа проходится в свою сторону, обратное
    # направление — это другая тропа, а не рекорд на этой.
    i_end, d_end = _nearest_index(track, end_lat, end_lon, start_from=i_start + 1)
    if i_end < 0 or d_end > TOLERANCE_M:
        return None

    piece = track[i_start:i_end + 1]
    if _covered(trail_points, piece) < COVERAGE:
        return None

    started_ms = track[i_start][2]
    ended_ms = track[i_end][2]
    duration_s = max(0, int((ended_ms - started_ms) / 1000))
    if duration_s <= 0:
        return None

    length = line_length_m(trail_points)
    if length / duration_s > MAX_SPEED_MS:
        return None   # так не бегают — это транспорт

    return {
        "startIndex": i_start,
        "endIndex": i_end,
        "startedAtMs": started_ms,
        "durationS": duration_s,
    }


def simplify(points, min_gap_m=15.0):
    """Прорядить линию: соседние точки ближе 15 м ничего не добавляют, а сверку
    замедляют. Первую и последнюю точки сохраняем всегда — по ним ищется вход и выход."""
    if len(points) < 3:
        return list(points)
    out = [points[0]]
    for p in points[1:-1]:
        if haversine_m(out[-1][0], out[-1][1], p[0], p[1]) >= min_gap_m:
            out.append(p)
    out.append(points[-1])
    return out
