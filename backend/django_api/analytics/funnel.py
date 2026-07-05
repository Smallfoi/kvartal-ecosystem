"""Воронки конверсии и активность (D-30, фаза 2) поверх потока событий `Event`.

Воронка активации: регистрация → первый забег → первая покупка. На каждом шаге —
число УНИКАЛЬНЫХ пользователей, дошедших до ВСЕХ шагов включительно (inclusive-AND),
и конверсия к первому шагу / к предыдущему. Плюс активные пользователи (DAU/WAU-подобно)
и топ событий за период.

Как и ретеншн, считается на реальных событиях — накапливаются с момента внедрения D-30
(историю до этого события не покрывают). Анонимные события (пустой user_id) не учитываются
в пользовательских метриках воронки/активных.
"""
from datetime import timedelta

from django.utils import timezone

from .models import E_PURCHASE, E_REGISTER, E_RUN_FINISHED, Event

# Шаги воронки активации по умолчанию (имена канонических серверных событий).
DEFAULT_STEPS = [E_REGISTER, E_RUN_FINISHED, E_PURCHASE]
_STEP_LABEL = {
    E_REGISTER: "Регистрация",
    E_RUN_FINISHED: "Первый забег",
    E_PURCHASE: "Первая покупка",
}


def _since(days):
    return timezone.now() - timedelta(days=max(1, int(days or 30)))


def _users_with(name, since):
    return set(
        Event.objects.filter(name=name, created_at__gte=since)
        .exclude(user_id="")
        .values_list("user_id", flat=True)
    )


def funnel(steps=None, days=30):
    """Воронка: для каждого шага — уникальные юзеры, сделавшие ВСЕ шаги до него включительно,
    и конверсия (% к первому шагу и % к предыдущему)."""
    steps = steps or DEFAULT_STEPS
    since = _since(days)
    rows, cumulative = [], None
    for i, name in enumerate(steps):
        users = _users_with(name, since)
        cumulative = users if cumulative is None else (cumulative & users)
        rows.append({"step": i, "event": name, "label": _STEP_LABEL.get(name, name),
                     "users": len(cumulative)})
    first = rows[0]["users"] if rows else 0
    for i, r in enumerate(rows):
        prev = rows[i - 1]["users"] if i > 0 else r["users"]
        r["pctOfFirst"] = round(100.0 * r["users"] / first, 1) if first else 0.0
        r["pctOfPrev"] = round(100.0 * r["users"] / prev, 1) if prev else 0.0
    return rows


def active_users(days=7):
    """Уникальные пользователи с любым событием за период (DAU/WAU-подобно)."""
    return (
        Event.objects.filter(created_at__gte=_since(days))
        .exclude(user_id="")
        .values("user_id")
        .distinct()
        .count()
    )


def event_counts(days=7):
    """Число событий по имени за период (топ активности), по убыванию."""
    from django.db.models import Count

    rows = (
        Event.objects.filter(created_at__gte=_since(days))
        .values("name")
        .annotate(n=Count("id"))
        .order_by("-n")
    )
    return [{"event": r["name"], "count": r["n"]} for r in rows]
