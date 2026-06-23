"""Регрессии начисления за захват территории (S-04 Phase 2): сервер +50, идемпотентно."""
from common.testutils import ApiTestCase

# Прямоугольник ~5800 м² у Якутска (> MIN_CAPTURE_AREA_M2, < MAX).
_POLY = [[62.000, 129.700], [62.001, 129.700], [62.001, 129.701], [62.000, 129.701]]


class TerritoryAwardTests(ApiTestCase):
    phone = "+79990002003"

    def test_capture_awards_server_side(self):
        r = self.api_post(
            "/v1/territories/capture", {"points": _POLY, "captureId": "capA"}
        ).json()
        self.assertTrue(r["ok"])
        self.assertEqual(self.balance(), 50)

    def test_duplicate_capture_no_double(self):
        body = {"points": _POLY, "captureId": "capA"}
        self.api_post("/v1/territories/capture", body)
        r = self.api_post("/v1/territories/capture", body).json()
        self.assertTrue(r["duplicate"])
        self.assertEqual(self.balance(), 50)

    def test_speed_cheat_rejected(self):
        r = self.api_post(
            "/v1/territories/capture",
            {"points": _POLY, "captureId": "capFast",
             "distanceMeters": 5000, "elapsedSeconds": 10},
        )
        self.assertEqual(r.status_code, 400)
        self.assertEqual(self.balance(), 0)

    def test_client_cannot_mint_runner_territory(self):
        r = self.api_post(
            "/v1/loyalty/transactions",
            {"amount": 9999, "source": "runnerTerritory"},
        )
        self.assertEqual(r.status_code, 403)
        self.assertEqual(self.balance(), 0)
