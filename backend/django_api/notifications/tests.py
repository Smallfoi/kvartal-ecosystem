"""Каркас пушей (D-25): регистрация устройств + send_push (no-op без провайдера)."""
import os
from unittest import mock

from common.testutils import ApiTestCase
from notifications.models import DeviceToken, create_notification
from notifications.push import push_enabled, send_push


class PushScaffoldTests(ApiTestCase):
    phone = "+79990005001"

    def test_push_disabled_by_default(self):
        self.assertFalse(push_enabled())
        DeviceToken.objects.create(user_id=self.uid, token="t1", platform="android")
        self.assertEqual(send_push(self.uid, "Привет", "тест"), 0)  # no-op

    def test_register_device_stores_token(self):
        r = self.api_post(
            "/v1/devices/register", {"token": "abc123", "platform": "android"}
        )
        self.assertEqual(r.status_code, 200)
        self.assertTrue(
            DeviceToken.objects.filter(token="abc123", user_id=self.uid).exists()
        )

    def test_create_notification_works_without_push(self):
        n = create_notification(self.uid, "Заказ готов", "тест")
        self.assertIsNotNone(n)  # уведомление создано, пуш — no-op

    @mock.patch.dict(os.environ, {"PUSH_PROVIDER": "rustore"})
    def test_rustore_stub_without_key_sends_zero(self):
        self.assertTrue(push_enabled())
        DeviceToken.objects.create(user_id=self.uid, token="t2", platform="android")
        self.assertEqual(send_push(self.uid, "x", "y"), 0)  # нет RUSTORE_PUSH_KEY


class NotificationFeedTests(ApiTestCase):
    """Лента уведомлений и пометка прочитанным (GET /notifications, POST .../read)."""
    phone = "+79990005002"

    def test_feed_lists_own_notifications(self):
        create_notification(self.uid, "Заказ принят")
        create_notification(self.uid, "Новый уровень")
        data = self.api_get("/v1/notifications").json()
        self.assertEqual({n["title"] for n in data}, {"Заказ принят", "Новый уровень"})
        self.assertFalse(data[0]["read"])

    def test_feed_isolated_per_user(self):
        create_notification("u_other", "Чужое")
        create_notification(self.uid, "Моё")
        data = self.api_get("/v1/notifications").json()
        self.assertEqual([n["title"] for n in data], ["Моё"])

    def test_read_all(self):
        create_notification(self.uid, "a")
        create_notification(self.uid, "b")
        self.assertEqual(self.api_post("/v1/notifications/read", {}).json()["marked"], 2)
        self.assertTrue(all(n["read"] for n in self.api_get("/v1/notifications").json()))

    def test_read_specific_ids(self):
        n1 = create_notification(self.uid, "a")
        create_notification(self.uid, "b")
        self.assertEqual(
            self.api_post("/v1/notifications/read", {"ids": [n1.pk]}).json()["marked"], 1
        )
        by_title = {
            n["title"]: n["read"] for n in self.api_get("/v1/notifications").json()
        }
        self.assertTrue(by_title["a"])
        self.assertFalse(by_title["b"])

    def test_read_idempotent(self):
        create_notification(self.uid, "a")
        self.api_post("/v1/notifications/read", {})
        self.assertEqual(self.api_post("/v1/notifications/read", {}).json()["marked"], 0)

    def test_feed_requires_auth(self):
        self.assertEqual(self.client.get("/v1/notifications").status_code, 401)
        self.assertEqual(self.client.post("/v1/notifications/read").status_code, 401)
