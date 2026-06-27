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


class ClubStyleTerritoryTests(ApiTestCase):
    phone = "+79990004020"

    def _club(self, name="Стиль-клуб"):
        return self.api_post("/v1/clubs", {"name": name}).json()["id"]

    def test_style_default_and_patch(self):
        cid = self._club()
        d = self.api_get(f"/v1/clubs/{cid}").json()
        self.assertEqual(d["style"], "minimal")  # дефолт
        self.assertIsNone(d["cover"])
        r = self.api_patch(f"/v1/clubs/{cid}", {"style": "fire"})
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["style"], "fire")

    def test_unknown_style_falls_back_to_minimal(self):
        cid = self._club("Стиль2")
        r = self.api_patch(f"/v1/clubs/{cid}", {"style": "rainbow-unicorn"})
        self.assertEqual(r.json()["style"], "minimal")

    def test_detail_has_territory_zero_for_new_club(self):
        cid = self._club("Терр")
        t = self.api_get(f"/v1/clubs/{cid}").json()["territory"]
        self.assertEqual(t["areaM2"], 0)
        self.assertEqual(t["pieces"], 0)


class ClubChallengeTests(ApiTestCase):
    phone = "+79990004030"

    def _club(self):
        return self.api_post("/v1/clubs", {"name": "Челлендж-клуб"}).json()["id"]

    def _delete(self, path, token=None):
        return self.client.delete(
            path, HTTP_AUTHORIZATION=f"Bearer {token or self.token}"
        )

    def test_no_challenge_by_default(self):
        cid = self._club()
        self.assertIsNone(self.api_get(f"/v1/clubs/{cid}").json()["challenge"])

    def test_create_challenge_appears_in_detail(self):
        cid = self._club()
        r = self.api_post(
            f"/v1/clubs/{cid}/challenge",
            {"title": "Цель недели", "targetKm": 50, "days": 7},
        )
        self.assertEqual(r.status_code, 200)
        ch = r.json()["challenge"]
        self.assertEqual(ch["title"], "Цель недели")
        self.assertEqual(ch["targetKm"], 50.0)
        self.assertEqual(ch["currentKm"], 0.0)
        self.assertGreaterEqual(ch["daysLeft"], 6)

    def test_challenge_requires_title_and_positive_target(self):
        cid = self._club()
        self.assertEqual(
            self.api_post(
                f"/v1/clubs/{cid}/challenge", {"title": "", "targetKm": 10}
            ).status_code,
            400,
        )
        self.assertEqual(
            self.api_post(
                f"/v1/clubs/{cid}/challenge", {"title": "Ц", "targetKm": 0}
            ).status_code,
            400,
        )

    def test_challenge_owner_only(self):
        cid = self._club()
        t2 = self.new_user("+79990004031")
        self.api_post(f"/v1/clubs/{cid}/join", {}, token=t2)
        r = self.api_post(
            f"/v1/clubs/{cid}/challenge",
            {"title": "Ц", "targetKm": 10},
            token=t2,
        )
        self.assertEqual(r.status_code, 403)

    def test_only_one_active_challenge(self):
        cid = self._club()
        self.api_post(
            f"/v1/clubs/{cid}/challenge", {"title": "Первый", "targetKm": 10}
        )
        r = self.api_post(
            f"/v1/clubs/{cid}/challenge", {"title": "Второй", "targetKm": 20}
        )
        self.assertEqual(r.json()["challenge"]["title"], "Второй")

    def test_cancel_challenge(self):
        cid = self._club()
        self.api_post(
            f"/v1/clubs/{cid}/challenge", {"title": "Ц", "targetKm": 10}
        )
        d = self._delete(f"/v1/clubs/{cid}/challenge")
        self.assertEqual(d.status_code, 200)
        self.assertIsNone(d.json()["challenge"])
