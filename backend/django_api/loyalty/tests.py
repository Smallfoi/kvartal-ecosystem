"""Регрессии траты баллов + гейт демо-баллов."""
import os
from unittest import mock

from django.test import TestCase

from common.testutils import ApiTestCase
from loyalty.models import LoyaltyTransaction, add_txn, seed_runner_points
from notifications.models import Notification


class LevelUpNotificationTests(TestCase):
    """Уведомление при росте уровня лояльности (бег/территории/покупки → add_txn)."""

    def _levels(self, uid):
        return Notification.objects.filter(user_id=uid, type="level")

    def test_crossing_threshold_notifies_once(self):
        uid = "u_lvl_a"
        add_txn(uid, 150, "runnerRun", "пробежка")  # basic — без уведомления
        self.assertEqual(self._levels(uid).count(), 0)
        add_txn(uid, 100, "runnerRun", "пробежка")  # 250 → silver
        self.assertEqual(self._levels(uid).count(), 1)
        self.assertIn("Серебро", self._levels(uid).first().title)

    def test_no_duplicate_within_same_level(self):
        uid = "u_lvl_b"
        add_txn(uid, 250, "runnerRun")  # → silver (1)
        add_txn(uid, 50, "runnerRun")  # 300, всё ещё silver
        self.assertEqual(self._levels(uid).count(), 1)

    def test_redeem_does_not_notify(self):
        uid = "u_lvl_c"
        add_txn(uid, 600, "manual")  # → gold (1)
        add_txn(uid, -500, "redeem")  # списание (amount<0) — без уведомления
        self.assertEqual(self._levels(uid).count(), 1)
        self.assertIn("Золото", self._levels(uid).first().title)


class SeedGateTests(TestCase):
    def test_seed_off_by_default(self):
        # Без SEED_DEMO_POINTS новый аккаунт получает 0 баллов (реальные данные).
        seed_runner_points("u_seed_a")
        self.assertEqual(
            LoyaltyTransaction.objects.filter(user_id="u_seed_a").count(), 0
        )

    @mock.patch.dict(os.environ, {"SEED_DEMO_POINTS": "1"})
    def test_seed_on_when_flag_set(self):
        seed_runner_points("u_seed_b")
        self.assertEqual(
            LoyaltyTransaction.objects.filter(user_id="u_seed_b").count(), 5
        )


class RedeemTests(ApiTestCase):
    phone = "+79990002004"

    def _seed(self, amount):
        # Начисляем напрямую (модельная функция, минуя эндпоинт-блокировку).
        add_txn(self.uid, amount, "manual", "тестовый баланс")

    def test_cannot_redeem_more_than_balance(self):
        self._seed(100)
        r = self.api_post("/v1/loyalty/redeem", {"amount": 99999, "orderId": "o1"})
        self.assertEqual(r.status_code, 400)
        self.assertEqual(self.balance(), 100)  # не списалось

    def test_redeem_idempotent_by_order(self):
        self._seed(100)
        self.api_post("/v1/loyalty/redeem", {"amount": 30, "orderId": "o1"})
        r = self.api_post("/v1/loyalty/redeem", {"amount": 30, "orderId": "o1"}).json()
        self.assertTrue(r["deduped"])
        self.assertEqual(self.balance(), 70)  # списано один раз
