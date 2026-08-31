"""Дивизионы недели и сезоны (Квартал 2.0): назначение, места, движение,
идемпотентные закрытия с баллами."""
from datetime import datetime, timedelta, timezone as dt_tz

from accounts.models import Account
from common.testutils import ApiTestCase
from loyalty.models import LoyaltyTransaction, balance_of
from runs.models import Run

from . import divisions, seasons
from .models import Division, DivisionMember, SeasonResult


def _uid(test, phone):
    """new_user возвращает токен; для моделей нужен id аккаунта."""
    test.new_user(phone)
    return Account.objects.get(phone=phone).id


def _run(uid, run_id, km, finished, flagged=False):
    return Run.objects.create(
        id=run_id,
        user_id=uid,
        distance_m=km * 1000,
        duration_s=int(km * 360),
        finished_at=finished,
        flagged=flagged,
    )


class DivisionTests(ApiTestCase):
    phone = "+79992001001"

    def setUp(self):
        super().setUp()
        self.now = datetime(2026, 8, 26, 10, 0, tzinfo=dt_tz.utc)  # среда
        self.week = divisions._week_start_date(self.now)

    def test_assign_creates_division_of_my_tier(self):
        div = divisions.assign_division(self.uid, now=self.now)
        self.assertEqual(div.tier, 0)  # без пробежек — «Асфальт»
        self.assertEqual(div.week_start, self.week)
        again = divisions.assign_division(self.uid, now=self.now)
        self.assertEqual(again.id, div.id)  # повторный вход — та же группа
        self.assertEqual(
            DivisionMember.objects.filter(user_id=self.uid).count(), 1
        )

    def test_same_tier_runners_share_division(self):
        other = _uid(self, "+79992001002")
        d1 = divisions.assign_division(self.uid, now=self.now)
        d2 = divisions.assign_division(other, now=self.now)
        self.assertEqual(d1.id, d2.id)

    def test_higher_tier_runner_gets_other_division(self):
        pro = _uid(self, "+79992001003")
        week_dt = datetime.combine(self.week, datetime.min.time(), tzinfo=dt_tz.utc)
        _run(pro, "r_pro_life", 300, week_dt - timedelta(days=30))
        d_me = divisions.assign_division(self.uid, now=self.now)
        d_pro = divisions.assign_division(pro, now=self.now)
        self.assertNotEqual(d_me.id, d_pro.id)
        self.assertEqual(d_pro.tier, 2)  # 300 км — «Улица»

    def test_payload_places_and_movement(self):
        other = _uid(self, "+79992001004")
        week_dt = datetime.combine(self.week, datetime.min.time(), tzinfo=dt_tz.utc)
        # позавчера соперник бежал больше; вчера-сегодня я обогнал
        _run(other, "r_o1", 5, week_dt + timedelta(hours=5))
        _run(self.uid, "r_m1", 3, week_dt + timedelta(hours=6))
        _run(self.uid, "r_m2", 4, self.now - timedelta(hours=2))
        divisions.assign_division(self.uid, now=self.now)
        divisions.assign_division(other, now=self.now)
        data = divisions.division_payload(self.uid, now=self.now)
        self.assertEqual(data["me"]["place"], 1)
        self.assertEqual(data["me"]["of"], 2)
        self.assertEqual(data["me"]["movement"], 1)  # был #2 сутки назад
        self.assertEqual(data["division"]["tierLabel"], "Асфальт")
        self.assertEqual(len(data["members"]), 2)
        self.assertTrue(data["members"][0]["isMe"])

    def test_close_awards_top3_once(self):
        week_dt = datetime.combine(self.week, datetime.min.time(), tzinfo=dt_tz.utc)
        _run(self.uid, "r_w1", 10, week_dt + timedelta(days=1))
        divisions.assign_division(self.uid, now=self.now)
        before = balance_of(self.uid)
        next_week = self.now + timedelta(days=7)
        divisions._close_finished_weeks(self.uid, now=next_week)
        self.assertEqual(balance_of(self.uid), before + 50)
        # повторное закрытие ничего не дублирует
        divisions._close_finished_weeks(self.uid, now=next_week)
        self.assertEqual(balance_of(self.uid), before + 50)
        div = Division.objects.get(week_start=self.week, tier=0)
        self.assertTrue(div.closed)

    def test_endpoint_shape(self):
        r = self.api_get("/v1/league/division")
        self.assertEqual(r.status_code, 200)
        body = r.json()
        self.assertIn("division", body)
        self.assertIn("members", body)
        self.assertEqual(body["zones"], {"up": 0.18, "down": 0.18})
        self.assertEqual(body["me"]["of"], 1)


class SeasonTests(ApiTestCase):
    phone = "+79992001010"

    def setUp(self):
        super().setUp()
        self.now = datetime(2026, 9, 2, 8, 0, tzinfo=dt_tz.utc)

    def test_close_snapshots_and_rewards_once(self):
        rival = _uid(self, "+79992001011")
        aug = datetime(2026, 8, 10, 10, 0, tzinfo=dt_tz.utc)
        _run(self.uid, "r_s1", 20, aug)
        _run(rival, "r_s2", 12, aug + timedelta(days=1))
        before = balance_of(self.uid)
        month = seasons.close_season_if_needed(now=self.now)
        self.assertEqual(month, "2026-08")
        self.assertEqual(balance_of(self.uid), before + 100)  # чемпион
        rows = SeasonResult.objects.filter(month=month).order_by("place")
        self.assertEqual([r.user_id for r in rows], [self.uid, rival])
        # повторное закрытие — ничего
        seasons.close_season_if_needed(now=self.now)
        self.assertEqual(balance_of(self.uid), before + 100)
        self.assertEqual(
            LoyaltyTransaction.objects.filter(
                user_id=self.uid, source="runnerSeason"
            ).count(),
            1,
        )

    def test_payload_me_and_top(self):
        _run(self.uid, "r_s3", 7, datetime(2026, 8, 15, 9, 0, tzinfo=dt_tz.utc))
        data = seasons.season_payload(self.uid, now=self.now)
        self.assertEqual(data["month"], "2026-08")
        self.assertEqual(data["me"]["place"], 1)
        self.assertEqual(data["top"][0]["userId"], self.uid)
        self.assertEqual(data["currentMonth"], "2026-09")

    def test_endpoint(self):
        r = self.api_get("/v1/league/season/latest")
        self.assertEqual(r.status_code, 200)
        self.assertIn("month", r.json())
