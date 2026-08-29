"""Зачёты лиги и профиль бегуна (docs/LEAGUE_PLAN.md, Э1).

Проверяем то, ради чего всё затевалось: одна и та же пробежка попадает в разные
зачёты, и в каждом побеждает другой человек. Медленный, но регулярный выигрывает
постоянство; возрастной — свою лигу; никто не видит себя «просто проигравшим».
"""
from datetime import timedelta

from django.utils import timezone

from accounts.models import Account
from clubs.models import Club, ClubMember
from common.security import normalize_phone
from common.testutils import ApiTestCase
from league.models import RunnerProfile
from runs.models import Run


class LeagueTests(ApiTestCase):
    phone = "+79990009101"
    _n = 0

    def _run(self, uid, km, when=None, flagged=False):
        LeagueTests._n += 1
        return Run.objects.create(
            id=f"run_lg_{LeagueTests._n}",
            user_id=uid,
            distance_m=km * 1000.0,
            duration_s=int(km * 360),
            finished_at=when or timezone.now(),
            flagged=flagged,
        )

    def _other(self, phone, name="Бегун"):
        """Ещё один бегун. new_user() из базового класса отдаёт токен, а здесь
        нужен user_id — заводим аккаунт напрямую, как в тестах рейтинга."""
        return Account.objects.create(
            id=f"u_lg_{phone[-4:]}",
            phone=normalize_phone(phone),
            name=name,
            email=f"lg{phone[-4:]}@t.local",
        ).id

    def _profile(self, uid, birth_year=None, gender=""):
        RunnerProfile.objects.update_or_create(
            user_id=uid, defaults={"birth_year": birth_year, "gender": gender}
        )

    # ── профиль ─────────────────────────────────────────────────────────────

    def test_profile_empty_by_default(self):
        r = self.api_get("/v1/runner/profile")
        self.assertEqual(r.status_code, 200)
        self.assertIsNone(r.json()["birthYear"])
        self.assertIsNone(r.json()["group"])

    def test_profile_saves_and_returns_group(self):
        r = self.api_post("/v1/runner/profile", {"birthYear": 1990, "gender": "m"})
        self.assertEqual(r.status_code, 200)
        body = r.json()
        self.assertEqual(body["birthYear"], 1990)
        self.assertEqual(body["group"]["gender"], "m")
        # Группа считается от текущего года, поэтому проверяем сам факт попадания.
        self.assertIn("–", body["group"]["age"] + "–")
        self.assertTrue(body["group"]["label"].startswith("Мужчины"))

    def test_profile_partial_update_keeps_other_fields(self):
        self.api_post("/v1/runner/profile", {"birthYear": 1990, "gender": "m"})
        self.api_post("/v1/runner/profile", {"level": "amateur"})
        body = self.api_get("/v1/runner/profile").json()
        self.assertEqual(body["birthYear"], 1990)
        self.assertEqual(body["level"], "amateur")

    def test_profile_can_be_cleared(self):
        self.api_post("/v1/runner/profile", {"birthYear": 1990})
        r = self.api_post("/v1/runner/profile", {"birthYear": None})
        self.assertIsNone(r.json()["birthYear"])

    def test_profile_rejects_nonsense(self):
        self.assertEqual(self.api_post("/v1/runner/profile", {"birthYear": 1700}).status_code, 400)
        self.assertEqual(self.api_post("/v1/runner/profile", {"gender": "x"}).status_code, 400)
        self.assertEqual(self.api_post("/v1/runner/profile", {"weeklyGoalKm": -5}).status_code, 400)

    def test_profile_requires_auth(self):
        self.assertEqual(self.client.get("/v1/runner/profile").status_code, 401)

    # ── зачёты ──────────────────────────────────────────────────────────────

    def test_absolute_ranks_by_kilometres(self):
        other = self._other("+79990009102", "Гонщик")
        self._run(self.uid, 5)
        self._run(other, 12)
        body = self.api_get("/v1/league/boards?board=absolute&period=week").json()
        self.assertEqual(body["top"][0]["userId"], other)
        self.assertEqual(body["me"]["place"], 2)
        self.assertEqual(body["me"]["value"], 5.0)

    def test_consistency_ranks_by_number_of_runs(self):
        """Тот же набор пробежек, а победитель другой — в этом весь смысл лиги."""
        other = self._other("+79990009103", "Гонщик")
        for _ in range(4):
            self._run(self.uid, 2)          # 8 км за четыре выхода
        self._run(other, 12)      # 12 км за один

        absolute = self.api_get("/v1/league/boards?board=absolute&period=week").json()
        self.assertEqual(absolute["top"][0]["userId"], other)

        consistency = self.api_get("/v1/league/boards?board=consistency&period=week").json()
        self.assertEqual(consistency["top"][0]["userId"], self.uid)
        self.assertEqual(consistency["me"]["value"], 4)

    def test_me_block_counts_people_behind(self):
        """«Ты обошёл N из M» — без этого таблица работает только на победителя."""
        slower = self._other("+79990009104", "Спокойный")
        self._run(self.uid, 10)
        self._run(slower, 3)
        me = self.api_get("/v1/league/boards?board=absolute&period=week").json()["me"]
        self.assertEqual(me["place"], 1)
        self.assertEqual(me["of"], 2)
        self.assertEqual(me["aheadOf"], 1)

    def test_flagged_runs_do_not_count(self):
        self._run(self.uid, 50, flagged=True)
        self._run(self.uid, 4)
        body = self.api_get("/v1/league/boards?board=absolute&period=week").json()
        self.assertEqual(body["me"]["value"], 4.0)

    def test_old_runs_out_of_period(self):
        self._run(self.uid, 30, when=timezone.now() - timedelta(days=120))
        self._run(self.uid, 6)
        week = self.api_get("/v1/league/boards?board=absolute&period=week").json()
        self.assertEqual(week["me"]["value"], 6.0)
        q90 = self.api_get("/v1/league/boards?board=absolute&period=q90").json()
        self.assertEqual(q90["me"]["value"], 6.0)   # 120 дней назад не попадает и в 90

    def test_mylane_needs_profile(self):
        self._run(self.uid, 5)
        body = self.api_get("/v1/league/boards?board=mylane&period=week").json()
        self.assertTrue(body["needsProfile"])
        self.assertEqual(body["top"], [])

    def test_mylane_compares_only_with_peers(self):
        """Своя лига: ровесники своего пола. Чужие в таблицу не попадают —
        иначе это обычный абсолютный зачёт под другим названием."""
        this_year = timezone.now().year
        peer = self._other("+79990009105", "Ровесник")       # ровесник
        elder = self._other("+79990009106", "Старший")      # старше на поколение
        woman = self._other("+79990009107", "Ровесница")      # ровесница, другой пол

        self._profile(self.uid, this_year - 35, "m")
        self._profile(peer, this_year - 33, "m")
        self._profile(elder, this_year - 55, "m")
        self._profile(woman, this_year - 34, "f")

        self._run(self.uid, 10)
        self._run(peer, 14)
        self._run(elder, 40)
        self._run(woman, 30)

        body = self.api_get("/v1/league/boards?board=mylane&period=week").json()
        ids = [t["userId"] for t in body["top"]]
        self.assertIn(peer, ids)
        self.assertNotIn(elder, ids)
        self.assertNotIn(woman, ids)
        self.assertEqual(body["me"]["of"], 2)
        self.assertEqual(body["group"]["age"], "30–39")

    def test_personal_compares_with_previous_week(self):
        self._run(self.uid, 12)
        self._run(self.uid, 9, when=timezone.now() - timedelta(days=7))
        body = self.api_get("/v1/league/boards?board=personal&period=week").json()
        me = body["me"]
        self.assertEqual(me["value"], 12.0)
        self.assertTrue(me["improved"])
        self.assertEqual(me["runs"], 1)

    def test_club_board_sums_members(self):
        mate = self._other("+79990009108", "Напарник")
        club = Club.objects.create(id="club_lg_1", name="Клуб Лиги", owner_id=self.uid)
        ClubMember.objects.create(club_id=club.id, user_id=self.uid, role="owner")
        ClubMember.objects.create(club_id=club.id, user_id=mate, role="member")
        self._run(self.uid, 7)
        self._run(mate, 5)
        body = self.api_get("/v1/league/boards?board=club&period=week").json()
        self.assertEqual(body["top"][0]["name"], "Клуб Лиги")
        self.assertEqual(body["top"][0]["value"], 12.0)

    def test_unknown_board_falls_back_to_absolute(self):
        self._run(self.uid, 3)
        body = self.api_get("/v1/league/boards?board=nonsense&period=week").json()
        self.assertEqual(body["board"], "absolute")

    def test_boards_require_auth(self):
        self.assertEqual(self.client.get("/v1/league/boards").status_code, 401)
