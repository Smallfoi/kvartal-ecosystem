"""Регрессии входа/профиля: rate-limit (анти-брутфорс) + базовые потоки auth + SMS-OTP."""
import json
import os
import tempfile
from unittest import mock

from django.core.cache import cache
from django.test import SimpleTestCase, TestCase, override_settings

from common.testutils import ApiTestCase


class SmsOtpTests(SimpleTestCase):
    """Каркас SMS-OTP: dev принимает 1234; с провайдером — реальный одноразовый код."""

    def setUp(self):
        cache.clear()

    def test_dev_mode_accepts_1234(self):
        from accounts.sms import check_code, sms_enabled
        self.assertFalse(sms_enabled())
        self.assertTrue(check_code("+79990001111", "1234"))
        self.assertFalse(check_code("+79990001111", "0000"))

    @mock.patch.dict(os.environ, {"SMS_PROVIDER": "smsc"})
    def test_real_mode_checks_sent_code(self):
        from accounts.sms import check_code, request_code, sms_enabled
        self.assertTrue(sms_enabled())
        self.assertFalse(check_code("+79990001112", "1234"))  # дев-код больше не годится
        request_code("+79990001112")  # SMS_LOGIN не задан → реально не шлёт, но код в кэше
        rec = cache.get("otp:+79990001112")
        self.assertTrue(check_code("+79990001112", rec["code"]))
        self.assertFalse(check_code("+79990001112", rec["code"]))  # одноразовый

    @mock.patch.dict(os.environ, {"SMS_PROVIDER": "smsc"})
    def test_attempt_limit_blocks_even_correct_code(self):
        from accounts.sms import check_code, request_code
        request_code("+79990001113")
        rec = cache.get("otp:+79990001113")
        for _ in range(5):
            check_code("+79990001113", "000000")  # 5 неверных
        self.assertFalse(check_code("+79990001113", rec["code"]))  # лимит исчерпан


class AuthFlowTests(ApiTestCase):
    phone = "+79990004001"

    def test_me_returns_profile(self):
        r = self.api_get("/v1/auth/me")
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["id"], self.uid)

    def test_me_without_token_401(self):
        r = self.client.get("/v1/auth/me")
        self.assertEqual(r.status_code, 401)

    @override_settings(MEDIA_ROOT=tempfile.mkdtemp())
    def test_avatar_upload_sets_path_and_me_returns_it(self):
        from io import BytesIO

        from django.core.files.uploadedfile import SimpleUploadedFile
        from PIL import Image

        buf = BytesIO()
        Image.new("RGB", (64, 64), (80, 40, 200)).save(buf, "PNG")
        img = SimpleUploadedFile("av.png", buf.getvalue(), content_type="image/png")
        r = self.client.post(
            "/v1/profile/avatar",
            {"image": img},
            HTTP_AUTHORIZATION=f"Bearer {self.token}",
        )
        self.assertEqual(r.status_code, 200)
        path = r.json()["avatarPath"]
        self.assertTrue(path and path.startswith("/media/"))
        # /auth/me отдаёт тот же аватар (единый для экосистемы)
        self.assertEqual(self.api_get("/v1/auth/me").json()["avatarPath"], path)
        # DELETE снимает аватар
        d = self.client.delete(
            "/v1/profile/avatar", HTTP_AUTHORIZATION=f"Bearer {self.token}"
        )
        self.assertIsNone(d.json()["avatarPath"])

    def test_avatar_requires_image_file(self):
        r = self.client.post(
            "/v1/profile/avatar", {}, HTTP_AUTHORIZATION=f"Bearer {self.token}"
        )
        self.assertEqual(r.status_code, 400)

    def test_update_profile_changes_name(self):
        r = self.api_patch("/v1/profile", {"name": "Новое Имя"})
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["name"], "Новое Имя")
        self.assertEqual(self.api_get("/v1/auth/me").json()["name"], "Новое Имя")

    def test_register_then_login(self):
        body = {"email": "reg@test.dev", "password": "p@ss12345", "name": "Рег"}
        r = self.client.post("/v1/auth/register", data=json.dumps(body),
                             content_type="application/json")
        self.assertEqual(r.status_code, 200)
        self.assertTrue(r.json()["token"])
        ok = self.client.post("/v1/auth/login",
                              data=json.dumps({"email": "reg@test.dev",
                                               "password": "p@ss12345"}),
                              content_type="application/json")
        self.assertEqual(ok.status_code, 200)
        bad = self.client.post("/v1/auth/login",
                               data=json.dumps({"email": "reg@test.dev",
                                                "password": "wrong"}),
                               content_type="application/json")
        self.assertEqual(bad.status_code, 401)

    def test_blocked_account_cannot_login(self):
        from accounts.models import Account
        Account.objects.filter(id=self.uid).update(is_blocked=True)
        r = self.client.post("/v1/auth/phone/verify",
                             data=json.dumps({"phone": self.phone, "code": "1234"}),
                             content_type="application/json")
        self.assertEqual(r.status_code, 403)

    def test_blocked_account_existing_token_rejected(self):
        # Мгновенный бан: уже выданный токен перестаёт работать (не ждём 30 дней).
        from django.core.cache import cache
        from accounts.models import Account
        self.assertEqual(self.api_get("/v1/auth/me").status_code, 200)  # пока ок
        Account.objects.filter(id=self.uid).update(is_blocked=True)
        cache.clear()  # сбрасываем кэш blocked-статуса (в проде — ≤60с TTL)
        self.assertEqual(self.api_get("/v1/auth/me").status_code, 401)


