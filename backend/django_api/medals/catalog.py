# -*- coding: utf-8 -*-
"""Критерии 44 наград «Штамп МАТА» (docs/design/medals/README.md).

Сервер — единственный судья: считает по своим данным (runs без флага,
события территорий, итоги сезонов, дивизионные начисления). Часть наград
пока «недоступна» — для них в данных нет основания (дневная цель, температура,
город из GPS, районы, клубный сезон): критерий отсутствует, клиент показывает
их закрытыми без прогресса. Список причин — в отчёте D-64 и ECOSYSTEM_API.md.

Все «дни» — по Якутску (Asia/Yakutsk): серия, рассвет/полночь, праздники.
"""
from calendar import monthrange
from datetime import date, timedelta
from zoneinfo import ZoneInfo

from django.utils import timezone

from loyalty.models import LoyaltyTransaction
from runs.models import Run

TZ = ZoneInfo("Asia/Yakutsk")
HOLD_HOURS = 168  # неделя удержания зоны (territories.views)

MONTHS_RU = (
    "ЯНВАРЬ", "ФЕВРАЛЬ", "МАРТ", "АПРЕЛЬ", "МАЙ", "ИЮНЬ",
    "ИЮЛЬ", "АВГУСТ", "СЕНТЯБРЬ", "ОКТЯБРЬ", "НОЯБРЬ", "ДЕКАБРЬ",
)


def fmt_km(km: float) -> str:
    if km >= 100:
        return f"{km:.0f} КМ"
    s = f"{km:.1f}".replace(".", ",")
    return f"{s} КМ"


def fmt_time(seconds: int) -> str:
    h, rest = divmod(int(seconds), 3600)
    m, s = divmod(rest, 60)
    return f"{h}:{m:02d}:{s:02d}" if h else f"{m}:{s:02d}"


def fmt_date(d: date) -> str:
    return d.strftime("%d.%m.%Y")


class Facts:
    """Один проход по данным бегуна — все факты для 44 критериев."""

    def __init__(self, uid: str, now=None):
        self.now = now or timezone.now()
        rows = list(
            Run.objects.filter(user_id=uid, flagged=False)
            .order_by("finished_at")
            .values_list("finished_at", "duration_s", "distance_m", "captured_zones")
        )
        self.run_count = len(rows)
        self.total_km = sum(r[2] for r in rows) / 1000.0
        self.zones_total = sum(r[3] for r in rows)

        self.days: set[date] = set()
        self.month_km: dict[tuple[int, int], float] = {}
        self.best_single_km = 0.0
        # Лучшее время на пороговых дистанциях: км → (сек, дата).
        self.best_at: dict[float, tuple[int, date]] = {}
        self.first_run = None          # (дата, км)
        self.first_capture = None      # дата первого забега с захватом
        self.zones_dates: list[tuple[date, int]] = []  # накопление зон по датам
        self.dawn = None               # (время старта, дата)
        self.midnight = None
        self.night_capture = None
        self.workout_100_date = None
        self.total_1000_date = None
        self.month_100 = None          # ((y,m), км)
        self.holidays: dict[str, tuple[date, float]] = {}
        self.defense_candidates: list[tuple] = []  # (finished_at utc, дата)

        km_acc = 0.0
        for i, (fin, dur, dist_m, zones) in enumerate(rows):
            start_l = (fin - timedelta(seconds=dur or 0)).astimezone(TZ)
            fin_l = fin.astimezone(TZ)
            d = start_l.date()
            km = dist_m / 1000.0
            self.days.add(d)
            key = (d.year, d.month)
            self.month_km[key] = self.month_km.get(key, 0.0) + km
            if self.first_run is None:
                self.first_run = (d, km)
            if km > self.best_single_km:
                self.best_single_km = km
            for thr in (5.0, 10.0, 21.097, 42.195):
                if km >= thr:
                    cur = self.best_at.get(thr)
                    if cur is None or dur < cur[0]:
                        self.best_at[thr] = (dur, d)
            km_acc += km
            if self.total_1000_date is None and km_acc >= 1000:
                self.total_1000_date = d
            if self.workout_100_date is None and i + 1 >= 100:
                self.workout_100_date = d
            if zones > 0:
                if self.first_capture is None:
                    self.first_capture = d
                self.zones_dates.append((d, zones))
                # Ночной захват: старт или финиш между 00:00 и 05:00.
                if (start_l.hour < 5 or fin_l.hour < 5) and self.night_capture is None:
                    self.night_capture = (start_l.strftime("%H:%M"), d)
                if fin <= self.now - timedelta(hours=HOLD_HOURS):
                    self.defense_candidates.append((fin, d))
            if start_l.hour < 7 and self.dawn is None:
                self.dawn = (start_l.strftime("%H:%M"), d)
            if start_l.hour >= 23 and self.midnight is None:
                self.midnight = (start_l.strftime("%H:%M"), d)
            for hid, (mm, dd), need_km in (
                ("l_ny_2026", (12, 31), 0), ("l_ny_2026", (1, 1), 0),
                ("l_pobeda_2026", (5, 9), 9), ("l_ysyakh_2026", (6, 21), 0),
                ("l_ysyakh_2026", (6, 22), 0), ("l_eco_2026", (4, 22), 0),
            ):
                if (d.year == 2026 and (d.month, d.day) == (mm, dd)
                        and km >= need_km and hid not in self.holidays):
                    self.holidays[hid] = (d, km)

        self.longest_streak = _longest_streak(self.days)
        self.perfect_month = _perfect_month(self.days, self.now.astimezone(TZ).date())
        self.best_month = max(self.month_km.items(), key=lambda kv: kv[1]) if self.month_km else None

        # Оборона: захват дожил до конца недели холда, и за эту неделю у бегуна
        # никто ничего не отрезал (события territory_events, victim = я).
        self.defense = None
        if self.defense_candidates:
            hits = _victim_events(uid)
            for fin, d in self.defense_candidates:
                until = fin + timedelta(hours=HOLD_HOURS)
                if not any(fin <= h <= until for h in hits):
                    self.defense = d + timedelta(days=7)
                    break

        # Перехват: отрезал землю у живого соперника (событие с виновником-мной).
        self.intercept = _first_attack(uid)

        # Сезон и дивизион.
        from league.models import SeasonResult
        sr = SeasonResult.objects.filter(user_id=uid).order_by("month").first()
        self.season_first = sr  # None | SeasonResult
        tx = (
            LoyaltyTransaction.objects
            .filter(user_id=uid, source="runnerDivision", amount=50)
            .order_by("created_at").first()
        )
        self.division_win = tx.created_at.astimezone(TZ).date() if tx else None

    def zones_reached(self, n: int):
        """Дата, когда счётчик зон дошёл до n (для гравировки)."""
        acc = 0
        for d, z in self.zones_dates:
            acc += z
            if acc >= n:
                return d
        return None


