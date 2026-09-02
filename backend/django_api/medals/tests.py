# -*- coding: utf-8 -*-
"""Медали «Штамп МАТА»: ленивая выдача, гравировка, идемпотентность."""
from datetime import datetime, timedelta, timezone as dt_tz

from common.testutils import ApiTestCase
from runs.models import Run

from .models import MedalAward

YAKUTSK_NOON_UTC = 3  # 12:00 Якутска = 03:00 UTC


def _run(uid, run_id, km, finished, zones=0, flagged=False, dur=None):
    return Run.objects.create(
        id=run_id,
        user_id=uid,
        distance_m=km * 1000,
        duration_s=dur if dur is not None else int(km * 360),
        captured_zones=zones,
        captured_territory=zones > 0,
        finished_at=finished,
        flagged=flagged,
    )


class MedalTests(ApiTestCase):
    phone = "+79993001001"

    def get(self):
        r = self.api_get("/v1/me/medals")
        self.assertEqual(r.status_code, 200)
        return r.json()

    def by_id(self, data, mid):
        return next(i for i in data["items"] if i["id"] == mid)

    def test_catalog_size_and_shape(self):
        data = self.get()
        self.assertEqual(data["total"], 44)
        self.assertEqual(len(data["items"]), 44)
        # Без пробежек ничего не заработано.
        self.assertEqual(data["earned"], 0)

    def test_first_run_awards_and_engraves(self):
        fin = datetime(2026, 8, 20, YAKUTSK_NOON_UTC, 0, tzinfo=dt_tz.utc)
        _run(self.uid, "r1", 5.2, fin)
        data = self.get()
        item = self.by_id(data, "d_first_run")
        self.assertIsNotNone(item["earnedAtMs"])
        self.assertTrue(item["new"])
        self.assertEqual(item["engraving"]["v"], "5,2 КМ")
        self.assertEqual(item["engraving"]["sub"], "20.08.2026")
        # Пятёрка без остановки тоже закрыта, гравировка — личное время.
        five = self.by_id(data, "d_run_5k")
        self.assertIsNotNone(five["earnedAtMs"])
        self.assertEqual(five["engraving"]["v"], "31:12")  # 5.2 км × 360 с/км

    def test_flagged_runs_do_not_count(self):
        fin = datetime(2026, 8, 20, YAKUTSK_NOON_UTC, 0, tzinfo=dt_tz.utc)
        _run(self.uid, "r1", 12, fin, flagged=True)
        data = self.get()
        self.assertIsNone(self.by_id(data, "d_first_run")["earnedAtMs"])

    def test_streak_and_progress(self):
        base = datetime(2026, 8, 1, YAKUTSK_NOON_UTC, 0, tzinfo=dt_tz.utc)
        for i in range(7):
            _run(self.uid, f"r{i}", 3, base + timedelta(days=i))
        data = self.get()
        self.assertIsNotNone(self.by_id(data, "r_streak_7")["earnedAtMs"])
        self.assertIsNotNone(self.by_id(data, "r_week_perfect")["earnedAtMs"])
        s30 = self.by_id(data, "r_streak_30")
        self.assertIsNone(s30["earnedAtMs"])
        self.assertEqual(s30["progress"], {"cur": 7, "target": 30})

    def test_award_is_permanent_and_idempotent(self):
        fin = datetime(2026, 8, 20, YAKUTSK_NOON_UTC, 0, tzinfo=dt_tz.utc)
        _run(self.uid, "r1", 5.0, fin)
        self.get()
        Run.objects.all().delete()  # данные ушли — медаль остаётся
        data = self.get()
        self.assertIsNotNone(self.by_id(data, "d_first_run")["earnedAtMs"])
        self.assertEqual(
            MedalAward.objects.filter(user_id=self.uid, medal_id="d_first_run").count(),
            1,
        )

    def test_territory_counters(self):
        fin = datetime(2026, 8, 20, YAKUTSK_NOON_UTC, 0, tzinfo=dt_tz.utc)
        for i in range(4):
            _run(self.uid, f"r{i}", 4, fin + timedelta(days=i), zones=3)
        data = self.get()
        self.assertIsNotNone(self.by_id(data, "t_first_zone")["earnedAtMs"])
        t10 = self.by_id(data, "t_zones_10")
        self.assertIsNotNone(t10["earnedAtMs"])
        self.assertEqual(t10["engraving"]["sub"], "23.08.2026")  # 4-й забег добил до 12
        self.assertEqual(self.by_id(data, "t_zones_50")["progress"]["cur"], 12)

    def test_night_capture_by_yakutsk_clock(self):
        # 17:00 UTC = 02:00 Якутска следующего дня — ночной захват.
        fin = datetime(2026, 8, 20, 17, 0, tzinfo=dt_tz.utc)
        _run(self.uid, "r1", 4, fin, zones=1, dur=1200)
        data = self.get()
        self.assertIsNotNone(self.by_id(data, "t_night_capture")["earnedAtMs"])
        # Старт 01:40 по Якутску — это «до 07:00» (рассвет), но не «после 23:00».
        self.assertIsNotNone(self.by_id(data, "d_dawn")["earnedAtMs"])
        self.assertIsNone(self.by_id(data, "d_midnight")["earnedAtMs"])

    def test_holiday_limited_medal(self):
        fin = datetime(2026, 5, 9, YAKUTSK_NOON_UTC, 0, tzinfo=dt_tz.utc)
        _run(self.uid, "r1", 9.5, fin)
        data = self.get()
        pob = self.by_id(data, "l_pobeda_2026")
        self.assertIsNotNone(pob["earnedAtMs"])
        self.assertEqual(pob["engraving"]["u"], "ДЕНЬ ПОБЕДЫ")
        # 9 мая, но меньше 9 км — не считается.
        MedalAward.objects.all().delete()
        Run.objects.all().delete()
        _run(self.uid, "r2", 5, fin)
        data = self.get()
        self.assertIsNone(self.by_id(data, "l_pobeda_2026")["earnedAtMs"])

    def test_unavailable_have_no_progress(self):
        data = self.get()
        for mid in ("r_goal_first", "d_frost_40", "s_div_gold", "l_city_2026"):
            item = self.by_id(data, mid)
            self.assertFalse(item["available"])
            self.assertIsNone(item["earnedAtMs"])
            self.assertNotIn("progress", item)

    def test_requires_token(self):
        r = self.client.get("/v1/me/medals")
        self.assertEqual(r.status_code, 401)
