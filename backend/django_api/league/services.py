"""Расчёт зачётов лиги.

Главная мысль стратегии: одна пробежка попадает сразу в несколько зачётов, и в
каждом человек видит не только победителя, но и себя — «ты обошёл N из M».
Проигравших нет: медленный выигрывает в постоянстве, возрастной — в своей лиге.

Считаем по таблице `runs` (сводки забегов), а не по начислениям баллов: там есть
и дистанция, и количество пробежек, а помеченные античитом (`flagged`) видно и
можно исключить. Считает сервер — как и очки (S-04).
"""
from datetime import datetime, timedelta
from datetime import timezone as dt_tz

from django.db.models import Count, Sum

from clubs.models import ClubMember
from common.people import club_names_of, names_of
from league.models import RunnerProfile
from runs.models import Run

PERIODS = ("week", "month", "q90")
BOARDS = ("absolute", "consistency", "mylane", "personal", "club")

# Возрастные группы — те же, что на настоящих забегах: человек узнаёт свою.
AGE_GROUPS = [
    (0, 17, "до 18"),
    (18, 29, "18–29"),
    (30, 39, "30–39"),
    (40, 49, "40–49"),
    (50, 59, "50–59"),
    (60, 200, "60+"),
]


def period_start(period: str, now=None):
    now = now or datetime.now(dt_tz.utc)
    if period == "week":
        return (now - timedelta(days=now.weekday())).replace(
            hour=0, minute=0, second=0, microsecond=0
        )
    if period == "month":
        return now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    return now - timedelta(days=90)   # q90 — 90 дней, как «Местная легенда» у Strava


def previous_window(period: str, now=None):
    """Границы ПРЕДЫДУЩЕГО такого же периода — для зачёта «личный рекорд»."""
    now = now or datetime.now(dt_tz.utc)
    start = period_start(period, now)
    if period == "week":
        return start - timedelta(days=7), start
    if period == "month":
        prev_end = start
        prev_start = (start - timedelta(days=1)).replace(day=1)
        return prev_start, prev_end
    return start - timedelta(days=90), start


def age_group(birth_year, now=None):
    """Группа считается на лету: в базе она устарела бы в ближайший день рождения."""
    if not birth_year:
        return None
    now = now or datetime.now(dt_tz.utc)
    age = now.year - int(birth_year)
    if age < 0 or age > 120:
        return None
    for lo, hi, label in AGE_GROUPS:
        if lo <= age <= hi:
            return label
    return None


def group_label(age, gender):
    who = {"m": "Мужчины", "f": "Женщины"}.get(gender or "", "Бегуны")
    return f"{who} {age}" if age else who


def _totals(start, until=None, user_ids=None):
    """Сводка по каждому бегуну за период: километры, число пробежек, лучший забег.

    Помеченные античитом забеги в зачёты не идут — иначе рейтинг превращается
    в соревнование накрутчиков.
    """
    qs = Run.objects.filter(finished_at__gte=start, flagged=False)
    if until is not None:
        qs = qs.filter(finished_at__lt=until)
    if user_ids is not None:
        qs = qs.filter(user_id__in=list(user_ids))
    rows = qs.values("user_id").annotate(
        meters=Sum("distance_m"), runs=Count("id")
    )
    return {
        r["user_id"]: {
            "km": round((r["meters"] or 0) / 1000.0, 2),
            "runs": r["runs"] or 0,
        }
        for r in rows
    }


def _ranked(totals, key):
    """Список (user_id, значение) по убыванию; нули не участвуют — человек,
    который не бегал, не должен занимать место в таблице."""
    pairs = [(uid, t[key]) for uid, t in totals.items() if t[key]]
    return sorted(pairs, key=lambda x: (-x[1], x[0]))


def _me_block(ranked, me, decimals=2):
    """Моё место и — главное — сколько человек я обошёл.

    «Ты обошёл 47 из 63» держит в игре тех, кто никогда не будет первым.
    """
    of = len(ranked)
    place = next((i + 1 for i, (uid, _) in enumerate(ranked) if uid == me), None)
    value = next((v for uid, v in ranked if uid == me), 0)
    block = {
        "place": place,
        "of": of,
        "value": round(value, decimals),
        "aheadOf": (of - place) if place else 0,
    }
    if place and place > 1:
        block["behindNext"] = round(ranked[place - 2][1] - value, decimals)
    return block


def _top(ranked, me, limit=20, decimals=2):
    uids = [uid for uid, _ in ranked[:limit]]
    names = names_of(uids)
    clubs = club_names_of(uids)
    return [
        {
            "userId": uid,
            "name": names.get(uid, "—"),
            "club": clubs.get(uid),
            "value": round(value, decimals),
            "place": i + 1,
            "isMe": uid == me,
        }
        for i, (uid, value) in enumerate(ranked[:limit])
    ]