def _longest_streak(days: set[date]) -> int:
    best = cur = 0
    prev = None
    for d in sorted(days):
        cur = cur + 1 if prev is not None and (d - prev).days == 1 else 1
        best = max(best, cur)
        prev = d
    return best


def _perfect_month(days: set[date], today: date):
    """Полностью закрытый календарный месяц (только прошедшие месяцы)."""
    by_month: dict[tuple[int, int], int] = {}
    for d in days:
        by_month[(d.year, d.month)] = by_month.get((d.year, d.month), 0) + 1
    for (y, m), n in sorted(by_month.items()):
        if (y, m) >= (today.year, today.month):
            continue
        if n >= monthrange(y, m)[1]:
            return (y, m)
    return None


def _victim_events(uid: str):
    from django.db import connection
    with connection.cursor() as cur:
        cur.execute(
            "SELECT created_at FROM territory_events WHERE victim_owner = %s", [uid]
        )
        return [r[0] for r in cur.fetchall()]


def _first_attack(uid: str):
    from django.db import connection
    with connection.cursor() as cur:
        cur.execute(
            "SELECT created_at, area_m2 FROM territory_events "
            "WHERE attacker = %s ORDER BY created_at LIMIT 1", [uid],
        )
        row = cur.fetchone()
    if not row:
        return None
    return (row[0].astimezone(TZ).date(), row[1])


def _season_month_label(month: str) -> str:
    y, m = month.split("-")
    return f"{MONTHS_RU[int(m) - 1]} {y}"


def _e_date(d):
    return fmt_date(d) if d else ""


# ── каталог: id → критерий/прогресс/гравировка ────────────────────────────────
# У «недоступных» наград (нет данных на сервере) check отсутствует — клиент
# показывает их закрытыми, без полосы прогресса.

def _best_time_engrave(thr, label):
    def e(f):
        dur, d = f.best_at[thr]
        return (fmt_time(dur), label, _e_date(d))
    return e


