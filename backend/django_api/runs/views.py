"""Синхронизация истории пробежек + серверный расчёт очков (анти-чит S-04).
- GET  /v1/runs            → история пользователя (сводки, новые сверху);
- POST /v1/runs            → загрузить завершённый забег (идемпотентно по id);
                             СЕРВЕР сам валидирует забег и начисляет очки за бег
                             (клиент очки больше не присылает — иначе их можно подделать).
Требуется Bearer-токен. Сырой GPS-маршрут НЕ принимаем/не храним (приватность §2)."""
from datetime import datetime, timezone as dt_timezone

from django.utils import timezone
from rest_framework.decorators import api_view
from rest_framework.response import Response

from common.security import user_id_from_request
from loyalty.models import LoyaltyTransaction, add_txn

from .models import Run

_MAX = 100

# ── Пороги анти-чита (S-04). Скорость согласована с territories (40 км/ч). ──
MAX_SPEED_MS = 11.2            # ~40 км/ч — серверный потолок (как в territories)
MAX_RUN_DISTANCE_M = 100_000   # 100 км за один забег — неправдоподобно
MAX_DAY_DISTANCE_M = 150_000   # 150 км/сутки суммарно — щедрый потолок против фарма
POINTS_PER_KM = 10             # очки = км × 10 (как было на клиенте, теперь на сервере)


def _validate(uid, distance_m, duration_s, finished):
    """Возвращает причину флага (str) или '' если забег правдоподобен."""
    if distance_m <= 0:
        return "Нулевая дистанция"
    if duration_s <= 0:
        return "Нет длительности забега"
    if distance_m / duration_s > MAX_SPEED_MS:
        return "Скорость выше 40 км/ч (спуфинг/телепорт)"
    if distance_m > MAX_RUN_DISTANCE_M:
        return "Дистанция за забег неправдоподобна"
    # Суточный лимит: сумма валидных забегов за календарный день (UTC) + этот.
    day_start = finished.replace(hour=0, minute=0, second=0, microsecond=0)
    day_sum = sum(
        r.distance_m
        for r in Run.objects.filter(
            user_id=uid, flagged=False, finished_at__gte=day_start,
            finished_at__lt=day_start.replace(hour=23, minute=59, second=59),
        )
    )
    if day_sum + distance_m > MAX_DAY_DISTANCE_M:
        return "Превышен суточный лимит дистанции"
    return ""


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

    # Повтор (ретрай/офлайн-очередь) с тем же id ничего не задваивает — отдаём как есть.
    existing = Run.objects.filter(id=rid).first()
    if existing:
        if existing.user_id != uid:
            return Response({"detail": "Конфликт id"}, status=409)
        return Response({
            "ok": True, "duplicate": True,
            "flagged": existing.flagged, "flagReason": existing.flag_reason,
            "pointsAwarded": existing.points_awarded, "run": existing.to_json(),
        })

    distance_m = float(d.get("distanceMeters") or 0)
    duration_s = int(d.get("elapsedSeconds") or 0)

    ms = d.get("finishedAtMs")
    try:
        finished = (
            datetime.fromtimestamp(int(ms) / 1000, tz=dt_timezone.utc)
            if ms is not None
            else timezone.now()
        )
    except (TypeError, ValueError, OSError):
        finished = timezone.now()

    # Анти-чит: считаем очки на сервере; неправдоподобный забег → флаг + 0 очков.
    reason = _validate(uid, distance_m, duration_s, finished)
    flagged = bool(reason)
    points = 0 if flagged else round(distance_m / 1000.0 * POINTS_PER_KM)

    run = Run.objects.create(
        id=rid,
        user_id=uid,
        distance_m=distance_m,
        duration_s=duration_s,
        captured_territory=bool(d.get("capturedTerritory")),
        captured_zones=int(d.get("capturedZones") or 0),
        finished_at=finished,
        points_awarded=points,
        flagged=flagged,
        flag_reason=reason,
    )

    # Начисляем за бег ровно один раз на забег (идемпотентность гарантирует Run.id).
    # Если запись транзакции по этому runId уже есть (защита от рассинхрона) — не дублируем.
    if points > 0 and not LoyaltyTransaction.objects.filter(
        user_id=uid, run_id=rid, source="runnerRun"
    ).exists():
        add_txn(uid, points, "runnerRun",
                f"Пробежка {distance_m / 1000.0:.1f} км", None, rid)

    return Response({
        "ok": True, "duplicate": False,
        "flagged": flagged, "flagReason": reason,
        "pointsAwarded": points, "run": run.to_json(),
    })
