"""Каталог Store (D-13). Публичные read-эндпоинты — токен не нужен.
Контракт совпадает с ApiProductRepository в SportStore."""
import secrets

from django.db.models import Avg, Count, Q
from django.utils import timezone
from rest_framework.decorators import api_view
from rest_framework.response import Response

from accounts.models import Account
from common.security import user_id_from_request
from orders.models import Order

from .models import Banner, Category, Product, Review

_TRUE = {"1", "true", "True", "yes"}


def _is_preview(request) -> bool:
    """preview=1 → отдаём и черновики (для админ-превью); иначе только опубликованное."""
    return request.query_params.get("preview") in _TRUE


def _visible_products(request):
    qs = Product.objects.all()
    if not _is_preview(request):
        qs = qs.filter(is_published=True)
    return qs


@api_view(["GET"])
def categories(request):
    return Response([c.to_json() for c in Category.objects.all()])


@api_view(["GET"])
def products(request):
    qs = _visible_products(request)
    cat = request.query_params.get("category")
    if cat and cat != "all":
        qs = qs.filter(category_id=cat)
    if request.query_params.get("featured") in _TRUE:
        qs = qs.filter(is_featured=True)
    if request.query_params.get("new") in _TRUE:
        qs = qs.filter(is_new=True)
    return Response([p.to_json() for p in qs])


@api_view(["GET"])
def product_search(request):
    q = (request.query_params.get("q") or "").strip()
    qs = _visible_products(request)
    if q:
        qs = qs.filter(
            Q(name__icontains=q) | Q(description__icontains=q) | Q(brand__icontains=q)
        )
    return Response([p.to_json() for p in qs])


@api_view(["GET"])
def product_price_range(request):
    vals = list(Product.objects.values_list("price", flat=True))
    if not vals:
        return Response({"min": 0, "max": 0})
    return Response({"min": min(vals), "max": max(vals)})


@api_view(["GET"])
def product_detail(request, pid):
    p = Product.objects.filter(id=pid).first()
    if not p or (not p.is_published and not _is_preview(request)):
        return Response({"detail": "Товар не найден"}, status=404)
    return Response(p.to_json())


@api_view(["GET"])
def brands(request):
    return Response(sorted(set(Product.objects.values_list("brand", flat=True))))


@api_view(["GET"])
def sizes(request):
    order = ["XS", "S", "M", "L", "XL", "XXL", "39", "40", "41", "42", "43", "44", "45"]
    found = set()
    for arr in Product.objects.values_list("sizes", flat=True):
        for s in (arr or []):
            if s != "Один размер":
                found.add(s)
    return Response(
        sorted(found, key=lambda x: (order.index(x) if x in order else 999, x))
    )


@api_view(["GET"])
def banners(request):
    qs = Banner.objects.all()
    if not _is_preview(request):
        qs = qs.filter(is_published=True)
    return Response([b.to_json() for b in qs])


# ── Отзывы на товары ────────────────────────────────────────────────────────

def _recompute_rating(product_id):
    # Скрытые модерацией отзывы не влияют на рейтинг.
    agg = Review.objects.filter(product_id=product_id, hidden=False).aggregate(
        a=Avg("rating"), c=Count("id")
    )
    Product.objects.filter(id=product_id).update(
        rating=round(agg["a"] or 0, 1), review_count=agg["c"] or 0
    )


def _has_purchased(uid, product_id):
    for o in Order.objects.filter(user_id=uid).only("payload"):
        for it in (o.payload or {}).get("items", []):
            if isinstance(it, dict) and it.get("productId") == product_id:
                return True
    return False


def _review_name(uid):
    a = Account.objects.filter(id=uid).only("name").first()
    return a.name if (a and a.name) else "Покупатель"


def _review_json(r, uid):
    return {
        "id": r.id,
        "userId": r.user_id,
        "name": _review_name(r.user_id),
        "rating": r.rating,
        "text": r.text,
        "photos": r.photos or [],
        "createdAt": r.created_at.isoformat(),
        "mine": r.user_id == uid,
    }


@api_view(["GET", "POST"])
def product_reviews(request, pid):
    """GET — список отзывов товара (+ можно ли оставить). POST — оставить/обновить
    свой отзыв (только купившие товар). Рейтинг товара пересчитывается."""
    product = Product.objects.filter(id=pid).first()
    if not product:
        return Response({"detail": "Товар не найден"}, status=404)
    uid = user_id_from_request(request)
    if request.method == "GET":
        reviews = [
            _review_json(r, uid)
            for r in Review.objects.filter(product_id=pid, hidden=False)
        ]
        return Response(
            {
                "rating": product.rating,
                "reviewCount": product.review_count,
                "reviews": reviews,
                "canReview": bool(uid and _has_purchased(uid, pid)),
                "hasMine": any(r["mine"] for r in reviews) if uid else False,
            }
        )
    if not uid:
        return Response({"detail": "Нет токена"}, status=401)
    if not _has_purchased(uid, pid):
        return Response({"detail": "Отзыв доступен после покупки товара"}, status=403)
    d = request.data
    try:
        rating = int(d.get("rating") or 0)
    except (TypeError, ValueError):
        rating = 0
    if rating < 1 or rating > 5:
        return Response({"detail": "Оценка должна быть от 1 до 5"}, status=400)
    text = (d.get("text") or "").strip()[:2000]
    # Фото отзыва: до 5 URL (загружаются через POST /v1/reviews/photo).
    photos = d.get("photos")
    if not isinstance(photos, list):
        photos = []
    photos = [str(p).strip() for p in photos if isinstance(p, str) and p.strip()][:5]
    obj = Review.objects.filter(product_id=pid, user_id=uid).first()
    if obj:
        obj.rating = rating
        obj.text = text
        obj.photos = photos
        obj.created_at = timezone.now()
        obj.save()
    else:
        obj = Review.objects.create(
            id=f"rev_{secrets.token_hex(8)}",
            product_id=pid,
            user_id=uid,
            rating=rating,
            text=text,
            photos=photos,
        )
    _recompute_rating(pid)
    product.refresh_from_db()
    return Response(
        {
            "rating": product.rating,
            "reviewCount": product.review_count,
            "review": _review_json(obj, uid),
        }
    )


@api_view(["POST"])
def review_photo(request):
    """Загрузка фото к отзыву (multipart `image`) → URL в media. Авторизованные;
    право оставить отзыв проверяется при сохранении (купившие товар)."""
    uid = user_id_from_request(request)
    if not uid:
        return Response({"detail": "Нет токена"}, status=401)
    f = request.FILES.get("image")
    if not f:
        return Response({"detail": "Нет файла"}, status=400)
    if f.size > 5 * 1024 * 1024:
        return Response({"detail": "Файл слишком большой (макс 5 МБ)"}, status=400)
    if not (f.content_type or "").startswith("image/"):
        return Response({"detail": "Нужен файл-изображение"}, status=400)
    from django.core.files.storage import default_storage

    ext = (f.name.rsplit(".", 1)[-1] if "." in f.name else "jpg").lower()[:5]
    saved = default_storage.save(
        f"uploads/reviews/{uid}_{secrets.token_hex(6)}.{ext}", f
    )
    return Response({"url": f"/media/{saved}"})
