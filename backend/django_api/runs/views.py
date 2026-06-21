"""Синхронизация истории пробежек.
- GET  /v1/runs            → история пользователя (сводки, новые сверху);
- POST /v1/runs            → загрузить завершённый забег (идемпотентно по id).
Требуется Bearer-токен. Сырой GPS-маршрут НЕ принимаем/не храним (приватность §2)."""
from datetime import datetime, timezone as dt_timezone

from rest_framework.decorators import api_view
from rest_framework.response import Response

from common.security import user_id_from_request

from .models import Run

_MAX = 100


@api_view(["GET", "POST"])
def runs(request):
    uid = user_id_from_request(request)
    if not uid:
        return Response({"detail": "Нет токена"}, status=401)

    if request.method == "GET":
        rows = Run.objects.filter(user_id=uid)[:_MAX]
        return Response([r.to_json() for r in rows])

    # POST — загрузка завершённого забега
    d = request.data
    rid = (str(d.get("id") or "")).strip()[:40]
    if not rid:
        return Response({"detail": "Нет id забега"}, status=400)

    ms = d.get("finishedAtMs")
    try:
        finished = (
            datetime.fromtimestamp(int(ms) / 1000, tz=dt_timezone.utc)
            if ms is not None
            else datetime.now(tz=dt_timezone.utc)
        )
    except (TypeError, ValueError, OSError):
        finished = datetime.now(tz=dt_timezone.utc)

    # Идемпотентность: повтор с тем же id (ретрай) ничего не дублирует.
    obj, created = Run.objects.get_or_create(
        id=rid,
        defaults={
            "user_id": uid,
            "distance_m": float(d.get("distanceMeters") or 0),
            "duration_s": int(d.get("elapsedSeconds") or 0),
            "captured_territory": bool(d.get("capturedTerritory")),
            "captured_zones": int(d.get("capturedZones") or 0),
            "finished_at": finished,
        },
    )
    # Чужой id (теоретически) — не трогаем чужой забег.
    if not created and obj.user_id != uid:
        return Response({"detail": "Конфликт id"}, status=409)
    return Response({"ok": True, "duplicate": not created, "run": obj.to_json()})
