"""Продуктовая аналитика (D-30): поток событий (track + POST /v1/events),
серверная инструментация ключевых действий, ретеншн по когортам."""
import time

from django.test import TestCase

from analytics.models import (
    E_LOGIN,
    E_PURCHASE,
    E_REGISTER,
    E_RUN_FINISHED,
    Event,
    track,
)
from common.testutils import ApiTestCase


class TrackTests(TestCase):
    def test_track_creates_event_with_props(self):
        e = track("custom_event", user_id="u1", source="server", foo="bar")
        self.assertIsNotNone(e)
        self.assertEqual(Event.objects.filter(name="custom_event", user_id="u1").count(), 1)
        self.assertEqual(e.props["foo"], "bar")

    def test_track_empty_name_ignored(self):
        self.assertIsNone(track(""))
        self.assertEqual(Event.objects.count(), 0)


class EventsEndpointTests(ApiTestCase):
    phone = "+79990011001"

    def test_post_single_event_bound_to_uid(self):
        r = self.api_post(
            "/v1/events",
            {"name": "screen_view", "source": "store", "props": {"screen": "cart"}},
        )
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["accepted"], 1)
        e = Event.objects.get(name="screen_view")
        self.assertEqual(e.user_id, self.uid)  # привязано к токену, не к телу
        self.assertEqual(e.source, "store")
        self.assertEqual(e.props["screen"], "cart")

    def test_post_batch_skips_empty_names(self):
        r = self.api_post(
            "/v1/events",
            {"events": [{"name": "a"}, {"name": "b", "source": "site"}, {"name": ""}]},
        )
        self.assertEqual(r.json()["accepted"], 2)

    def test_client_cannot_forge_server_source(self):
        self.api_post("/v1/events", {"name": "x", "source": "server"})
        self.assertEqual(Event.objects.get(name="x").source, "client")  # server → client

    def test_events_requires_auth(self):
        self.assertEqual(self.client.post("/v1/events").status_code, 401)


class ServerInstrumentationTests(ApiTestCase):
    phone = "+79990011002"

    def test_run_finished_tracked(self):
        self.api_post(
            "/v1/runs",
            {
                "id": "r1", "distanceMeters": 5000, "elapsedSeconds": 1800,
                "finishedAtMs": int(time.time() * 1000),
            },
        )
        self.assertTrue(
            Event.objects.filter(name=E_RUN_FINISHED, user_id=self.uid).exists()
        )

    def test_purchase_tracked_with_total(self):
        self.api_post("/v1/orders", {"id": "o1", "total": 500, "items": []})
        e = Event.objects.get(name=E_PURCHASE, user_id=self.uid)
        self.assertEqual(e.props["total"], 500)

    def test_auth_tracked_on_verify(self):
        # setUp уже дернул phone/verify (создание аккаунта) → есть событие регистрации/входа.
        self.assertTrue(
            Event.objects.filter(
                user_id=self.uid, name__in=[E_REGISTER, E_LOGIN]
            ).exists()
        )


class RetentionTests(TestCase):
    def test_cohort_counts_registration_and_week0_activity(self):
        from accounts.models import Account
        from analytics.retention import weekly_cohorts
        from loyalty.models import add_txn

        # Регистрация на этой неделе (created_at=now) + активность (txn) на этой же неделе.
        Account.objects.create(id="u_ret", email="ret@t.local")
        add_txn("u_ret", 50, "runnerRun")
        cohorts = weekly_cohorts(weeks=4)
        latest = cohorts[0]  # свежие когорты сверху → текущая неделя
        self.assertEqual(latest["size"], 1)
        self.assertEqual(latest["retention"][0]["active"], 1)  # week-0 активен
        self.assertEqual(latest["retention"][0]["pct"], 100.0)

    def test_no_registrations_empty_cohorts(self):
        from analytics.retention import weekly_cohorts

        cohorts = weekly_cohorts(weeks=3)
        self.assertEqual(len(cohorts), 3)
        self.assertTrue(all(c["size"] == 0 for c in cohorts))
