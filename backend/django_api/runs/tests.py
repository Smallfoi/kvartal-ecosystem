"""Регрессии анти-чита бега (S-04): сервер сам считает очки, чит/реплей → flagged/0."""
import time

from common.testutils import ApiTestCase

_NOW_MS = int(time.time() * 1000)
_DAY_MS = 86_400_000
# Базовый правдоподобный забег: 5 км за 30 мин (10 км/ч), завершён только что.
_OK = {"distanceMeters": 5000, "elapsedSeconds": 1800, "finishedAtMs": _NOW_MS}


class RunAntiCheatTests(ApiTestCase):
    phone = "+79990002001"

    def test_valid_run_awards_server_side(self):
        r = self.api_post("/v1/runs", {"id": "r1", **_OK}).json()
        self.assertFalse(r["flagged"])
        self.assertEqual(r["pointsAwarded"], 50)  # 5 км × 10
        self.assertEqual(self.balance(), 50)

    def test_duplicate_run_no_double_award(self):
        self.api_post("/v1/runs", {"id": "r1", **_OK})
        r = self.api_post("/v1/runs", {"id": "r1", **_OK}).json()
        self.assertTrue(r["duplicate"])
        self.assertEqual(self.balance(), 50)

    def test_speed_cheat_flagged_zero(self):
        r = self.api_post(
            "/v1/runs",
            {"id": "r2", "distanceMeters": 5000, "elapsedSeconds": 10,
             "finishedAtMs": _NOW_MS},
        ).json()
        self.assertTrue(r["flagged"])
        self.assertEqual(r["pointsAwarded"], 0)
        self.assertEqual(self.balance(), 0)

    def test_distance_cheat_flagged(self):
        r = self.api_post(
            "/v1/runs",
            {"id": "r3", "distanceMeters": 500000, "elapsedSeconds": 200000,
             "finishedAtMs": _NOW_MS},
        ).json()
        self.assertTrue(r["flagged"])
        self.assertEqual(self.balance(), 0)

    def test_future_run_flagged(self):
        r = self.api_post(
            "/v1/runs",
            {"id": "r4", "distanceMeters": 5000, "elapsedSeconds": 1800,
             "finishedAtMs": _NOW_MS + 2 * _DAY_MS},
        ).json()
        self.assertTrue(r["flagged"])
        self.assertEqual(self.balance(), 0)

    def test_old_run_flagged_replay(self):
        r = self.api_post(
            "/v1/runs",
            {"id": "r5", "distanceMeters": 5000, "elapsedSeconds": 1800,
             "finishedAtMs": _NOW_MS - 40 * _DAY_MS},
        ).json()
        self.assertTrue(r["flagged"])
        self.assertEqual(self.balance(), 0)

    def test_too_many_runs_per_day_flagged(self):
        # 30 валидных забегов за сутки — ок; 31-й → flagged (анти-спам).
        for i in range(30):
            r = self.api_post(
                "/v1/runs",
                {"id": f"rc{i}", "distanceMeters": 1000, "elapsedSeconds": 600,
                 "finishedAtMs": _NOW_MS},
            ).json()
            self.assertFalse(r["flagged"], f"забег {i} должен быть валидным")
        over = self.api_post(
            "/v1/runs",
            {"id": "rc_over", "distanceMeters": 1000, "elapsedSeconds": 600,
             "finishedAtMs": _NOW_MS},
        ).json()
        self.assertTrue(over["flagged"])
        self.assertEqual(over["pointsAwarded"], 0)

    def test_client_cannot_mint_runner_run(self):
        r = self.api_post(
            "/v1/loyalty/transactions",
            {"amount": 9999, "source": "runnerRun", "runId": "x"},
        )
        self.assertEqual(r.status_code, 403)
        self.assertEqual(self.balance(), 0)
