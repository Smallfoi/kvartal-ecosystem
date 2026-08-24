"""Баллы за заказ: начисление и возврат — идемпотентно по заказу.

Раньше начисление жило прямо в создании заказа. Пока оплаты не было, это совпадало:
заказ = покупка. С реальной ЮKassa так нельзя — иначе баллы (а баллы = деньги)
капают за неоплаченный заказ. Поэтому логика вынесена сюда и вызывается:

- при создании заказа — если провайдер оплаты ВЫКЛЮЧЕН (dev/CI: оплата не требуется);
- при подтверждении оплаты вебхуком — если провайдер ВКЛЮЧЁН.

Каждая функция проверяет, не начисляла ли уже по этому заказу: вебхук ЮKassa может
прийти несколько раз (при 5xx она повторяет доставку), и повтор не должен задваивать.
"""
from loyalty.models import LoyaltyTransaction, add_txn

_PURCHASE_RATE = 10   # ₽ на 1 балл
_FIRST_ORDER_BONUS = 50


def _has_txn(user_id, order_id, source) -> bool:
    return LoyaltyTransaction.objects.filter(
        user_id=user_id, order_id=order_id, source=source
    ).exists()


def accrue_purchase_points(order) -> None:
    """+1 балл за каждые 10 ₽ суммы заказа и +50 за первый заказ пользователя."""
    uid, oid = order.user_id, order.order_id
    total = float(order.total or 0)

    if not _has_txn(uid, oid, "purchase"):
        base = int(total // _PURCHASE_RATE)
        if base > 0:
            add_txn(uid, base, "purchase", f"Покупка на {int(total)} ₽", oid)

    # «Первый заказ» определяем по отсутствию бонуса у пользователя, а не по числу
    # заказов: при оплате вперёд платит не обязательно самый первый оформленный.
    if not LoyaltyTransaction.objects.filter(user_id=uid, source="registration").exists():
        add_txn(uid, _FIRST_ORDER_BONUS, "registration", "Бонус за первый заказ", oid)


def revoke_purchase_points(order) -> None:
    """Снять баллы, начисленные за покупку, если деньги вернули покупателю.

    Иначе возврат превращается в дырку: товар и деньги у покупателя, а баллы
    (то есть скидка на следующую покупку) остались начисленными. Бонус за первый
    заказ не трогаем — он за факт знакомства с магазином, а не за конкретный товар.
    """
    uid, oid = order.user_id, order.order_id
    if _has_txn(uid, oid, "purchase_revoke"):
        return
    earned = LoyaltyTransaction.objects.filter(
        user_id=uid, order_id=oid, source="purchase"
    ).first()
    if not earned or earned.amount <= 0:
        return
    add_txn(uid, -earned.amount, "purchase_revoke", "Отмена начисления: возврат заказа", oid)


def refund_redeemed_points(order) -> None:
    """Вернуть баллы, списанные при оформлении, если оплата не состоялась.

    Покупатель списал баллы на чекауте, а платёж отменился — баллы обязаны
    вернуться, иначе они сгорают ни за что.
    """
    uid, oid = order.user_id, order.order_id
    spent = LoyaltyTransaction.objects.filter(
        user_id=uid, order_id=oid, source="redeem"
    ).first()
    if not spent or _has_txn(uid, oid, "redeem_refund"):
        return
    add_txn(
        uid, -spent.amount, "redeem_refund", "Возврат баллов: оплата не прошла", oid
    )
