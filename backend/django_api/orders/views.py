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
        obj, _ = Order.objects.update_or_create(
            user_id=uid,
            order_id=oid,
            defaults={
                "total": float(d.get("total") or 0),
                "status": (d.get("status") or "pending"),
                "points_redeemed": int(d.get("pointsRedeemed") or 0),
                "payload": d,
            },
        )
        # Связка экосистемы: для каждой пары обуви в заказе заводим ресурс
        # «износа кроссовок» (Квартал затем убавляет километраж). Идемпотентно.
        from shoes.views import create_for_order

        create_for_order(uid, oid, d.get("items") or [])
        return Response(obj.to_json())

    # GET — заказы текущего пользователя
    rows = Order.objects.filter(user_id=uid)
    return Response([o.to_json() for o in rows])
