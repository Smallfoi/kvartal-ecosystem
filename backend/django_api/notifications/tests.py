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
