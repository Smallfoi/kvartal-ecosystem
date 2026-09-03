"""Базовый TestCase для интеграционных тестов API (через реальные URL).
Каждый тест: логинимся по телефону (dev-код 1234), чистим демо-баллы, считаем баланс."""
import json

from django.core.cache import cache
from django.test import TestCase

from accounts.models import Account
from loyalty.models import LoyaltyTransaction


class ApiTestCase(TestCase):
    phone = "+79990002000"  # переопредели в подклассе, чтобы тесты не пересекались

    def setUp(self):
        # Счётчики rate-limit живут в кэше — чистим, чтобы тесты не штрафовали друг друга.
        cache.clear()
        r = self.client.post(
            "/v1/auth/phone/verify",
            data=json.dumps({"phone": self.phone, "code": "1234"}),
            content_type="application/json",
        )
        self.token = r.json()["token"]
        self.uid = Account.objects.get(phone=self.phone).id
        # Демо-баллы из seed_runner_points мешают считать дельты — убираем.
        LoyaltyTransaction.objects.filter(user_id=self.uid).delete()

    def api_post(self, path, body, token=None):
        return self.client.post(
            path,
            data=json.dumps(body),
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {token or self.token}",
        )

    def api_get(self, path, token=None):
        return self.client.get(
            path, HTTP_AUTHORIZATION=f"Bearer {token or self.token}"
        )

    def api_patch(self, path, body, token=None):
        return self.client.patch(
            path,
            data=json.dumps(body),
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {token or self.token}",
        )

    def new_user(self, phone):
        """Создать ещё одного пользователя (для тестов с двумя участниками)."""
        r = self.client.post(
            "/v1/auth/phone/verify",
            data=json.dumps({"phone": phone, "code": "1234"}),
            content_type="application/json",
        )
        return r.json()["token"]

    def balance(self):
        return sum(
            t.amount for t in LoyaltyTransaction.objects.filter(user_id=self.uid)
        )


def verify_admin(client, user):
    """Пройти второй фактор в тесте: привязать устройство и отметить сессию.

    Второй фактор обязателен для всех, у кого есть админка (D-68), поэтому
    одного `client.login()` для админ-страниц больше не хватает: без отметки
    об устройстве middleware уводит на привязку.
    """
    from django_otp import DEVICE_ID_SESSION_KEY
    from django_otp.plugins.otp_totp.models import TOTPDevice

    device = (TOTPDevice.objects.filter(user=user, confirmed=True).first()
              or TOTPDevice.objects.create(user=user, name="test", confirmed=True))
    session = client.session
    session[DEVICE_ID_SESSION_KEY] = device.persistent_id
    session.save()
    return device


def login_admin(client, username, password, user=None):
    """Полный вход в админку для теста: пароль плюс второй фактор."""
    from django.contrib.auth import get_user_model

    assert client.login(username=username, password=password), "пароль не подошёл"
    if user is None:
        User = get_user_model()
        user = User.objects.get(**{User.USERNAME_FIELD: username})
    verify_admin(client, user)
    return user
