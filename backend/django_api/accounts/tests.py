"""Регрессии входа/профиля: rate-limit (анти-брутфорс) + базовые потоки auth + SMS-OTP."""
import json
import os
from unittest import mock

from django.core.cache import cache
from django.test import SimpleTestCase, TestCase

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
