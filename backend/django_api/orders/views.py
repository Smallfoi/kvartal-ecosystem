"""Заказы Store (D-13). POST — сохранить заказ пользователя (идемпотентно по id),
GET — список заказов пользователя (новые сверху). Требуется Bearer-токен."""
from rest_framework.decorators import api_view
from rest_framework.response import Response

from common.security import user_id_from_request

from .models import Order


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
    rows = Order.objects.filter(user_id=uid)
    return Response([o.to_json() for o in rows])
