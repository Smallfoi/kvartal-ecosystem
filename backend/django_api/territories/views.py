"""
Территории (D-09) на PostGIS, raw SQL.
- захват по реальному маршруту: своя территория растёт через ST_Union (расширение),
  у чужих вычитается пересечение через ST_Difference (перехват);
- сглаживание/чистка GPS при фиксации: ST_SimplifyPreserveTopology + ST_MakeValid;
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

# Валидный сглаженный captured-полигон из WKT (упрощение ~5 м, фикс самопересечений,
# извлекаем только полигоны и оборачиваем в MultiPolygon).
_CAP = (
    "ST_Multi(ST_CollectionExtract("
    "ST_MakeValid(ST_SimplifyPreserveTopology(ST_GeomFromText(%s,4326),0.00005)),3))"
)


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
    ring = [(float(p[1]), float(p[0])) for p in pts]  # (lng, lat)
    if ring[0] != ring[-1]:
        ring.append(ring[0])
    wkt = "POLYGON((" + ", ".join(f"{lng} {lat}" for lng, lat in ring) + "))"
    club_id = _club_of(uid)
    with transaction.atomic():
        with connection.cursor() as cur:
            # 1) перехват: вычесть наш полигон у чужих территорий
            cur.execute(
                f"UPDATE territories SET geom = "
                f"ST_Multi(ST_CollectionExtract(ST_Difference(geom, {_CAP}),3)) "
                f"WHERE owner_id <> %s AND ST_Intersects(geom, {_CAP})",
                [wkt, uid, wkt],
            )
            cur.execute("DELETE FROM territories WHERE ST_IsEmpty(geom) OR ST_Area(geom)=0")
            # 2) своя территория: union с существующей или создать
            cur.execute("SELECT 1 FROM territories WHERE owner_id=%s", [uid])
            if cur.fetchone():
                cur.execute(
                    f"UPDATE territories SET "
                    f"geom = ST_Multi(ST_CollectionExtract(ST_Union(geom, {_CAP}),3)), "
                    f"club_id=%s, captured_at=now() WHERE owner_id=%s",
                    [wkt, club_id, uid],
                )
            else:
                cur.execute(
                    f"INSERT INTO territories (id,owner_id,club_id,geom,captured_at) "
                    f"VALUES (%s,%s,%s,{_CAP},now())",
                    [f"t_{secrets.token_hex(8)}", uid, club_id, wkt],
                )
            cur.execute(
                "SELECT ST_AsGeoJSON(geom), ST_Area(geom::geography) "
                "FROM territories WHERE owner_id=%s",
                [uid],
            )
            gj, area = cur.fetchone()
    return Response({"ok": True, "areaM2": round(area or 0), "geojson": json.loads(gj)})


@api_view(["GET"])
def list_territories(request):
    uid = user_id_from_request(request)
    if not uid:
        return Response({"detail": "Нет токена"}, status=401)
    my_club = _club_of(uid)
    bbox = request.query_params.get("bbox")
    # На отдалённом виде упрощаем геометрию сильнее (легче и быстрее).
    simplify = "ST_SimplifyPreserveTopology(geom,0.00003)"
    with connection.cursor() as cur:
        if bbox:
            try:
                a, b, c, d = (float(x) for x in bbox.split(","))
            except Exception:
                return Response({"detail": "bbox=minLng,minLat,maxLng,maxLat"}, status=400)
            cur.execute(
                f"SELECT owner_id, club_id, ST_AsGeoJSON({simplify}) FROM territories "
                f"WHERE geom && ST_MakeEnvelope(%s,%s,%s,%s,4326)",
                [a, b, c, d],
            )
        else:
            cur.execute(f"SELECT owner_id, club_id, ST_AsGeoJSON({simplify}) FROM territories")
        rows = cur.fetchall()
    out = []
    for owner_id, club_id, gj in rows:
        rel = "mine" if owner_id == uid else (
            "club" if club_id and club_id == my_club else "enemy"
        )
        out.append({"ownerId": owner_id, "clubId": club_id, "rel": rel, "geojson": json.loads(gj)})
    return Response({"territories": out})
