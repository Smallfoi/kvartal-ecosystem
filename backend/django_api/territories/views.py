"""
Территории (D-09) на PostGIS, raw SQL.
- захват по реальному маршруту: своя территория растёт через ST_Union (расширение),
  у чужих вычитается пересечение через ST_Difference (перехват);
- сглаживание/чистка GPS при фиксации: ST_SimplifyPreserveTopology + ST_MakeValid;
- ЖИВОЙ слой (карта/рейтинг/клубы): территория живёт LIVE_TTL_HOURS (7 дней) от
  последнего забега; забег обновляет captured_at и продлевает; протухшие удаляются лениво;
- ВЕЧНЫЙ личный след (footprints): объединение всего, что юзер когда-либо пробежал —
  растёт и НЕ уменьшается (ни временем, ни перехватом). Для профиля (исследовано км²);
- античит: скорость (если клиент прислал дистанцию/время), мин/макс площадь, кулдаун;
- загрузка по видимой области (bbox), отметка mine/club/enemy.
Один владелец = одна (мульти)территория (owner_id UNIQUE).
"""
import json
import secrets

from django.db import connection, transaction
from rest_framework.decorators import api_view
from rest_framework.response import Response

from clubs.models import ClubMember
from common.security import user_id_from_request
from loyalty.models import LoyaltyTransaction, add_txn

# Валидный сглаженный captured-полигон из WKT (упрощение ~5 м, фикс самопересечений,
# извлекаем только полигоны и оборачиваем в MultiPolygon).
_CAP = (
    "ST_Multi(ST_CollectionExtract("
    "ST_MakeValid(ST_SimplifyPreserveTopology(ST_GeomFromText(%s,4326),0.00005)),3))"
)

# Живой слой территорий держится 7 дней без подтверждения забегом (мягкий распад).
# (имя HOLD_HOURS сохраняем — его импортирует leaderboard для фильтра свежести.)
HOLD_HOURS = 168
# Защита свежего захвата (Вариант Б, D-14): кусок, захваченный за последние
# PROTECT_HOURS, нельзя перехватить. Окно подкрутим по живому тесту.
PROTECT_HOURS = 24
# Античит.
MIN_CAPTURE_AREA_M2 = 100  # меньше — это не реальная петля, а дрожь GPS
MAX_CAPTURE_AREA_M2 = 2_000_000  # 2 км² за один забег — неправдоподобно (спуфинг/телепорт)
MAX_SPEED_MS = 11.2  # ~40 км/ч — серверный потолок скорости (см. CLAUDE.md)
CAPTURE_COOLDOWN_S = 30  # защита от спама захватами
TERRITORY_POINTS = 50  # очки за захват (анти-чит S-04: начисляет сервер, не клиент)


def _club_of(uid):
    m = ClubMember.objects.filter(user_id=uid).first()
    return m.club_id if m else None


