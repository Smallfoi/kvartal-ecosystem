"""Каркас пушей (D-25): регистрация устройств + send_push (no-op без провайдера)."""
import os
from unittest import mock

from django.test import override_settings

from common.testutils import ApiTestCase
from notifications.models import DeviceToken, create_notification
from notifications.push import push_enabled, send_push

# Боевой режим пушей: провайдер + ключи проекта RuStore. Сеть в тестах не трогаем —
# подменяется notifications.push._http (единственная точка сетевого ввода-вывода).
_RS_ENV = {
    "PUSH_PROVIDER": "rustore",
    "RUSTORE_PROJECT_ID": "proj-42",
    "RUSTORE_PUSH_KEY": "service-token-xyz",
}


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
    def test_rustore_without_keys_sends_zero(self):
        self.assertTrue(push_enabled())
        DeviceToken.objects.create(user_id=self.uid, token="t2", platform="android")
        self.assertEqual(send_push(self.uid, "x", "y"), 0)  # нет ключей проекта


class RuStorePushTests(ApiTestCase):
    """Боевая отправка через RuStore Push (VK PNS). Сеть подменена."""
    phone = "+79990005005"

    def _token(self, value):
        DeviceToken.objects.create(user_id=self.uid, token=value, platform="android")

    @mock.patch.dict(os.environ, _RS_ENV)
    @mock.patch("notifications.push._http")
    def test_sends_to_all_devices_with_correct_request(self, http):
        http.return_value = {}
        self._token("dev-1")
        self._token("dev-2")
        self.assertEqual(send_push(self.uid, "Заказ готов", "Ждём вас"), 2)

        url, payload, headers = http.call_args[0]
        self.assertEqual(url, "https://vkpns.rustore.ru/v1/projects/proj-42/messages:send")
        self.assertEqual(headers["Authorization"], "Bearer service-token-xyz")
        self.assertEqual(payload["message"]["notification"]["title"], "Заказ готов")
        self.assertEqual(payload["message"]["notification"]["body"], "Ждём вас")
        self.assertIn(payload["message"]["token"], ("dev-1", "dev-2"))

    @mock.patch.dict(os.environ, _RS_ENV)
    @mock.patch("notifications.push._http")
    def test_dead_token_is_deleted(self, http):
        """Приложение удалили → NOT_FOUND. Такой токен мёртв, чистим базу."""
        from notifications.push import DeadToken

        http.side_effect = DeadToken("нет такого токена")
        self._token("stale")
        self.assertEqual(send_push(self.uid, "x", "y"), 0)
        self.assertFalse(DeviceToken.objects.filter(token="stale").exists())

    @mock.patch.dict(os.environ, _RS_ENV)
    @mock.patch("notifications.push._http")
    def test_provider_error_keeps_token_and_does_not_raise(self, http):
        """Отказ провайдера (например, неверный ключ) не должен ни ронять поток,
        ни удалять живой токен устройства."""
        from notifications.push import PushError

        http.side_effect = PushError("RuStore 403 PERMISSION_DENIED: bad key")
        self._token("alive")
        self.assertEqual(send_push(self.uid, "x", "y"), 0)
        self.assertTrue(DeviceToken.objects.filter(token="alive").exists())

    @mock.patch.dict(os.environ, _RS_ENV)
    @mock.patch("notifications.push._http")
    def test_notification_created_even_if_push_fails(self, http):
        from notifications.push import PushError

        http.side_effect = PushError("RuStore недоступен")
        self._token("alive")
        n = create_notification(self.uid, "Заказ принят", "тест")
        self.assertIsNotNone(n)  # лента важнее доставки на телефон


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


@override_settings(CELERY_TASK_ALWAYS_EAGER=True, CELERY_TASK_EAGER_PROPAGATES=True)
class PushTaskTests(ApiTestCase):
    """Пуш вынесен в Celery-задачу (D-07). EAGER-режим форсим — детерминированно и в
    dev (брокер есть), и в CI (брокера нет): задача выполняется синхронно inline."""

    phone = "+79990005003"

    def test_send_push_task_runs_inline_noop(self):
        from notifications.tasks import send_push_task

        DeviceToken.objects.create(user_id=self.uid, token="t", platform="android")
        # EAGER → .delay() выполняется синхронно; без PUSH_PROVIDER — 0 доставок.
        self.assertEqual(send_push_task.delay(self.uid, "Привет", "тест").get(), 0)

    def test_create_notification_dispatches_push_task(self):
        with mock.patch("notifications.tasks.send_push_task.delay") as delayed:
            n = create_notification(self.uid, "Заказ готов", "тест")
        self.assertIsNotNone(n)  # уведомление создано
        delayed.assert_called_once_with(self.uid, "Заказ готов", "тест")  # пуш ушёл в фон
