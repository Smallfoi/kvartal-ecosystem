"""Регрессии анти-чита бега (S-04 Phase 1): сервер сам считает очки, чит → flagged/0."""
from common.testutils import ApiTestCase

_OK = {"distanceMeters": 5000, "elapsedSeconds": 1800, "finishedAtMs": 1750000000000}


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
             "finishedAtMs": 1750000000000},
        ).json()
        self.assertTrue(r["flagged"])
        self.assertEqual(r["pointsAwarded"], 0)
        self.assertEqual(self.balance(), 0)

    def test_distance_cheat_flagged(self):
        r = self.api_post(
            "/v1/runs",
            {"id": "r3", "distanceMeters": 500000, "elapsedSeconds": 200000,
             "finishedAtMs": 1750000000000},
        ).json()
        self.assertTrue(r["flagged"])
        self.assertEqual(self.balance(), 0)

    def test_client_cannot_mint_runner_run(self):
        r = self.api_post(
            "/v1/loyalty/transactions",
            {"amount": 9999, "source": "runnerRun", "runId": "x"},
        )
        self.assertEqual(r.status_code, 403)
        self.assertEqual(self.balance(), 0)