CATALOG = [
    # ── Ритм ────────────────────────────────────────────────────────────────
    {"id": "r_goal_first"},   # дневная цель пока не живёт на сервере
    {"id": "r_week_perfect",
     "check": lambda f: f.longest_streak >= 7,
     "progress": lambda f: (f.longest_streak, 7),
     "engrave": lambda f: ("7", "ДНЕЙ ПОДРЯД", "")},
    {"id": "r_month_perfect",
     "check": lambda f: f.perfect_month is not None,
     "engrave": lambda f: (
         str(monthrange(*f.perfect_month)[1]), "ДНЕЙ · КАЖДЫЙ",
         f"{MONTHS_RU[f.perfect_month[1] - 1]} {f.perfect_month[0]}")},
    {"id": "r_year_perfect",
     "check": lambda f: f.longest_streak >= 365,
     "progress": lambda f: (f.longest_streak, 365),
     "engrave": lambda f: ("365", "ДНЕЙ ПОДРЯД", "")},
    {"id": "r_goal_x2"}, {"id": "r_goal_x3"}, {"id": "r_goal_x5"},
    {"id": "r_streak_7",
     "check": lambda f: f.longest_streak >= 7,
     "progress": lambda f: (f.longest_streak, 7),
     "engrave": lambda f: (str(f.longest_streak), "РЕКОРД СЕРИИ", "")},
    {"id": "r_streak_30",
     "check": lambda f: f.longest_streak >= 30,
     "progress": lambda f: (f.longest_streak, 30),
     "engrave": lambda f: (str(f.longest_streak), "РЕКОРД СЕРИИ", "")},
    {"id": "r_streak_100",
     "check": lambda f: f.longest_streak >= 100,
     "progress": lambda f: (f.longest_streak, 100),
     "engrave": lambda f: (str(f.longest_streak), "РЕКОРД СЕРИИ", "")},
    {"id": "r_streak_365",
     "check": lambda f: f.longest_streak >= 365,
     "progress": lambda f: (f.longest_streak, 365),
     "engrave": lambda f: (str(f.longest_streak), "РЕКОРД СЕРИИ", "")},

    # ── Территория ──────────────────────────────────────────────────────────
    {"id": "t_first_zone",
     "check": lambda f: f.zones_total >= 1,
     "engrave": lambda f: ("1", "ПЕРВЫЙ КВАРТАЛ", _e_date(f.first_capture))},
    {"id": "t_zones_10",
     "check": lambda f: f.zones_total >= 10,
     "progress": lambda f: (f.zones_total, 10),
     "engrave": lambda f: ("10", "ЗОН · ВСЕГО", _e_date(f.zones_reached(10)))},
    {"id": "t_zones_50",
     "check": lambda f: f.zones_total >= 50,
     "progress": lambda f: (f.zones_total, 50),
     "engrave": lambda f: ("50", "ЗОН · ВСЕГО", _e_date(f.zones_reached(50)))},
    {"id": "t_zones_100",
     "check": lambda f: f.zones_total >= 100,
     "progress": lambda f: (f.zones_total, 100),
     "engrave": lambda f: ("100", "ЗОН · ВСЕГО", _e_date(f.zones_reached(100)))},
    {"id": "t_district"},     # районы города ещё не размечены
    {"id": "t_defense_7",
     "check": lambda f: f.defense is not None,
     "engrave": lambda f: ("7 ДНЕЙ", "ОБОРОНА", _e_date(f.defense))},
    {"id": "t_intercept",
     "check": lambda f: f.intercept is not None,
     "engrave": lambda f: (
         f"{f.intercept[1]:.0f} М²", "ОТБИТО У СОПЕРНИКА", _e_date(f.intercept[0]))},
    {"id": "t_night_capture",
     "check": lambda f: f.night_capture is not None,
     "engrave": lambda f: (
         f.night_capture[0], "НОЧНОЙ ЗАХВАТ", _e_date(f.night_capture[1]))},
    {"id": "t_pioneer"},      # нет журнала «кто брал зону раньше»

    # ── Дистанция ───────────────────────────────────────────────────────────
    {"id": "d_first_run",
     "check": lambda f: f.run_count >= 1,
     "engrave": lambda f: (
         fmt_km(f.first_run[1]), "ПЕРВЫЙ БЕГ", _e_date(f.first_run[0]))},
    {"id": "d_run_5k",
     "check": lambda f: 5.0 in f.best_at,
     "progress": lambda f: (f.best_single_km, 5),
     "engrave": _best_time_engrave(5.0, "ЛИЧНОЕ ВРЕМЯ · 5 КМ")},
    {"id": "d_run_10k",
     "check": lambda f: 10.0 in f.best_at,
     "progress": lambda f: (f.best_single_km, 10),
     "engrave": _best_time_engrave(10.0, "ЛИЧНОЕ ВРЕМЯ · 10 КМ")},
    {"id": "d_half_marathon",
     "check": lambda f: 21.097 in f.best_at,
     "progress": lambda f: (f.best_single_km, 21.1),
     "engrave": _best_time_engrave(21.097, "ПОЛУМАРАФОН")},
    {"id": "d_marathon",
     "check": lambda f: 42.195 in f.best_at,
     "progress": lambda f: (f.best_single_km, 42.2),
     "engrave": _best_time_engrave(42.195, "МАРАФОН")},
    {"id": "d_month_100",
     "check": lambda f: f.best_month is not None and f.best_month[1] >= 100,
     "progress": lambda f: (f.best_month[1] if f.best_month else 0, 100),
     "engrave": lambda f: (
         fmt_km(f.best_month[1]), "ЗА МЕСЯЦ",
         f"{MONTHS_RU[f.best_month[0][1] - 1]} {f.best_month[0][0]}")},
    {"id": "d_total_1000",
     "check": lambda f: f.total_km >= 1000,
     "progress": lambda f: (f.total_km, 1000),
     "engrave": lambda f: ("1000 КМ", "СУММАРНО", _e_date(f.total_1000_date))},
    {"id": "d_dawn",
     "check": lambda f: f.dawn is not None,
     "engrave": lambda f: (f.dawn[0], "СТАРТ ДО РАССВЕТА", _e_date(f.dawn[1]))},
    {"id": "d_midnight",
     "check": lambda f: f.midnight is not None,
     "engrave": lambda f: (f.midnight[0], "ПОЛУНОЧНЫЙ СТАРТ", _e_date(f.midnight[1]))},
    {"id": "d_frost_40"},     # температура пробежки не сохраняется
    {"id": "d_workouts_100",
     "check": lambda f: f.run_count >= 100,
     "progress": lambda f: (f.run_count, 100),
     "engrave": lambda f: ("100", "ТРЕНИРОВОК", _e_date(f.workout_100_date))},

    # ── Сезон и лига ────────────────────────────────────────────────────────
    {"id": "s_season_closed",
     "check": lambda f: f.season_first is not None and f.season_first.runs > 0,
     "engrave": lambda f: (
         fmt_km(f.season_first.km), f"МЕСТО {f.season_first.place} ИЗ {f.season_first.of}",
         _season_month_label(f.season_first.month))},
    {"id": "s_div_bronze"},   # маппинг 7 уровней Лиги ↔ 4 ранга медалей — вопрос владельцу
    {"id": "s_div_silver"},
    {"id": "s_div_gold"},
    {"id": "s_div_elite"},
    {"id": "s_champion",
     "check": lambda f: f.division_win is not None,
     "engrave": lambda f: ("1", "МЕСТО В ДИВИЗИОНЕ", _e_date(f.division_win))},
    {"id": "s_club_cup"},     # клубного сезона ещё нет

    # ── Лимитированные ──────────────────────────────────────────────────────
    {"id": "l_ny_2026",
     "check": lambda f: "l_ny_2026" in f.holidays,
     "engrave": lambda f: (
         fmt_km(f.holidays["l_ny_2026"][1]), "НОВЫЙ ГОД",
         _e_date(f.holidays["l_ny_2026"][0]))},
    {"id": "l_pobeda_2026",
     "check": lambda f: "l_pobeda_2026" in f.holidays,
     "engrave": lambda f: (
         fmt_km(f.holidays["l_pobeda_2026"][1]), "ДЕНЬ ПОБЕДЫ",
         _e_date(f.holidays["l_pobeda_2026"][0]))},
    {"id": "l_ysyakh_2026",
     "check": lambda f: "l_ysyakh_2026" in f.holidays,
     "engrave": lambda f: (
         fmt_km(f.holidays["l_ysyakh_2026"][1]), "ЫСЫАХ",
         _e_date(f.holidays["l_ysyakh_2026"][0]))},
    {"id": "l_city_2026"},    # город пробежки из GPS не сохраняется
    {"id": "l_eco_2026",
     "check": lambda f: "l_eco_2026" in f.holidays,
     "engrave": lambda f: (
         fmt_km(f.holidays["l_eco_2026"][1]), "ЭКОДЕНЬ",
         _e_date(f.holidays["l_eco_2026"][0]))},
    {"id": "l_race_2026"},    # финиш официального забега МАТА — после первого забега
]