class AuthThrottleTests(TestCase):
    def setUp(self):
        cache.clear()  # сбрасываем счётчики лимита перед тестом

    def test_phone_verify_is_rate_limited(self):
        # Лимит auth = 20/min по IP. 30 попыток подряд → часть упрётся в 429.
        codes = []
        for _ in range(30):
            r = self.client.post(
                "/v1/auth/phone/verify",
                data=json.dumps({"phone": "+79990003000", "code": "0000"}),
                content_type="application/json",
            )
            codes.append(r.status_code)
        self.assertIn(429, codes, "Брутфорс /auth должен упираться в rate-limit (429)")

    def test_wrong_code_rejected(self):
        r = self.client.post(
            "/v1/auth/phone/verify",
            data=json.dumps({"phone": "+79990003001", "code": "0000"}),
            content_type="application/json",
        )
        self.assertEqual(r.status_code, 401)


class MeStatsTests(ApiTestCase):
    """Личная аналитика: агрегаты забегов/баллов/заказов из общего бэка."""

    phone = "+79990006001"

    def test_me_stats_aggregates(self):
        import time

        from orders.models import Order

        # Забег 5 км → +50 баллов (сервер считает).
        self.api_post("/v1/runs", {
            "id": "rs1", "distanceMeters": 5000, "elapsedSeconds": 1800,
            "finishedAtMs": int(time.time() * 1000),
        })
        Order.objects.create(
            user_id=self.uid, order_id="SS-9", total=5000,
            payload={"id": "SS-9", "items": []},
        )
        d = self.api_get("/v1/me/stats").json()
        self.assertEqual(d["runs"]["count"], 1)
        self.assertEqual(d["runs"]["totalKm"], 5.0)
        self.assertEqual(d["loyalty"]["balance"], 50)
        self.assertGreaterEqual(d["loyalty"]["earned"], 50)
        self.assertEqual(d["orders"]["count"], 1)
        self.assertEqual(d["orders"]["totalSpent"], 5000)

    def test_stats_cached_and_invalidated_on_txn(self):
        # Первый запрос — считает и кэширует (баланс 0).
        self.assertEqual(self.api_get("/v1/me/stats").json()["loyalty"]["balance"], 0)
        from loyalty.models import add_txn

        add_txn(self.uid, 100, "runnerRun")  # новая транзакция сбрасывает кэш статистики
        self.assertEqual(self.api_get("/v1/me/stats").json()["loyalty"]["balance"], 100)

    def test_me_stats_requires_auth(self):
        self.assertEqual(self.client.get("/v1/me/stats").status_code, 401)


