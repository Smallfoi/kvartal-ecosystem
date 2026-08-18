"""Заказы Store (D-13). POST — сохранить заказ пользователя (идемпотентно по id),
GET — список заказов пользователя (новые сверху). Требуется Bearer-токен."""
from rest_framework.decorators import api_view
from rest_framework.response import Response

from common.security import user_id_from_request

from .awards import accrue_purchase_points, refund_redeemed_points
from .models import Order
from .pricing import total_is_acceptable
from .payment import PaymentError, create_payment, fetch_payment, payment_enabled


@api_view(["POST"])
def pay_order(request, order_id):
    """Инициировать оплату заказа (D-13). Dev (без провайдера) — сразу «оплачено»;
    с ЮKassa — вернуть confirmationUrl для редиректа покупателя на страницу оплаты."""
    uid = user_id_from_request(request)
    if not uid:
        return Response({"detail": "Нет токена"}, status=401)
    order = Order.objects.filter(user_id=uid, order_id=order_id).first()
    if not order:
        return Response({"detail": "Заказ не найден"}, status=404)
    try:
        result = create_payment(
            order_id, order.total, request.data.get("returnUrl") or ""
        )
    except PaymentError as e:
        # Провайдер отказал/недоступен — НЕ трогаем статус заказа. Отдать «оплачено»
        # или молча «pending» с пустой ссылкой значит потерять покупателя и деньги.
        return Response({"detail": f"Оплата недоступна: {e}"}, status=502)
    order.payment_status = result["status"]
    order.payment_id = result.get("paymentId") or ""
    order.save(update_fields=["payment_status", "payment_id"])
    if result["status"] == "paid":
        order.refresh_from_db()
        _mark_paid(order)
    return Response(result)


def _mark_paid(order) -> None:
    """Заказ оплачен: зафиксировать статус и начислить баллы (идемпотентно)."""
    fields = []
    if order.payment_status != "paid":
        order.payment_status = "paid"
        fields.append("payment_status")
    if order.status == "pending":
        order.status = "paid"
        fields.append("status")
    if fields:
        order.save(update_fields=fields)
    accrue_purchase_points(order)


@api_view(["POST"])
def payment_webhook(request):
    """Уведомление ЮKassa об изменении статуса платежа.

    Эндпоинт публичный (адрес прописывается в личном кабинете ЮKassa), а тело
    уведомления НЕ подписано — поэтому телу не верим: берём из него только id
    платежа и перезапрашиваем настоящий статус по API своими ключами. Подделать
    уведомление и «оплатить» заказ бесплатно так нельзя.
    """
    obj = (request.data or {}).get("object") or {}
    payment_id = str(obj.get("id") or "").strip()
    if not payment_id:
        return Response({"detail": "Нет id платежа"}, status=400)

    try:
        info = fetch_payment(payment_id)
    except PaymentError as e:
        # Не подтвердили статус — отвечаем ошибкой, ЮKassa повторит доставку позже.
        return Response({"detail": str(e)}, status=502)

    order = Order.objects.filter(payment_id=payment_id).first()
    if not order:
        # Незнакомый платёж: возможна гонка с сохранением payment_id — пусть повторит.
        return Response({"detail": "Заказ по платежу не найден"}, status=404)

    if info["status"] == "paid":
        _mark_paid(order)
    elif info["status"] == "canceled":
        if order.payment_status != "canceled":
            order.payment_status = "canceled"
            order.save(update_fields=["payment_status"])
        refund_redeemed_points(order)
    return Response({"ok": True, "status": order.payment_status})


@api_view(["GET", "POST"])
def orders(request):
    uid = user_id_from_request(request)
    if not uid:
        return Response({"detail": "Нет токена"}, status=401)

    if request.method == "POST":
        d = request.data
        oid = str(d.get("id") or "").strip()
        if not oid:
            return Response({"detail": "Нет id заказа"}, status=400)
        total = float(d.get("total") or 0)
        # Сумму присылает клиент — сверяем её с ценами каталога (D-37). Иначе корзину
        # на 50 000 ₽ можно оформить с total: 1, заплатить рубль и получить товар.
        if not total_is_acceptable(total, d.get("items"), uid, oid):
            return Response(
                {"detail": "Сумма заказа не совпадает с ценами каталога"}, status=400
            )
        # Оплаченный заказ переоформить нельзя — иначе сумму меняют задним числом.
        already = Order.objects.filter(user_id=uid, order_id=oid).first()
        if already and already.payment_status == "paid" and float(already.total) != total:
            return Response({"detail": "Заказ уже оплачен"}, status=409)
        obj, created = Order.objects.update_or_create(
            user_id=uid,
            order_id=oid,
            defaults={
                "total": total,
                "status": (d.get("status") or "pending"),
                "points_redeemed": int(d.get("pointsRedeemed") or 0),
                "payload": d,
            },
        )
        # Начисление за покупку считает СЕРВЕР (анти-чит S-04 Phase 2), не клиент.
        # Когда оплата ВЫКЛЮЧЕНА (dev/CI) — заказ и есть покупка, начисляем сразу.
        # Когда оплата ВКЛЮЧЕНА — ждём подтверждения от ЮKassa (см. payment_webhook),
        # иначе баллы капали бы за неоплаченный заказ.
        if created and not payment_enabled():
            accrue_purchase_points(obj)
        # Связка экосистемы: для каждой пары обуви в заказе заводим ресурс
        # «износа кроссовок» (Квартал затем убавляет километраж). Идемпотентно.
        from shoes.views import create_for_order

        create_for_order(uid, oid, d.get("items") or [])
        if created:
            # Аналитика (D-30): покупка (только на создании — повтор POST не задваивает).
            from analytics.models import E_PURCHASE, track

            track(E_PURCHASE, user_id=uid, source="store", total=total, orderId=oid)
        return Response(obj.to_json())

    # GET — заказы текущего пользователя
    rows = Order.objects.filter(user_id=uid).order_by("-created_at")[
        :200
    ]  # последние заказы (детерминированный срез, ограничение payload)
    return Response([o.to_json() for o in rows])
