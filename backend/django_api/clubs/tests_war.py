"""«Война района» (Ф6): позиции клубов по земле и лента угроз недели."""
from django.db import connection

from common.testutils import ApiTestCase


class WarTests(ApiTestCase):
    phone = "+79992004001"

    def _insert_event(self, victim, attacker, area=1500.0):
        with connection.cursor() as cur:
            cur.execute(
                "INSERT INTO territory_events (victim_owner, attacker, area_m2) "
                "VALUES (%s, %s, %s)",
                [victim, attacker, area],
            )

    def test_war_shape_without_club(self):
        r = self.api_get("/v1/clubs/war")
        self.assertEqual(r.status_code, 200)
        body = r.json()
        self.assertIn("standings", body)
        self.assertIn("threats", body)

    def test_threats_include_my_losses(self):
        self._insert_event(self.uid, "u_attacker_123", 2000.0)
        r = self.api_get("/v1/clubs/war")
        threats = r.json()["threats"]
        self.assertEqual(len(threats), 1)
        self.assertTrue(threats[0]["mine"])
        self.assertEqual(threats[0]["areaM2"], 2000.0)

    def test_other_victims_not_in_my_feed(self):
        self._insert_event("u_stranger_9", "u_attacker_123", 500.0)
        r = self.api_get("/v1/clubs/war")
        self.assertEqual(r.json()["threats"], [])
