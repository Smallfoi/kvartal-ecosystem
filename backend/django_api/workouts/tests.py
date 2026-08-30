"""Импорт тренировок извне.

Проверяем ровно то, из-за чего импорт может превратиться в дыру: повторную
присылку, двойной учёт одного выхода на пробежку (часы + телефон) и обход
суточного лимита через второй источник.
"""
from datetime import timedelta

from django.utils import timezone

from common.testutils import ApiTestCase
from loyalty.models import LoyaltyTransaction
from runs.models import Run
from workouts.models import ExternalWorkout


class WorkoutImportTests(ApiTestCase):
    phone = "+79990009401"
    _n = 0

    def _item(self, km=5.0, minutes=30, source_id=None, when=None, **extra):
        WorkoutImportTests._n += 1
        started = when or (timezone.now() - timedelta(hours=2))
        return {
            "sourceId": source_id or f"hc_{WorkoutImportTests._n}",
            "startedAtMs": int(started.timestamp() * 1000),
            "durationS": minutes * 60,
            "distanceM": km * 1000,
            **extra,
        }

    def _import(self, items, source="healthconnect"):
        return self.api_post("/v1/workouts/import", {"source": source, "items": items})

    def _balance(self):
        return sum(t.amount for t in LoyaltyTransaction.objects.filter(user_id=self.uid))

    # ── основное ────────────────────────────────────────────────────────────

    def test_import_creates_workout_and_points(self):
        r = self._import([self._item(km=5)])
        self.assertEqual(r.status_code, 200)
        body = r.json()
        self.assertEqual(body["imported"], 1)
        self.assertEqual(body["points"], 50)          # 5 км × 10
        self.assertEqual(self._balance(), 50)

    def test_same_workout_twice_is_not_counted_twice(self):
        """Источники присылают одно и то же по многу раз — это норма."""
        item = self._item(km=4, source_id="fixed-1")
        self._import([item])
        r = self._import([item])
        self.assertEqual(r.json()["imported"], 0)
        self.assertEqual(r.json()["duplicates"], 1)
        self.assertEqual(self._balance(), 40)          # не 80
        self.assertEqual(ExternalWorkout.objects.filter(user_id=self.uid).count(), 1)

    def test_watch_workout_and_own_run_count_once(self):
        """Бежал с часами и с телефоном — это один выход, а не два."""
        started = timezone.now() - timedelta(hours=1)
        Run.objects.create(
            id="run_dup_1", user_id=self.uid, distance_m=6000, duration_s=1800,
            finished_at=started + timedelta(minutes=30), points_awarded=60,
        )
        r = self._import([self._item(km=6.2, minutes=30, when=started)])
        body = r.json()
        self.assertEqual(body["imported"], 1)
        self.assertEqual(body["points"], 0)            # очки уже дал наш забег
        self.assertTrue(body["items"][0]["duplicateOfRun"])
        self.assertEqual(self._balance(), 0)           # за сам забег в этом тесте не начисляли

    def test_different_run_same_day_still_counts(self):
        """Утренний забег и вечерняя тренировка с часов — разные события."""
        morning = timezone.now() - timedelta(hours=8)
        Run.objects.create(
            id="run_morning", user_id=self.uid, distance_m=5000, duration_s=1500,
            finished_at=morning,
        )
        r = self._import([self._item(km=7, when=timezone.now() - timedelta(hours=1))])
        self.assertEqual(r.json()["points"], 70)
        self.assertFalse(r.json()["items"][0]["duplicateOfRun"])

    # ── античит ─────────────────────────────────────────────────────────────

    def test_impossible_speed_is_flagged_without_points(self):
        r = self._import([self._item(km=40, minutes=20)])   # 120 км/ч
        self.assertEqual(r.json()["points"], 0)
        self.assertTrue(r.json()["items"][0]["flagged"])

    def test_future_workout_flagged(self):
        r = self._import([self._item(when=timezone.now() + timedelta(days=2))])
        self.assertTrue(r.json()["items"][0]["flagged"])

    def test_daily_limit_counts_own_runs_too(self):
        """Суточный потолок общий: второй источник не должен его обходить."""
        today = timezone.now().replace(hour=6, minute=0, second=0, microsecond=0)
        Run.objects.create(
            id="run_big", user_id=self.uid, distance_m=140_000, duration_s=40_000,
            finished_at=today,
        )
        r = self._import([self._item(km=30, minutes=200, when=today + timedelta(hours=2))])
        self.assertTrue(r.json()["items"][0]["flagged"])
        self.assertEqual(r.json()["points"], 0)

    def test_cycling_is_imported_but_gives_no_running_points(self):
        r = self._import([self._item(km=30, minutes=60, sport="biking")])
        self.assertEqual(r.json()["imported"], 1)
        self.assertEqual(r.json()["points"], 0)

    def test_garbage_items_are_skipped_not_fatal(self):
        r = self._import([{"nonsense": True}, self._item(km=3)])
        self.assertEqual(r.json()["skipped"], 1)
        self.assertEqual(r.json()["imported"], 1)

    # ── чтение и отключение ─────────────────────────────────────────────────

    def test_list_returns_only_mine(self):
        self._import([self._item(km=3)])
        ExternalWorkout.objects.create(
            id="foreign", user_id="someone_else", source="healthconnect",
            source_id="x", started_at=timezone.now(), duration_s=600, distance_m=1000,
        )
        items = self.api_get("/v1/workouts/").json()["items"]
        self.assertEqual(len(items), 1)

    def test_disconnect_removes_source_data(self):
        """Отключил источник — данные уходят. Баллы остаются: он их заработал."""
        self._import([self._item(km=5)])
        r = self.client.delete(
            "/v1/workouts/source/healthconnect",
            HTTP_AUTHORIZATION=f"Bearer {self.token}",
        )
        self.assertEqual(r.status_code, 200)
        self.assertEqual(ExternalWorkout.objects.filter(user_id=self.uid).count(), 0)
        self.assertEqual(self._balance(), 50)

    def test_unknown_source_rejected(self):
        self.assertEqual(self._import([self._item()], source="nonsense").status_code, 400)

    def test_import_requires_auth(self):
        self.assertEqual(self.client.post("/v1/workouts/import").status_code, 401)
