"""Регрессии клубов: один клуб на человека, вступление/выход, идемпотентность."""
from common.testutils import ApiTestCase


class ClubFlowTests(ApiTestCase):
    phone = "+79990004002"

    def _create(self, name="Тестовый клуб"):
        return self.api_post("/v1/clubs", {"name": name, "city": "Якутск"})

    def test_create_club_returns_id(self):
        r = self._create()
        self.assertEqual(r.status_code, 200)
        self.assertIn("id", r.json())

    def test_cannot_create_second_club(self):
        self._create()
        r = self._create("Второй")
        self.assertEqual(r.status_code, 409)  # уже состоит в клубе

    def test_my_club_returns_created(self):
        cid = self._create().json()["id"]
        r = self.api_get("/v1/clubs/me")
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["club"]["id"], cid)

    def test_open_club_join_dup_and_leave(self):
        cid = self._create().json()["id"]
        t2 = self.new_user("+79990004003")
        j = self.api_post(f"/v1/clubs/{cid}/join", {}, token=t2)
        self.assertEqual(j.status_code, 200)
        self.assertEqual(j.json()["status"], "joined")
        # повторное вступление, уже в клубе → 409
        self.assertEqual(self.api_post(f"/v1/clubs/{cid}/join", {}, token=t2).status_code, 409)
        # выход
        self.assertEqual(self.api_post(f"/v1/clubs/{cid}/leave", {}, token=t2).status_code, 200)

    def test_create_requires_name(self):
        r = self.api_post("/v1/clubs", {"name": "  "})
        self.assertEqual(r.status_code, 400)
