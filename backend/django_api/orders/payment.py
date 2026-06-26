"""Оплата заказов — провайдер-агностичный каркас под env-ключ.

ВАЖНО: конкретный провайдер (ЮKassa / CloudPayments / Тинькофф) — решение владельца,
поэтому здесь generic-абстракция: create_payment → confirmationUrl (редирект) + статус.
Без PAYMENT_PROVIDER — dev-режим: оплата не требуется, заказ считается оплаченным
(текущее поведение). С провайдером — возвращаем ссылку на оплату; подтверждение
прилетает вебхуком (реальный вызов API провайдера добавить при наличии аккаунта).
"""
import os


def payment_enabled() -> bool:
    return bool(os.environ.get("PAYMENT_PROVIDER"))


def create_payment(order_id, amount, return_url="") -> dict:
    """Создать платёж. Возвращает {status, paymentId, confirmationUrl}.
    Dev (без провайдера) — status='paid' (оплата не требуется)."""
    if not payment_enabled():
        return {"status": "paid", "paymentId": "", "confirmationUrl": ""}
    return _provider().create(order_id, amount, return_url)


def _provider():
    if os.environ.get("PAYMENT_PROVIDER", "").lower() == "yookassa":
        return _YooKassaProvider()
    return _NoopProvider()


class _NoopProvider:
    def create(self, order_id, amount, return_url) -> dict:
        return {"status": "pending", "paymentId": "", "confirmationUrl": ""}


class _YooKassaProvider:
    """ЮKassa (пример). Активна при PAYMENT_PROVIDER=yookassa + YOOKASSA_SHOP_ID/
    YOOKASSA_SECRET_KEY. Каркас: реальный вызов API ЮKassa добавить при наличии аккаунта."""

    def create(self, order_id, amount, return_url) -> dict:
        if not os.environ.get("YOOKASSA_SECRET_KEY"):
            return {"status": "pending", "paymentId": "", "confirmationUrl": ""}
        # TODO(owner-gated): создать платёж через API ЮKassa, вернуть confirmation.url.
        return {"status": "pending", "paymentId": "", "confirmationUrl": ""}
