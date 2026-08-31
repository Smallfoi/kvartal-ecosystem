"""Недельный стрик с заморозкой (Квартал 2.0, Ф4 — утверждено 31.08.2026).

Серия недель, в каждой из которых была хотя бы одна пробежка (свои забеги +
импорт с часов). Одна пустая неделя в календарный месяц прощается автоматически
(«заморозка»): серия не рвётся, но и не растёт. Текущая неделя серию не рвёт,
пока не закончилась.

Чистая функция от истории пробежек — состояния и cron не нужно.
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone as dt_tz

from runs.models import Run
from workouts.models import ExternalWorkout

from .services import period_start

MAX_LOOKBACK_WEEKS = 520  # ~10 лет — предохранитель от вечного цикла


def _active_week_starts(uid: str) -> set:
    """Понедельники (UTC-даты) всех недель, где был бег."""
    weeks = set()
    for finished in Run.objects.filter(
        user_id=uid, flagged=False, distance_m__gt=0
    ).values_list("finished_at", flat=True):
        monday = (finished - timedelta(days=finished.weekday())).date()
        weeks.add(monday)
    for started in ExternalWorkout.objects.filter(
        user_id=uid, flagged=False, distance_m__gt=0
    ).values_list("started_at", flat=True):
        monday = (started - timedelta(days=started.weekday())).date()
        weeks.add(monday)
    return weeks


def week_streak(uid: str, now: datetime | None = None) -> dict:
    now = now or datetime.now(dt_tz.utc)
    weeks = _active_week_starts(uid)
    this_week = period_start("week", now=now).date()
    this_week_done = this_week in weeks

    streak = 0
    frozen: list[str] = []
    freeze_used: set[tuple[int, int]] = set()
    # Текущая неделя входит в серию, если уже пробежал; иначе счёт начинаем
    # с прошлой недели (текущая ещё «в работе» — серию не рвёт).
    week = this_week if this_week_done else this_week - timedelta(days=7)
    for _ in range(MAX_LOOKBACK_WEEKS):
        if week in weeks:
            streak += 1
        else:
            month = (week.year, week.month)
            older = week - timedelta(days=7)
            # Заморозка тратится только когда ЗА пустой неделей серия
            # продолжается — иначе фриз сгорал бы на хвосте истории.
            if streak > 0 and older in weeks and month not in freeze_used:
                freeze_used.add(month)
                frozen.append(week.isoformat())
            else:
                break
        week -= timedelta(days=7)

    return {
        "weeks": streak,
        "thisWeekDone": this_week_done,
        "frozenWeeks": frozen[:6],
    }