class ProfileEditTests(ApiTestCase):
    """Централизованный профиль (аватар/email/структурный адрес — единые в экосистеме):
    валидация и round-trip email/имени/адресов + настройки приватности."""

    phone = "+79990004010"

    def test_empty_name_rejected(self):
        r = self.api_patch("/v1/profile", {"name": "   "})
        self.assertEqual(r.status_code, 400)

    def test_invalid_email_rejected(self):
        r = self.api_patch("/v1/profile", {"email": "не-почта"})
        self.assertEqual(r.status_code, 400)

    def test_email_stored_lowercased(self):
        r = self.api_patch("/v1/profile", {"email": "User@Test.DEV"})
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["email"], "user@test.dev")

    def test_addresses_roundtrip(self):
        # Структурный адрес (город/улица/дом/корпус/кв) — как в форме сайта/приложений.
        addr = [{"city": "Якутск", "street": "Ленина", "house": "1", "flat": "5"}]
        r = self.api_patch("/v1/profile", {"addresses": addr})
        self.assertEqual(r.json()["addresses"], addr)
        self.assertEqual(self.api_get("/v1/auth/me").json()["addresses"], addr)

    def test_addresses_non_list_coerced_to_empty(self):
        r = self.api_patch("/v1/profile", {"addresses": "мусор"})
        self.assertEqual(r.json()["addresses"], [])  # не список → пустой, не падаем

    def test_duplicate_email_conflict(self):
        from accounts.models import Account

        Account.objects.create(id="u_other_email", email="taken@test.dev")
        r = self.api_patch("/v1/profile", {"email": "taken@test.dev"})
        self.assertEqual(r.status_code, 409)  # email уже у другого аккаунта

    def test_profile_requires_auth(self):
        self.assertEqual(self.client.patch("/v1/profile").status_code, 401)

    def test_privacy_defaults_private_then_patch(self):
        priv = self.api_get("/v1/account/privacy").json()
        self.assertEqual(
            priv,
            {"profilePublic": False, "routePublic": False, "realtimePublic": False},
        )  # privacy by design — всё закрыто по умолчанию
        upd = self.api_patch("/v1/account/privacy", {"profilePublic": True}).json()
        self.assertTrue(upd["profilePublic"])
        self.assertFalse(upd["routePublic"])  # частичный PATCH не трогает остальное

    def test_privacy_requires_auth(self):
        self.assertEqual(self.client.get("/v1/account/privacy").status_code, 401)


class AccountDeletionTests(ApiTestCase):
    """Удаление аккаунта (152-ФЗ, LR §13): нужен confirm:true, чистит персональные данные."""

    phone = "+79990004011"

    def test_delete_requires_confirm(self):
        r = self.api_post("/v1/account/delete", {})
        self.assertEqual(r.status_code, 400)
        self.assertEqual(self.api_get("/v1/auth/me").status_code, 200)  # аккаунт жив

    def test_delete_purges_personal_data(self):
        from accounts.models import Account
        from loyalty.models import LoyaltyTransaction
        from orders.models import Order

        self.api_post("/v1/orders", {"id": "o1", "total": 500, "items": []})  # заказ + баллы
        self.assertTrue(LoyaltyTransaction.objects.filter(user_id=self.uid).exists())
        r = self.api_post("/v1/account/delete", {"confirm": True})
        self.assertEqual(r.status_code, 200)
        self.assertFalse(Account.objects.filter(id=self.uid).exists())
        self.assertFalse(LoyaltyTransaction.objects.filter(user_id=self.uid).exists())
        self.assertFalse(Order.objects.filter(user_id=self.uid).exists())

    def test_delete_requires_auth(self):
        self.assertEqual(self.client.post("/v1/account/delete").status_code, 401)


class AccountExportTests(ApiTestCase):
    """Выгрузка персональных данных (152-ФЗ §2 «портируемость»): всё своё — файлом."""

    phone = "+79990004012"

    def test_export_requires_auth(self):
        self.assertEqual(self.client.get("/v1/account/export").status_code, 401)

    def test_export_contains_personal_data(self):
        self.api_post("/v1/orders", {"id": "o1", "total": 500, "items": []})  # заказ + баллы
        r = self.api_get("/v1/account/export")
        self.assertEqual(r.status_code, 200)
        self.assertIn("attachment", r["Content-Disposition"])  # отдаётся файлом
        d = r.json()
        self.assertEqual(d["userId"], self.uid)
        self.assertEqual(d["profile"]["id"], self.uid)
        self.assertTrue(d["loyalty"]["transactions"])  # начисления за заказ попали
        self.assertTrue(any(o.get("id") == "o1" for o in d["orders"]))
        self.assertIn("exportedAt", d)
        # структура покрывает удаляемые данные (зеркало delete_account)
        for key in ("runs", "shoes", "notifications", "consents", "analyticsEvents"):
            self.assertIn(key, d)

    def test_export_isolated_per_user(self):
        from loyalty.models import add_txn

        add_txn("u_other_export", 100, "runnerRun")  # чужие баллы
        d = self.api_get("/v1/account/export").json()
        self.assertEqual(d["loyalty"]["transactions"], [])  # чужое не попадает