@api_view(["POST"])
def capture(request):
    uid = user_id_from_request(request)
    if not uid:
        return Response({"detail": "Нет токена"}, status=401)
    pts = request.data.get("points") or []
    if len(pts) < 3:
        return Response({"detail": "Маршрут слишком короткий для территории"}, status=400)
    # Лимит на размер payload (P0 безопасность): защита от DoS-полигона. Даже ультра-забег
    # после клиентской фильтрации (точка/5м) — тысячи точек, не десятки тысяч.
    if len(pts) > 20_000:
        return Response({"detail": "Слишком много точек в маршруте"}, status=400)

    # Античит по скорости: клиент опционально шлёт дистанцию и время забега.
    distance = request.data.get("distanceMeters")
    elapsed = request.data.get("elapsedSeconds")
    try:
        if distance is not None and elapsed is not None:
            distance = float(distance)
            elapsed = float(elapsed)
            if elapsed > 0 and distance / elapsed > MAX_SPEED_MS:
                return Response(
                    {"detail": "Слишком высокая скорость для забега — захват отклонён."},
                    status=400,
                )
    except (TypeError, ValueError):
        pass  # некорректные числа просто игнорируем, не блокируем легитимный захват

    ring = [(float(p[1]), float(p[0])) for p in pts]  # (lng, lat)
    if ring[0] != ring[-1]:
        ring.append(ring[0])
    wkt = "POLYGON((" + ", ".join(f"{lng} {lat}" for lng, lat in ring) + "))"
    club_id = _club_of(uid)
    # Идемпотентность (S-04): клиент шлёт captureId; повтор (ретрай офлайн-очереди)
    # не применяем заново — отдаём текущую территорию.
    capture_id = (str(request.data.get("captureId") or "")).strip()[:64] or None
    with transaction.atomic():
        with connection.cursor() as cur:
            # 0a) дедуп по captureId — ДО кулдауна и любых изменений
            if capture_id:
                cur.execute(
                    "INSERT INTO processed_captures (capture_id, owner_id) "
                    "VALUES (%s, %s) ON CONFLICT (capture_id) DO NOTHING",
                    [capture_id, uid],
                )
                if cur.rowcount == 0:
                    cur.execute(
                        "SELECT ST_AsGeoJSON(geom), ST_Area(geom::geography) "
                        "FROM territories WHERE owner_id=%s",
                        [uid],
                    )
                    row = cur.fetchone()
                    if row:
                        gj, area = row
                        return Response({
                            "ok": True, "duplicate": True, "areaM2": area,
                            "geojson": json.loads(gj), "holdHoursLeft": HOLD_HOURS,
                        })
                    return Response({"ok": True, "duplicate": True, "areaM2": 0, "geojson": None})
            # 0) лениво убираем протухшие (>72ч без обновления) — освобождаем карту
            cur.execute(
                "DELETE FROM territories WHERE captured_at <= now() - make_interval(hours => %s)",
                [HOLD_HOURS],
            )
            # 1) материализуем валидный сглаженный контур ОДИН раз (переиспользуем)
            cur.execute(f"SELECT ST_AsEWKT({_CAP})", [wkt])
            cap_ewkt = (cur.fetchone() or [None])[0]
            if not cap_ewkt:
                return Response({"detail": "Не удалось обработать контур забега."}, status=400)
            # 2) античит по площади контура (по полному контуру забега)
            cur.execute("SELECT ST_Area(ST_GeomFromEWKT(%s)::geography)", [cap_ewkt])
            cap_area = (cur.fetchone() or [0])[0] or 0
            if cap_area < MIN_CAPTURE_AREA_M2:
                return Response(
                    {
                        "detail": f"Слишком маленькая территория ({round(cap_area)} м²). "
                        f"Замкни контур побольше."
                    },
                    status=400,
                )
            if cap_area > MAX_CAPTURE_AREA_M2:
                return Response(
                    {"detail": "Слишком большая территория за один забег — захват отклонён."},
                    status=400,
                )
            # 3) кулдаун: не чаще раза в CAPTURE_COOLDOWN_S секунд
            cur.execute(
                "SELECT 1 FROM territories WHERE owner_id=%s "
                "AND captured_at > now() - make_interval(secs => %s)",
                [uid, CAPTURE_COOLDOWN_S],
            )
            if cur.fetchone():
                return Response(
                    {"detail": "Слишком частый захват — подожди немного."},
                    status=429,
                )
            # 4) защита 24ч (Вариант Б): из контура вычитаем ЧУЖИЕ защищённые куски
            #    (recent_captures моложе PROTECT_HOURS) → effective = что реально берём.
            cur.execute(
                "DELETE FROM recent_captures WHERE captured_at <= now() - make_interval(hours => %s)",
                [PROTECT_HOURS],
            )
            cur.execute(
                "SELECT ST_AsEWKT(ST_Multi(ST_CollectionExtract(ST_Difference("
                "  ST_GeomFromEWKT(%s),"
                "  COALESCE((SELECT ST_Union(geom) FROM recent_captures "
                "    WHERE owner_id <> %s AND captured_at > now() - make_interval(hours => %s) "
                "      AND ST_Intersects(geom, ST_GeomFromEWKT(%s))),"
                "    'SRID=4326;GEOMETRYCOLLECTION EMPTY'::geometry)"
                "),3)))",
                [cap_ewkt, uid, PROTECT_HOURS, cap_ewkt],
            )
            eff_ewkt = (cur.fetchone() or [None])[0]
            has_gain = bool(eff_ewkt) and "EMPTY" not in eff_ewkt.upper()
            # 5) перехват: срезаем у чужих ТОЛЬКО незащищённую часть (effective)
            if has_gain:
                cur.execute(
                    "UPDATE territories SET geom = ST_Multi(ST_CollectionExtract("
                    "ST_Difference(geom, ST_GeomFromEWKT(%s)),3)) "
                    "WHERE owner_id <> %s AND ST_Intersects(geom, ST_GeomFromEWKT(%s))",
                    [eff_ewkt, uid, eff_ewkt],
                )
                cur.execute("DELETE FROM territories WHERE ST_IsEmpty(geom) OR ST_Area(geom)=0")
                # 6) своя территория: union с тем, что реально взяли (effective)
                cur.execute("SELECT 1 FROM territories WHERE owner_id=%s", [uid])
                if cur.fetchone():
                    cur.execute(
                        "UPDATE territories SET geom = ST_Multi(ST_CollectionExtract("
                        "ST_Union(geom, ST_GeomFromEWKT(%s)),3)), club_id=%s, captured_at=now() "
                        "WHERE owner_id=%s",
                        [eff_ewkt, club_id, uid],
                    )
                else:
                    cur.execute(
                        "INSERT INTO territories (id,owner_id,club_id,geom,captured_at) "
                        "VALUES (%s,%s,%s,ST_GeomFromEWKT(%s),now())",
                        [f"t_{secrets.token_hex(8)}", uid, club_id, eff_ewkt],
                    )
                # 6a) свежий кусок под защиту 24ч (recent_captures = что реально взяли)
                cur.execute(
                    "INSERT INTO recent_captures (owner_id, geom) VALUES (%s, ST_GeomFromEWKT(%s))",
                    [uid, eff_ewkt],
                )
            # 7) вечный личный след: union ПОЛНОГО контура (бежал везде, даже где не взял)
            cur.execute("SELECT 1 FROM footprints WHERE owner_id=%s", [uid])
            if cur.fetchone():
                cur.execute(
                    "UPDATE footprints SET geom = ST_Multi(ST_CollectionExtract("
                    "ST_Union(geom, ST_GeomFromEWKT(%s)),3)), updated_at=now() WHERE owner_id=%s",
                    [cap_ewkt, uid],
                )
            else:
                cur.execute(
                    "INSERT INTO footprints (owner_id,geom,updated_at) "
                    "VALUES (%s,ST_GeomFromEWKT(%s),now())",
                    [uid, cap_ewkt],
                )
            cur.execute(
                "SELECT ST_AsGeoJSON(geom), ST_Area(geom::geography) "
                "FROM territories WHERE owner_id=%s",
                [uid],
            )
            row = cur.fetchone()
            gj, area = (row[0], row[1]) if row else (None, 0)
            if capture_id:
                cur.execute(
                    "UPDATE processed_captures SET area_m2=%s WHERE capture_id=%s",
                    [area, capture_id],
                )
        # Очки за захват начисляет СЕРВЕР (анти-чит S-04 Phase 2), идемпотентно по
        # captureId. Дубликаты захвата сюда не доходят (выходят раньше), но проверку
        # по транзакции оставляем как страховку от рассинхрона.
        if capture_id and not LoyaltyTransaction.objects.filter(
            user_id=uid, run_id=capture_id, source="runnerTerritory"
        ).exists():
            add_txn(uid, TERRITORY_POINTS, "runnerTerritory",
                    "Захват территории", None, capture_id)
    return Response(
        {
            "ok": True,
            "areaM2": round(area or 0),
            "geojson": json.loads(gj) if gj else None,
            "holdHoursLeft": HOLD_HOURS,
        }
    )


