"""Регрессии начисления за захват территории (S-04 Phase 2): сервер +50, идемпотентно.
+ плановая чистка протухших зон/защит (доводка Квартала)."""
from django.core.management import call_command
from django.db import connection
from django.test import TestCase

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


class TerritoryCleanupTests(TestCase):
    """Команда cleanup_territories удаляет ТОЛЬКО протухшее (>7д зоны, >24ч защита)."""

    _G = "ST_GeomFromText('MULTIPOLYGON(((0 0,0 1,1 1,1 0,0 0)))',4326)"

    def test_cleanup_removes_expired_only(self):
        with connection.cursor() as cur:
            cur.execute(
                "INSERT INTO territories (id, owner_id, geom, captured_at) "
                f"VALUES ('t_old','o_old',{self._G}, now() - interval '8 days')"
            )
            cur.execute(
                "INSERT INTO territories (id, owner_id, geom, captured_at) "
                f"VALUES ('t_new','o_new',{self._G}, now())"
            )
            cur.execute(
                "INSERT INTO recent_captures (owner_id, geom, captured_at) "
                f"VALUES ('o_old',{self._G}, now() - interval '2 days')"
            )
            cur.execute(
                "INSERT INTO recent_captures (owner_id, geom, captured_at) "
                f"VALUES ('o_new',{self._G}, now())"
            )
        call_command("cleanup_territories")
        with connection.cursor() as cur:
            cur.execute("SELECT owner_id FROM territories")
            rows = [r[0] for r in cur.fetchall()]
            self.assertEqual(rows, ["o_new"])  # протухшая удалена, свежая осталась
            cur.execute("SELECT count(*) FROM recent_captures")
            self.assertEqual(cur.fetchone()[0], 1)  # истёкшая защита удалена
