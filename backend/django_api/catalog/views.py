"""Каталог Store (D-13). Публичные read-эндпоинты — токен не нужен.
Контракт совпадает с ApiProductRepository в SportStore."""
from django.db.models import Q
from rest_framework.decorators import api_view
from rest_framework.response import Response

from .models import Banner, Category, Product

_TRUE = {"1", "true", "True", "yes"}


@api_view(["GET"])
def categories(request):
    return Response([c.to_json() for c in Category.objects.all()])


@api_view(["GET"])
def products(request):
    qs = Product.objects.all()
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
    qs = Product.objects.all()
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
    if not p:
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
    return Response([b.to_json() for b in Banner.objects.all()])
