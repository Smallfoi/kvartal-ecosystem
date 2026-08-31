"""Недельный стрик: серия, текущая неделя, авто-заморозка раз в месяц."""
from datetime import datetime, timedelta, timezone as dt_tz

from common.testutils import ApiTestCase
from runs.models import Run

from .streaks import week_streak


class StreakTests(ApiTestCase):
    phone = "+79992003001"

    NOW = datetime(2026, 8, 26, 10, 0, tzinfo=dt_tz.utc)  # среда

    def _run_on(self, run_id, day):
        Run.objects.create(
            id=run_id,
            user_id=self.uid,
            distance_m=3000,
            duration_s=1200,
            finished_at=day,
        )

    def test_empty_history(self):
        s = week_streak(self.uid, now=self.NOW)
        self.assertEqual(s["weeks"], 0)
        self.assertFalse(s["thisWeekDone"])

    def test_current_and_past_weeks_count(self):
        self._run_on("r_st1", self.NOW - timedelta(days=1))       # эта неделя
        self._run_on("r_st2", self.NOW - timedelta(days=8))       # прошлая
        self._run_on("r_st3", self.NOW - timedelta(days=15))      # позапрошлая
        s = week_streak(self.uid, now=self.NOW)
        self.assertTrue(s["thisWeekDone"])
        self.assertEqual(s["weeks"], 3)

    def test_current_week_pending_does_not_break(self):
        self._run_on("r_st4", self.NOW - timedelta(days=8))
        s = week_streak(self.uid, now=self.NOW)
        self.assertFalse(s["thisWeekDone"])
        self.assertEqual(s["weeks"], 1)  # текущая ещё «в работе»

    def test_freeze_saves_one_gap_per_month(self):
        # неделя −1: бегал; неделя −2: пусто (заморозка); неделя −3: бегал
        self._run_on("r_st5", self.NOW - timedelta(days=8))
        self._run_on("r_st6", self.NOW - timedelta(days=22))
        s = week_streak(self.uid, now=self.NOW)
        self.assertEqual(s["weeks"], 2)
        self.assertEqual(len(s["frozenWeeks"]), 1)

    def test_two_gaps_same_month_break(self):
        # два пустых окна в одном месяце — вторая дыра рвёт серию
        self._run_on("r_st7", self.NOW - timedelta(days=8))
        self._run_on("r_st8", self.NOW - timedelta(days=29))
        s = week_streak(self.uid, now=self.NOW)
        # −2 неделя заморожена (авг), −3 пустая тоже авг → разрыв
        self.assertEqual(s["weeks"], 1)
