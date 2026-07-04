"""Рейтинг (D-11): личный (км из runnerRun-начислений/10), клубный (сумма км
участников), районный (площадь удерживаемых территорий, PostGIS). Периоды week/all."""
from datetime import timedelta

from django.db import connection
from django.utils import timezone

from accounts.models import Account
from clubs.models import Club, ClubMember
from common.security import normalize_phone
from common.testutils import ApiTestCase
from loyalty.models import LoyaltyTransaction


class LeaderboardTests(ApiTestCase):
    phone = "+79990009001"
    _n = 0

    def _run_txn(self, uid, amount, when=None):
        LeaderboardTests._n += 1
        LoyaltyTransaction.objects.create(
            id=f"tx_lb_{LeaderboardTests._n}",
            user_id=uid, amount=amount, source="runnerRun",
            created_at=when or timezone.now(),
        )

    def _account(self, phone, name):
        return Account.objects.create(
            id=f"u_{phone[-4:]}", phone=normalize_phone(phone), name=name,
            email=f"{phone[-4:]}@t.local",
        ).id

    def _club(self):
        Club.objects.create(id="c1", name="Скороходы", owner_id=self.uid)
        ClubMember.objects.create(club_id="c1", user_id=self.uid, role="owner")

    # ── Личный рейтинг ────────────────────────────────────────────────────────

    def test_users_ranking_by_km(self):
        other = self._account("+79990009002", "Гонщик")
        self._run_txn(self.uid, 50)   # 5 км
        self._run_txn(other, 100)     # 10 км
        d = self.api_get("/v1/leaderboard/users?period=all").json()
        self.assertEqual(d["top"][0]["userId"], other)
        self.assertEqual(d["top"][0]["km"], 10.0)
        self.assertEqual(d["top"][1]["userId"], self.uid)
        self.assertTrue(d["top"][1]["isMe"])
        self.assertEqual(d["me"], {"rank": 2, "km": 5.0})

    def test_users_period_filters_old(self):
        self._run_txn(self.uid, 50)  # эта неделя → 5 км
        self._run_txn(self.uid, 100, timezone.now() - timedelta(days=40))  # старьё
        self.assertEqual(
            self.api_get("/v1/leaderboard/users?period=week").json()["me"]["km"], 5.0
        )
        self.assertEqual(
            self.api_get("/v1/leaderboard/users?period=all").json()["me"]["km"], 15.0
        )

    def test_users_zero_km_not_ranked(self):
        d = self.api_get("/v1/leaderboard/users?period=all").json()
        self.assertEqual(d["top"], [])
        self.assertIsNone(d["me"]["rank"])

    def test_users_requires_auth(self):
        self.assertEqual(self.client.get("/v1/leaderboard/users").status_code, 401)

    # ── Клубный рейтинг ───────────────────────────────────────────────────────

    def test_clubs_ranking_sums_members(self):
        self._club()
        self._run_txn(self.uid, 80)  # 8 км
        d = self.api_get("/v1/leaderboard/clubs?period=all").json()
        mine = [c for c in d["top"] if c["id"] == "c1"][0]
        self.assertEqual(mine["km"], 8.0)
        self.assertEqual(mine["members"], 1)
        self.assertTrue(mine["isMine"])

    # ── Районы (территории, PostGIS) ──────────────────────────────────────────

    def test_districts_ranking_by_area(self):
        self._club()
        g = "ST_GeomFromText('MULTIPOLYGON(((0 0,0 0.01,0.01 0.01,0.01 0,0 0)))',4326)"
        with connection.cursor() as cur:
            cur.execute(
                "INSERT INTO territories (id, owner_id, club_id, geom, captured_at) "
                f"VALUES ('t1','{self.uid}','c1',{g}, now())"
            )
        d = self.api_get("/v1/leaderboard/districts").json()
        self.assertTrue(any(c["id"] == "c1" and c["areaM2"] > 0 for c in d["top"]))

    def test_districts_requires_auth(self):
        self.assertEqual(self.client.get("/v1/leaderboard/districts").status_code, 401)
