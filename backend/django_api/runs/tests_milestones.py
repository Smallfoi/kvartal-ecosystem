"""Вехи пожизненных км: пересечение начисляет один раз, /me/stats отдаёт цель."""
from datetime import datetime, timezone as dt_tz

from common.testutils import ApiTestCase
from loyalty.models import LoyaltyTransaction, balance_of

from .milestones import award_milestones, next_milestone
from .models import Run


class MilestoneTests(ApiTestCase):
    phone = "+79992002001"

    def _run(self, run_id, km):
        return Run.objects.create(
            id=run_id,
            user_id=self.uid,
            distance_m=km * 1000,
            duration_s=int(km * 360),
            finished_at=datetime(2026, 8, 20, 10, 0, tzinfo=dt_tz.utc),
        )

    def test_crossing_awards_once(self):
        self._run("r_ms1", 20)
        self._run("r_ms2", 10)  # 30 км — пересекли веху 25
        before = balance_of(self.uid)
        awarded = award_milestones(self.uid, 10)
        self.assertEqual(awarded, 50)
        self.assertEqual(balance_of(self.uid), before + 50)
        # повтор — ноль
        self.assertEqual(award_milestones(self.uid, 10), 0)
        self.assertEqual(
            LoyaltyTransaction.objects.filter(
                user_id=self.uid, source="runnerMilestone"
            ).count(),
            1,
        )

    def test_multiple_milestones_one_run(self):
        self._run("r_ms3", 60)  # 0 → 60: вехи 25 и 50
        self.assertEqual(award_milestones(self.uid, 60), 100)

    def test_next_milestone_shape(self):
        nm = next_milestone(1964.0)
        self.assertEqual(nm["atKm"], 2000)
        self.assertEqual(nm["leftKm"], 36.0)
        self.assertEqual(nm["reward"], 50)

    def test_post_run_awards_milestone(self):
        r = self.api_post(
            "/v1/runs",
            {
                "id": "r_ms_api",
                "distanceMeters": 26000,
                "elapsedSeconds": 26 * 400,
                "finishedAtMs": int(
                    datetime.now(dt_tz.utc).timestamp() * 1000
                ),
            },
        )
        self.assertEqual(r.status_code, 200)
        self.assertTrue(
            LoyaltyTransaction.objects.filter(
                user_id=self.uid, source="runnerMilestone", run_id="ms:25"
            ).exists()
        )

    def test_stats_contains_milestone_and_streak(self):
        r = self.api_get("/v1/me/stats")
        body = r.json()
        self.assertIn("milestone", body)
        self.assertIn("streak", body)
        self.assertEqual(body["milestone"]["atKm"], 25)
        self.assertEqual(body["streak"]["weeks"], 0)

    def test_digest_shape(self):
        r = self.api_get("/v1/me/digest")
        self.assertEqual(r.status_code, 200)
        body = r.json()
        for key in ("weekKm", "weekRuns", "earnedPoints", "territories"):
            self.assertIn(key, body)
