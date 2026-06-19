"""Shoes API (ECOSYSTEM_API §2.5/§4.3) — трекер износа кроссовок.
GET  /v1/shoes                  → список кроссовок пользователя
POST /v1/shoes/<shoe_id>/distance {km} → добавить км после пробежки (Квартал)
Создание ресурса — серверное: при оформлении заказа с обувью (см. create_for_order,
вызывается из orders.views). Требуется Bearer-токен."""
from rest_framework.decorators import api_view
from rest_framework.response import Response

from common.security import user_id_from_request

from .models import ShoeAsset


def _pk_from_shoe_id(shoe_id: str):
    """Принимает 'shoe_5' или '5' → int pk (или None)."""
    s = str(shoe_id or "").strip()
    if s.startswith("shoe_"):
        s = s[len("shoe_"):]
    try:
        return int(s)
    except (TypeError, ValueError):
        return None


def _media_url(image_path: str) -> str:
    """Путь-ассет Store ('assets/images/products/X.jpg') → URL бэка
    ('/media/products/X.jpg'), который Квартал может загрузить по сети.
    Бэк отдаёт эти файлы из примонтированной папки sport_store (см. docker-compose)."""
    p = str(image_path or "").strip()
    if not p:
        return ""
    if p.startswith("http") or p.startswith("/media/"):
        return p
    return f"/media/products/{p.split('/')[-1]}"


def create_for_order(uid: str, order_id: str, items: list) -> int:
    """Создаёт ShoeAsset (статус 'pending' — ждёт подтверждения пользователя) для
    каждой пары обуви в заказе. Идемпотентно по (user, order, product). Возвращает
    число созданных. Никогда не бросает — оформление заказа не должно падать из-за трекера."""
    created = 0
    try:
        from catalog.models import Product

        for it in items or []:
            pid = str(it.get("productId") or "").strip()
            if not pid:
                continue
            prod = Product.objects.filter(pk=pid).first()
            # Только обувь (категория 'shoes'); неизвестный товар пропускаем.
            if not prod or prod.category_id != "shoes":
                continue
            qty = int(it.get("quantity") or 1)
            raw = (prod.image_urls or [None])[0] or it.get("imageUrl")
            image = _media_url(raw or "")
            model = prod.name or it.get("productName") or "Кроссовки"
            for _ in range(max(1, qty)):
                # update_or_create по (user, order, product) → без дублей при
                # повторном POST того же заказа. Статус по умолчанию 'pending'.
                _, was_created = ShoeAsset.objects.get_or_create(
                    user_id=uid,
                    order_id=order_id,
                    product_id=pid,
                    defaults={"model": model, "image_url": image},
                )
                if was_created:
                    created += 1
    except Exception:
        # трекер — не критичный путь, заказ важнее
        pass
    return created


@api_view(["GET"])
def shoes(request):
    """Трекер: только подтверждённые (active) кроссовки пользователя."""
    uid = user_id_from_request(request)
    if not uid:
        return Response({"detail": "Нет токена"}, status=401)
    rows = ShoeAsset.objects.filter(user_id=uid, status=ShoeAsset.STATUS_ACTIVE)
    return Response([s.to_json() for s in rows])


@api_view(["GET"])
def shoes_pending(request):
    """Купленные пары, ждущие решения пользователя «добавить в трекер?»."""
    uid = user_id_from_request(request)
    if not uid:
        return Response({"detail": "Нет токена"}, status=401)
    rows = ShoeAsset.objects.filter(user_id=uid, status=ShoeAsset.STATUS_PENDING)
    return Response([s.to_json() for s in rows])


@api_view(["POST"])
def shoe_confirm(request, shoe_id):
    """Решение пользователя по pending-паре: body {add: true|false}.
    add=true → active (попадает в трекер, считаем км); add=false → declined (скрыта)."""
    uid = user_id_from_request(request)
    if not uid:
        return Response({"detail": "Нет токена"}, status=401)
    pk = _pk_from_shoe_id(shoe_id)
    if pk is None:
        return Response({"detail": "Некорректный id"}, status=400)
    shoe = ShoeAsset.objects.filter(pk=pk, user_id=uid).first()
    if not shoe:
        return Response({"detail": "Кроссовки не найдены"}, status=404)
    add = request.data.get("add")
    shoe.status = ShoeAsset.STATUS_ACTIVE if add else ShoeAsset.STATUS_DECLINED
    shoe.save(update_fields=["status"])
    return Response(shoe.to_json())


@api_view(["POST"])
def shoe_distance(request, shoe_id):
    """Добавить пробег к ресурсу кроссовок: body {km, runId?}. Идемпотентно по
    runId (повтор той же пробежки из офлайн-очереди не задвоит). Возвращает ShoeAsset."""
    uid = user_id_from_request(request)
    if not uid:
        return Response({"detail": "Нет токена"}, status=401)
    pk = _pk_from_shoe_id(shoe_id)
    if pk is None:
        return Response({"detail": "Некорректный id"}, status=400)
    shoe = ShoeAsset.objects.filter(pk=pk, user_id=uid).first()
    if not shoe:
        return Response({"detail": "Кроссовки не найдены"}, status=404)
    # Километраж идёт только на подтверждённые пары.
    if shoe.status != ShoeAsset.STATUS_ACTIVE:
        return Response({"detail": "Кроссовки не активны"}, status=409)
    run_id = str(request.data.get("runId") or "").strip()
    if run_id and run_id in (shoe.applied_runs or []):
        return Response({**shoe.to_json(), "deduped": True})
    try:
        km = float(request.data.get("km") or 0)
    except (TypeError, ValueError):
        km = 0
    if km < 0:
        return Response({"detail": "Некорректный километраж"}, status=400)
    shoe.total_km += km
    if shoe.total_km >= shoe.max_km:
        shoe.retired = True
    fields = ["total_km", "retired"]
    if run_id:
        shoe.applied_runs = (shoe.applied_runs or []) + [run_id]
        fields.append("applied_runs")
    shoe.save(update_fields=fields)
    return Response(shoe.to_json())
