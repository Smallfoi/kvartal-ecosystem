"""Кастомные страницы админки (вне ModelAdmin): «Конструктор» — live-превью сайта/
приложения + правка (раздельный порядок по площадкам) + публикация с подтверждением.
Отдельные страницы «Превью» убраны — конструктор их заменяет."""
import json

from django.conf import settings
from django.contrib.admin.views.decorators import staff_member_required
from django.http import JsonResponse
from django.shortcuts import render
from django.views.decorators.http import require_http_methods


# ── Конструктор витрины (мерчендайзинг) ──────────────────────────────────────
# Данные товара ОБЩИЕ (одна запись), а порядок раскладки РАЗДЕЛЬНЫЙ по площадкам
# (sort_site / sort_app). Правка товара пишет в центральный Product → меняется везде.

_PLATFORM_FIELD = {"site": "sort_site", "app": "sort_app"}


def _merch_json(p):
    return {
        "id": p.id,
        "name": p.name,
        "imageUrl": p.network_image_url(),
        "price": p.price,
        "oldPrice": p.old_price,
        "inStock": p.in_stock,
        "isPublished": p.is_published,
        "isFeatured": p.is_featured,
        "description": p.description,
        "sizes": p.sizes or [],
        "categoryId": p.category_id,
    }


@staff_member_required
def merch_console(request):
    """«Конструктор витрины»: перетаскивание порядка товаров раздельно для сайта и
    приложения + правка товара (цена/старая цена/описание/наличие/публикация) прямо в
    превью. Данные общие, порядок раздельный."""
    site = getattr(settings, "SITE_PREVIEW_URL", "http://localhost:5577").rstrip("/")
    app = getattr(settings, "APP_PREVIEW_URL", "http://localhost:5578").rstrip("/")
    return render(request, "admin/merch_console.html", {
        "site_preview_url": site + "/?preview=1&platform=site",
        "app_preview_url": app + "/",
    })


@staff_member_required
@require_http_methods(["GET"])
def merch_products(request):
    """Список товаров для конструктора в порядке выбранной площадки."""
    from catalog.models import Product

    platform = (request.GET.get("platform") or "site").strip().lower()
    field = _PLATFORM_FIELD.get(platform, "sort")
    qs = Product.objects.all().order_by(field, "sort", "id")
    return JsonResponse({"products": [_merch_json(p) for p in qs]})


@staff_member_required
@require_http_methods(["POST"])
def merch_reorder(request):
    """Сохранить новый порядок для площадки: {platform, order:[id,...]} → sort_site/app."""
    from catalog.models import Product

    try:
        data = json.loads(request.body or b"{}")
    except ValueError:
        return JsonResponse({"detail": "Некорректный JSON"}, status=400)
    field = _PLATFORM_FIELD.get((data.get("platform") or "").strip().lower())
    if not field:
        return JsonResponse({"detail": "Неизвестная площадка"}, status=400)
    order = data.get("order") or []
    for i, pid in enumerate(order):
        Product.objects.filter(id=pid).update(**{field: i})
    return JsonResponse({"ok": True, "count": len(order)})


@staff_member_required
@require_http_methods(["POST"])
def merch_product(request, pid):
    """Правка ЦЕНТРАЛЬНОГО товара (меняется на всех площадках)."""
    from catalog.models import Product

    p = Product.objects.filter(id=pid).first()
    if not p:
        return JsonResponse({"detail": "Товар не найден"}, status=404)
    try:
        d = json.loads(request.body or b"{}")
    except ValueError:
        return JsonResponse({"detail": "Некорректный JSON"}, status=400)
    if "price" in d:
        try:
            p.price = float(d["price"])
        except (TypeError, ValueError):
            return JsonResponse({"detail": "Некорректная цена"}, status=400)
    if "oldPrice" in d:
        v = d["oldPrice"]
        try:
            p.old_price = float(v) if v not in (None, "", 0, "0") else None
        except (TypeError, ValueError):
            return JsonResponse({"detail": "Некорректная старая цена"}, status=400)
    if "description" in d:
        p.description = str(d["description"] or "")
    if "inStock" in d:
        p.in_stock = bool(d["inStock"])
    if "isPublished" in d:
        p.is_published = bool(d["isPublished"])
    if "isFeatured" in d:
        p.is_featured = bool(d["isFeatured"])
    if isinstance(d.get("sizes"), list):
        p.sizes = [str(s).strip() for s in d["sizes"] if str(s).strip()]
    p.save()
    return JsonResponse({"ok": True, "product": _merch_json(p)})
