"""Регрессии начисления за покупку (S-04 Phase 2) + каркас оплаты."""
import os
from unittest import mock

from common.testutils import ApiTestCase
from orders.payment import payment_enabled


class PaymentScaffoldTests(ApiTestCase):
    phone = "+79990002003"

    def test_dev_pay_marks_paid(self):
        self.assertFalse(payment_enabled())
        self.api_post("/v1/orders", {"id": "SS-P1", "total": 500, "items": []})
        r = self.api_post("/v1/orders/SS-P1/pay", {})
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["status"], "paid")  # dev — оплата не требуется

    def test_pay_unknown_order_404(self):
        self.assertEqual(self.api_post("/v1/orders/NOPE/pay", {}).status_code, 404)

    @mock.patch.dict(os.environ, {"PAYMENT_PROVIDER": "yookassa"})
    def test_provider_mode_pending_without_key(self):
        self.assertTrue(payment_enabled())
        self.api_post("/v1/orders", {"id": "SS-P2", "total": 500, "items": []})
        r = self.api_post("/v1/orders/SS-P2/pay", {})
        self.assertEqual(r.json()["status"], "pending")  # нет YOOKASSA_SECRET_KEY


class OrderAwardTests(ApiTestCase):
    phone = "+79990002002"

    def test_first_order_awards_purchase_and_registration(self):
        self.api_post("/v1/orders", {"id": "SS-1", "total": 1000, "items": []})
        self.assertEqual(self.balance(), 150)  # 100 (1000/10) + 50 (первый заказ)

    def test_duplicate_order_no_double(self):
        self.api_post("/v1/orders", {"id": "SS-1", "total": 1000, "items": []})
        self.api_post("/v1/orders", {"id": "SS-1", "total": 1000, "items": []})
        self.assertEqual(self.balance(), 150)

    def test_second_order_no_registration_bonus(self):
        self.api_post("/v1/orders", {"id": "SS-1", "total": 1000, "items": []})  # 150
        self.api_post("/v1/orders", {"id": "SS-2", "total": 500, "items": []})   # +50
        self.assertEqual(self.balance(), 200)

    def test_client_cannot_mint_purchase_or_registration(self):
        for src in ("purchase", "registration"):
            r = self.api_post(
                "/v1/loyalty/transactions",
                {"amount": 9999, "source": src, "orderId": "x"},
            )
            self.assertEqual(r.status_code, 403)
        self.assertEqual(self.balance(), 0)