class BroadcastAdminTests(TestCase):
    """Массовая рассылка через админ-действие send_notification (AccountAdmin):
    промежуточная форма → уведомление каждому выбранному пользователю."""

    _SEL = "_selected_action"  # django.contrib.admin.helpers.ACTION_CHECKBOX_NAME

    def setUp(self):
        from django.contrib.auth.models import User

        User.objects.create_superuser("boss", "boss@x.dev", "pass-12345")
        self.assertTrue(self.client.login(username="boss", password="pass-12345"))

    def test_form_shown_without_apply(self):
        from accounts.models import Account

        Account.objects.create(id="ua", email="a@t.local")
        r = self.client.post("/admin/accounts/account/", {
            "action": "send_notification", self._SEL: ["ua"],
        })
        self.assertEqual(r.status_code, 200)
        self.assertContains(r, 'name="title"')  # показана промежуточная форма

    def test_broadcast_creates_notifications(self):
        from accounts.models import Account
        from notifications.models import Notification

        Account.objects.create(id="ua", email="a@t.local")
        Account.objects.create(id="ub", email="b@t.local")
        self.client.post("/admin/accounts/account/", {
            "action": "send_notification", self._SEL: ["ua", "ub"],
            "apply": "1", "title": "Обновление", "body": "Новая функция",
        }, follow=True)
        self.assertEqual(Notification.objects.filter(title="Обновление").count(), 2)
        self.assertEqual(
            Notification.objects.get(user_id="ua", title="Обновление").body, "Новая функция"
        )

    def test_empty_title_sends_nothing(self):
        from accounts.models import Account
        from notifications.models import Notification

        Account.objects.create(id="ua", email="a@t.local")
        self.client.post("/admin/accounts/account/", {
            "action": "send_notification", self._SEL: ["ua"],
            "apply": "1", "title": "   ", "body": "x",
        }, follow=True)
        self.assertEqual(Notification.objects.count(), 0)  # пустой заголовок → ничего


class PhoneIdentityTests(ApiTestCase):
    """Телефон — идентификатор входа, менять его без подтверждения нельзя (D-37)."""
    phone = "+79990009001"

    def test_cannot_claim_someone_elses_phone(self):
        """Классический перехват: присвоить своему аккаунту чужой номер, чтобы вход
        владельца по SMS привёл в аккаунт атакующего."""
        from accounts.models import Account

        victim_phone = "+79990009002"
        self.new_user(victim_phone)

        r = self.api_patch("/v1/profile", {"phone": victim_phone})
        self.assertEqual(r.status_code, 200)  # запрос не падает, но номер не меняется
        self.assertEqual(Account.objects.get(id=self.uid).phone, self.phone)
        self.assertEqual(Account.objects.filter(phone=victim_phone).count(), 1)

    def test_first_fill_of_empty_phone_allowed(self):
        """Первичное заполнение пустого поля — законный сценарий (вход по email)."""
        from accounts.models import Account
        from common.security import make_token

        acc = Account.objects.create(id="u_nophone", email="nophone@test.local", phone=None)
        r = self.api_patch("/v1/profile", {"phone": "+79990009003"}, token=make_token(acc.id))
        self.assertEqual(r.status_code, 200)
        self.assertEqual(Account.objects.get(id=acc.id).phone, "+79990009003")

    def test_first_fill_rejects_number_already_taken(self):
        from accounts.models import Account
        from common.security import make_token

        acc = Account.objects.create(id="u_nophone2", email="nophone2@test.local", phone=None)
        r = self.api_patch("/v1/profile", {"phone": self.phone}, token=make_token(acc.id))
        self.assertEqual(r.status_code, 409)


# MEDIA_ROOT по умолчанию /srv/media (том в докере) — на раннере CI он недоступен.
@override_settings(MEDIA_ROOT=tempfile.mkdtemp())
class UploadValidationTests(ApiTestCase):
    """Тип файла — по содержимому, а не по имени и Content-Type (D-37)."""
    phone = "+79990009004"

    # Сигнатура PNG без экранирования, чтобы исходник теста оставался чистым текстом.
    PNG_HEAD = bytes.fromhex("89504e470d0a1a0a")

    def _upload(self, name, data, content_type):
        from django.core.files.uploadedfile import SimpleUploadedFile

        return self.client.post(
            "/v1/profile/avatar",
            {"image": SimpleUploadedFile(name, data, content_type=content_type)},
            HTTP_AUTHORIZATION=f"Bearer {self.token}",
        )

    def test_html_disguised_as_png_rejected(self):
        """Иначе файл лёг бы в media как .html и отдавался бы как страница — хранимый XSS."""
        evil = "<html><script>alert(1)</script></html>".encode()
        self.assertEqual(self._upload("evil.png", evil, "image/png").status_code, 400)

    def test_real_png_accepted_regardless_of_name_and_type(self):
        r = self._upload("whatever.txt", self.PNG_HEAD + bytes(64), "text/plain")
        self.assertEqual(r.status_code, 200)
        self.assertTrue(r.json()["avatarPath"].endswith(".png"))

    def test_oversized_rejected(self):
        big = self.PNG_HEAD + bytes(6 * 1024 * 1024)
        self.assertEqual(self._upload("big.png", big, "image/png").status_code, 400)
