"""Синхронизация истории пробежек + серверный расчёт очков (анти-чит S-04).
- GET  /v1/runs            → история пользователя (сводки, новые сверху);
- POST /v1/runs            → загрузить завершённый забег (идемпотентно по id);
                             СЕРВЕР сам валидирует забег и начисляет очки за бег
                             (клиент очки больше не присылает — иначе их можно подделать).
Требуется Bearer-токен. Сырой GPS-маршрут НЕ принимаем/не храним (приватность §2)."""
from datetime import datetime, timedelta, timezone as dt_timezone

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
MAX_RUNS_PER_DAY = 30          # >30 забегов/сутки — спам/автоматизация (для человека много)
POINTS_PER_KM = 10             # очки = км × 10 (как было на клиенте, теперь на сервере)
FUTURE_SKEW = timedelta(hours=12)   # допуск на часовые пояса/рассинхрон часов
MAX_RUN_AGE = timedelta(days=30)    # старше — подозрение на реплей/бэкфилл фейков

# Режим доверия (S-04): при накоплении флагнутых забегов помечаем аккаунт «на ревью».
REVIEW_FLAGGED_THRESHOLD = 5        # столько флагов за окно → отметка модератору
REVIEW_WINDOW = timedelta(days=7)


def _validate(uid, distance_m, duration_s, finished, mock=False):
    """Возвращает причину флага (str) или '' если забег правдоподобен."""
    now = timezone.now()
    # Клиент сообщил о поддельной геолокации (Android mock-provider) — сразу флаг.
    if mock:
        return "Подделка местоположения (mock GPS)"
    # Anti-replay (S-04): время забега в будущем или слишком старое — подделка.
    if finished > now + FUTURE_SKEW:
        return "Дата забега в будущем"
    if finished < now - MAX_RUN_AGE:
        return "Слишком старый забег (возможный реплей)"
    if distance_m <= 0:
        return "Нулевая дистанция"
    if duration_s <= 0:
        return "Нет длительности забега"
    if distance_m / duration_s > MAX_SPEED_MS:
        return "Скорость выше 40 км/ч (спуфинг/телепорт)"
    if distance_m > MAX_RUN_DISTANCE_M:
        return "Дистанция за забег неправдоподобна"
    # Суточные лимиты по валидным забегам за календарный день (UTC).
    day_start = finished.replace(hour=0, minute=0, second=0, microsecond=0)
    todays = list(
        Run.objects.filter(
            user_id=uid, flagged=False, finished_at__gte=day_start,
            finished_at__lt=day_start.replace(hour=23, minute=59, second=59),
        )
    )
    if len(todays) >= MAX_RUNS_PER_DAY:  # анти-спам: слишком много забегов за сутки
        return "Слишком много забегов за день"
    if sum(r.distance_m for r in todays) + distance_m > MAX_DAY_DISTANCE_M:
        return "Превышен суточный лимит дистанции"
    return ""


def _maybe_flag_for_review(uid):
    """Накопилось много флагнутых забегов за окно → помечаем аккаунт на ревью.
    Бан НЕ автоматический — это сигнал модератору присмотреться (S-04, hold/review)."""
    from accounts.models import Account

    since = timezone.now() - REVIEW_WINDOW
    flagged_count = Run.objects.filter(
        user_id=uid, flagged=True, created_at__gte=since
    ).count()
    if flagged_count >= REVIEW_FLAGGED_THRESHOLD:
        Account.objects.filter(id=uid, needs_review=False).update(needs_review=True)


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
    mock = bool(d.get("mockDetected"))  # клиент сообщает о mock-GPS (Android)
    reason = _validate(uid, distance_m, duration_s, finished, mock=mock)
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

    # Режим доверия: если забегов с флагом накопилось много — пометить на ревью.
    if flagged:
        _maybe_flag_for_review(uid)

    return Response({
        "ok": True, "duplicate": False,
        "flagged": flagged, "flagReason": reason,
        "pointsAwarded": points, "run": run.to_json(),
    })


def approve_run(run):
    """Модерация (S-04 ф.2): снять флаг с забега и начислить очки за бег.
    Идемпотентно (по runId) — повторный вызов не дублирует начисление.
    Возвращает кол-во начисленных за бег очков."""
    points = round(run.distance_m / 1000.0 * POINTS_PER_KM)
    if points > 0 and not LoyaltyTransaction.objects.filter(
        user_id=run.user_id, run_id=run.id, source="runnerRun"
    ).exists():
        add_txn(run.user_id, points, "runnerRun",
                f"Пробежка {run.distance_m / 1000.0:.1f} км (одобрено модератором)",
                None, run.id)
    run.flagged = False
    run.flag_reason = ""
    run.points_awarded = points
    run.save(update_fields=["flagged", "flag_reason", "points_awarded"])
    return points
