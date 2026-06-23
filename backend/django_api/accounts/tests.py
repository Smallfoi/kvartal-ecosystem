"""Регрессии безопасности входа: rate-limit на /auth (анти-брутфорс кода/пароля)."""
import json

from django.core.cache import cache
from django.test import TestCase


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