@api_view(["GET"])
def list_territories(request):
    uid = user_id_from_request(request)
    if not uid:
        return Response({"detail": "Нет токена"}, status=401)
    my_club = _club_of(uid)
    bbox = request.query_params.get("bbox")
    # На отдалённом виде упрощаем геометрию сильнее (легче и быстрее).
    simplify = "ST_SimplifyPreserveTopology(geom,0.00003)"
    # Остаток удержания в часах (для UI «защищено ещё Nч»).
    hold_left = (
        "EXTRACT(EPOCH FROM (captured_at + make_interval(hours => %s) - now())) / 3600.0"
    )
    cols = f"owner_id, club_id, ST_AsGeoJSON({simplify}), {hold_left}"
    # Активны только территории, удерживаемые < 72ч назад.
    fresh = "captured_at > now() - make_interval(hours => %s)"
    with connection.cursor() as cur:
        if bbox:
            try:
                a, b, c, d = (float(x) for x in bbox.split(","))
            except Exception:
                return Response({"detail": "bbox=minLng,minLat,maxLng,maxLat"}, status=400)
            cur.execute(
                f"SELECT {cols} FROM territories "
                f"WHERE {fresh} AND geom && ST_MakeEnvelope(%s,%s,%s,%s,4326)",
                [HOLD_HOURS, HOLD_HOURS, a, b, c, d],
            )
        else:
            cur.execute(
                f"SELECT {cols} FROM territories WHERE {fresh}",
                [HOLD_HOURS, HOLD_HOURS],
            )
        rows = cur.fetchall()
    out = []
    for owner_id, club_id, gj, hours_left in rows:
        rel = "mine" if owner_id == uid else (
            "club" if club_id and club_id == my_club else "enemy"
        )
        out.append(
            {
                "ownerId": owner_id,
                "clubId": club_id,
                "rel": rel,
                "holdHoursLeft": round(max(0.0, float(hours_left or 0)), 1),
                "geojson": json.loads(gj),
            }
        )
    return Response({"territories": out})


@api_view(["GET"])
def footprint(request):
    """Вечный личный след: вся когда-либо пробежанная площадь (не уменьшается).
    Для профиля — «исследовано N км²». geojson — упрощённый контур для будущей heatmap."""
    uid = user_id_from_request(request)
    if not uid:
        return Response({"detail": "Нет токена"}, status=401)
    with connection.cursor() as cur:
        cur.execute(
            "SELECT ST_Area(geom::geography), "
            "ST_AsGeoJSON(ST_SimplifyPreserveTopology(geom,0.00005)) "
            "FROM footprints WHERE owner_id=%s",
            [uid],
        )
        row = cur.fetchone()
    if not row:
        return Response({"areaM2": 0, "geojson": None})
    area, gj = row
    return Response(
        {"areaM2": round(area or 0), "geojson": json.loads(gj) if gj else None}
    )