def board_absolute(me, period, limit=20):
    """Кто набрал больше километров. Классический зачёт — для быстрых и выносливых."""
    totals = _totals(period_start(period))
    ranked = _ranked(totals, "km")
    return {"top": _top(ranked, me, limit), "me": _me_block(ranked, me), "unit": "км"}


def board_consistency(me, period, limit=20):
    """Кто выходил бежать чаще. Скорость не решает — решает регулярность."""
    totals = _totals(period_start(period))
    ranked = _ranked(totals, "runs")
    return {
        "top": _top(ranked, me, limit, decimals=0),
        "me": _me_block(ranked, me, decimals=0),
        "unit": "пробежек",
    }


def board_mylane(me, period, limit=20):
    """Своя лига: сравниваем с ровесниками своего пола.

    Без профиля зачёт не показываем — сравнивать не с кем и незачем врать
    человеку, будто он в «своей» группе.
    """
    profile = RunnerProfile.objects.filter(user_id=me).first()
    my_age = age_group(profile.birth_year) if profile else None
    my_gender = (profile.gender or "") if profile else ""
    if not my_age or not my_gender:
        return {
            "top": [],
            "me": {"place": None, "of": 0, "value": 0, "aheadOf": 0},
            "unit": "км",
            "needsProfile": True,
        }

    peers = [
        p.user_id
        for p in RunnerProfile.objects.filter(gender=my_gender).only("user_id", "birth_year", "gender")
        if age_group(p.birth_year) == my_age
    ]
    totals = _totals(period_start(period), user_ids=peers)
    ranked = _ranked(totals, "km")
    return {
        "top": _top(ranked, me, limit),
        "me": _me_block(ranked, me),
        "unit": "км",
        "group": {"age": my_age, "gender": my_gender, "label": group_label(my_age, my_gender)},
    }


def board_personal(me, period):
    """Личный зачёт: я против себя же в прошлом периоде. Единственный, где
    выигрывают все — соревноваться не с кем, кроме прошлой версии себя."""
    now = datetime.now(dt_tz.utc)
    cur = _totals(period_start(period, now), user_ids=[me]).get(me, {"km": 0, "runs": 0})
    p_start, p_end = previous_window(period, now)
    prev = _totals(p_start, until=p_end, user_ids=[me]).get(me, {"km": 0, "runs": 0})
    return {
        "top": [],
        "unit": "км",
        "me": {
            "value": cur["km"],
            "runs": cur["runs"],
            "prevValue": prev["km"],
            "prevRuns": prev["runs"],
            "delta": round(cur["km"] - prev["km"], 2),
            "improved": cur["km"] > prev["km"],
        },
    }


def board_club(me, period, limit=20):
    """Клубный зачёт: сумма километров участников. Личный вклад виден в других досках."""
    totals = _totals(period_start(period))
    if not totals:
        return {"top": [], "me": {"place": None, "of": 0, "value": 0, "aheadOf": 0}, "unit": "км"}

    members = ClubMember.objects.filter(user_id__in=list(totals)).only("user_id", "club_id")
    by_club = {}
    for m in members:
        by_club.setdefault(m.club_id, []).append(m.user_id)
    if not by_club:
        return {"top": [], "me": {"place": None, "of": 0, "value": 0, "aheadOf": 0}, "unit": "км"}

    from clubs.models import Club

    club_names = {c.id: c.name for c in Club.objects.filter(id__in=list(by_club)).only("id", "name")}
    ranked = sorted(
        (
            (cid, round(sum(totals[u]["km"] for u in uids if u in totals), 2))
            for cid, uids in by_club.items()
        ),
        key=lambda x: (-x[1], str(x[0])),
    )
    ranked = [(cid, km) for cid, km in ranked if km]

    my_club = next((m.club_id for m in members if m.user_id == me), None)
    place = next((i + 1 for i, (cid, _) in enumerate(ranked) if cid == my_club), None)
    top = [
        {
            "clubId": cid,
            "name": club_names.get(cid, "—"),
            "value": km,
            "place": i + 1,
            "isMe": cid == my_club,
        }
        for i, (cid, km) in enumerate(ranked[:limit])
    ]
    me_block = {
        "place": place,
        "of": len(ranked),
        "value": next((km for cid, km in ranked if cid == my_club), 0),
        "aheadOf": (len(ranked) - place) if place else 0,
    }
    return {"top": top, "me": me_block, "unit": "км"}


BOARD_FUNCS = {
    "absolute": board_absolute,
    "consistency": board_consistency,
    "mylane": board_mylane,
    "club": board_club,
}
