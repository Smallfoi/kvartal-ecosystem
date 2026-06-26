"""Заказы Store (D-13). POST — сохранить заказ пользователя (идемпотентно по id),
GET — список заказов пользователя (новые сверху). Требуется Bearer-токен."""
from rest_framework.decorators import api_view
from rest_framework.response import Response

from common.security import user_id_from_request

from .models import Order
from .payment import create_payment


@api_view(["POST"])
def pay_order(request, order_id):
    """Инициировать оплату заказа (каркас, D-13). Dev (без провайдера) — сразу
    «оплачено»; с провайдером — вернуть confirmationUrl для редиректа."""
    uid = user_id_from_request(request)
    if not uid:
        return Response({"detail": "Нет токена"}, status=401)
    order = Order.objects.filter(user_id=uid, order_id=order_id).first()
    if not order:
        return Response({"detail": "Заказ не найден"}, status=404)
    result = create_payment(order_id, order.total, request.data.get("returnUrl") or "")
    order.payment_status = result["status"]
    order.payment_id = result.get("paymentId") or ""
    order.save(update_fields=["payment_status", "payment_id"])
    return Response(result)


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
        # Начисление за покупку считает СЕРВЕР (анти-чит S-04 Phase 2), не клиент:
        # +1 балл за каждые 10 ₽ фактической суммы + 50 за первый заказ. Только при
        # создании (created) → повторный POST того же id не задваивает баллы.
        if created:
            from loyalty.models import add_txn

            base = int(total // 10)
            if base > 0:
                add_txn(uid, base, "purchase", f"Покупка на {int(total)} ₽", oid)
            if Order.objects.filter(user_id=uid).count() == 1:  # это первый заказ юзера
                add_txn(uid, 50, "registration", "Бонус за первый заказ", oid)
        # Связка экосистемы: для каждой пары обуви в заказе заводим ресурс
        # «износа кроссовок» (Квартал затем убавляет километраж). Идемпотентно.
        from shoes.views import create_for_order

        create_for_order(uid, oid, d.get("items") or [])
        return Response(obj.to_json())

    # GET — заказы текущего пользователя
    rows = Order.objects.filter(user_id=uid).order_by("-created_at")[
        :200
    ]  # последние заказы (детерминированный срез, ограничение payload)
    return Response([o.to_json() for o in rows])
