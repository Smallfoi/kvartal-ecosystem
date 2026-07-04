"""Ретеншн по когортам (D-30): удержание по неделе регистрации.

Когорта = ISO-неделя регистрации аккаунта (Account.created_at). Пользователь «активен»
в неделю W, если у него есть хоть одна транзакция баллов в эту неделю (забег/покупка/
захват/трата) — устойчивый сигнал, доступный и ретроспективно (события копим с D-30, но
ретеншн работает по историческим данным сразу). Треугольная матрица week-0..week-N.
"""
from datetime import timedelta
from datetime import timezone as dt_tz

from django.utils import timezone

from accounts.models import Account
from loyalty.models import LoyaltyTransaction


def _week_start(dt):
    d = dt.astimezone(dt_tz.utc)
    monday = d - timedelta(days=d.weekday())
    return monday.replace(hour=0, minute=0, second=0, microsecond=0)


def weekly_cohorts(weeks=8):
    """Когорты за последние `weeks` недель (свежие сверху). Каждая:
    {cohortWeek, size, retention:[{week, active, pct}, ...]} — pct от размера когорты."""
    weeks = max(1, min(int(weeks or 8), 52))
    this_week = _week_start(timezone.now())
    cohorts = []
    for k in range(weeks):
        cohort_start = this_week - timedelta(weeks=(weeks - 1 - k))
        cohort_end = cohort_start + timedelta(weeks=1)
        users = list(
            Account.objects.filter(
                created_at__gte=cohort_start, created_at__lt=cohort_end
            ).values_list("id", flat=True)
        )
        size = len(users)
        retention = []
        if size:
            offset, wk = 0, cohort_start
            while wk <= this_week:  # week-0 (регистрация) … текущая неделя
                wk_end = wk + timedelta(weeks=1)
                active = (
                    LoyaltyTransaction.objects.filter(
                        user_id__in=users, created_at__gte=wk, created_at__lt=wk_end
                    )
                    .values("user_id")
                    .distinct()
                    .count()
                )
                retention.append(
                    {"week": offset, "active": active, "pct": round(100.0 * active / size, 1)}
                )
                offset += 1
                wk = wk_end
        cohorts.append(
            {"cohortWeek": cohort_start.date().isoformat(), "size": size, "retention": retention}
        )
    cohorts.reverse()  # свежие когорты сверху
    return cohorts
