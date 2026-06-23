"""Регрессии траты баллов: redeem авторитетен на сервере (нельзя в минус, идемпотентен)."""
from common.testutils import ApiTestCase
from loyalty.models import add_txn


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
