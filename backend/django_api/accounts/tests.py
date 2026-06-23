"""Регрессии входа/профиля: rate-limit (анти-брутфорс) + базовые потоки auth."""
import json

from django.core.cache import cache
from django.test import TestCase

from common.testutils import ApiTestCase


class AuthFlowTests(ApiTestCase):
    phone = "+79990004001"

    def test_me_returns_profile(self):
        r = self.api_get("/v1/auth/me")
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["id"], self.uid)

    def test_me_without_token_401(self):
        r = self.client.get("/v1/auth/me")
        self.assertEqual(r.status_code, 401)

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
