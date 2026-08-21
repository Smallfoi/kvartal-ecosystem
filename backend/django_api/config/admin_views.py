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


# ── Контент сайта (мини-CMS): тексты и фото шапки/hero/секций ────────────────

@staff_member_required
@require_http_methods(["POST"])
def merch_site_content(request):
    """Правка текста блока сайта: {key, value} → SiteContent (публикуется на сайт)."""
    from catalog.models import SiteContent

    try:
        d = json.loads(request.body or b"{}")
    except ValueError:
        return JsonResponse({"detail": "Некорректный JSON"}, status=400)
    key = (d.get("key") or "").strip()[:80]
    if not key:
        return JsonResponse({"detail": "Нет ключа"}, status=400)
    obj, _ = SiteContent.objects.get_or_create(key=key)
    obj.value = str(d.get("value") or "")
    obj.save()
    return JsonResponse({"ok": True, "content": {key: obj.to_json()}})


@staff_member_required
@require_http_methods(["POST"])
def merch_site_image(request):
    """Замена фото блока сайта: multipart image + key → SiteContent.image."""
    from catalog.models import SiteContent

    key = (request.POST.get("key") or "").strip()[:80]
    if not key:
        return JsonResponse({"detail": "Нет ключа"}, status=400)
    f = request.FILES.get("image")
    if not f:
        return JsonResponse({"detail": "Нет файла"}, status=400)
    if f.size > 40 * 1024 * 1024:
        return JsonResponse({"detail": "Файл слишком большой (макс 40 МБ)"}, status=400)
    if not (f.content_type or "").startswith("image/"):
        return JsonResponse({"detail": "Нужен файл-изображение"}, status=400)
    obj, _ = SiteContent.objects.get_or_create(key=key)
    obj.image = f
    obj.save()
    return JsonResponse({"ok": True, "content": {key: obj.to_json()}})


@staff_member_required
@require_http_methods(["POST"])
def merch_site_video(request):
    """Загрузка короткого видео на фон блока: multipart video → сохраняем в
    хранилище и возвращаем URL. URL кладётся фронтом в bgvid.<key> через /site-content
    (как обычная ссылка) — отдельная модель/миграция не нужны."""
    from django.core.files.storage import default_storage
    from django.utils.text import get_valid_filename

    f = request.FILES.get("video")
    if not f:
        return JsonResponse({"detail": "Нет файла"}, status=400)
    if f.size > 200 * 1024 * 1024:
        return JsonResponse({"detail": "Файл слишком большой (макс 200 МБ)"}, status=400)
    ct = (f.content_type or "").lower()
    name = (f.name or "").lower()
    if not (ct.startswith("video/") or name.endswith((".mp4", ".webm", ".ogg", ".mov"))):
        return JsonResponse({"detail": "Нужен видео-файл (.mp4/.webm)"}, status=400)
    safe = get_valid_filename(f.name or "clip.mp4") or "clip.mp4"
    saved = default_storage.save("uploads/site-video/" + safe, f)
    # Качество (управляет владелец при загрузке): web — лёгкое для сайта; high — 1080p;
    # original — без сжатия (4K, полное качество, но грузится дольше).
    quality = (request.POST.get("quality") or "web").lower()
    if quality != "original":
        saved = _webify_video(saved, quality) or saved
    return JsonResponse({"ok": True, "url": default_storage.url(saved)})


# Пресеты сжатия: макс. сторона (px) и CRF (меньше = лучше качество/больше вес).
_VIDEO_PRESETS = {"web": ("1280", "30"), "high": ("1920", "24")}


def _webify_video(saved, quality="web"):
    """Транскод фонового видео в web-формат по пресету качества (web/high). Камерные
    ролики огромны (80-100 МБ, 4K) и долго декодируются в браузере. Делаем H.264,
    ≤maxdim, без звука, faststart. Только локальное хранилище (dev/диск); на S3 или без
    ffmpeg — тихо None (отдаётся оригинал). Возвращает имя web-версии либо None."""
    import os
    import subprocess
    from django.core.files.storage import default_storage
    maxdim, crf = _VIDEO_PRESETS.get(quality, _VIDEO_PRESETS["web"])
    try:
        src = default_storage.path(saved)  # NotImplementedError на нелокальном хранилище
    except Exception:
        return None
    try:
        import imageio_ffmpeg
        ff = imageio_ffmpeg.get_ffmpeg_exe()
    except Exception:
        return None
    web_name = os.path.splitext(saved)[0] + "_web.mp4"
    web_path = default_storage.path(web_name)
    scale = ("scale=w=%s:h=%s:force_original_aspect_ratio=decrease:force_divisible_by=2"
             % (maxdim, maxdim))
    try:
        os.makedirs(os.path.dirname(web_path), exist_ok=True)
        subprocess.run(
            [ff, "-y", "-i", src, "-vf", scale,
             "-c:v", "libx264", "-crf", crf, "-preset", "veryfast", "-pix_fmt", "yuv420p",
             "-an", "-movflags", "+faststart", web_path],
            check=True, timeout=600, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
    except Exception:
        try:
            if os.path.exists(web_path):
                os.remove(web_path)
        except Exception:
            pass
        return None
    if not os.path.exists(web_path) or os.path.getsize(web_path) == 0:
        return None
    try:
        default_storage.delete(saved)  # оригинал-тяжеловес больше не нужен
    except Exception:
        pass
    return web_name


# ── Баннеры (промо) в конструкторе: полный CRUD перенесён из Django-админки ───
# Раньше баннеры правились только в Catalog → Banner. Теперь — визуально в
# «Конструкторе» (владелец: всё визуальное в одном месте). Данные общие, порядок
# раздельный по площадкам (sort_site/sort_app), как у товаров.

def _banner_json(b):
    return {
        "id": b.id,
        "title": b.title,
        "subtitle": b.subtitle,
        "action": b.action,
        "imageUrl": b.network_image_url(),
        "isPublished": b.is_published,
        "imageFit": b.image_fit or "cover",
        "imageFocal": b.image_focal or "50% 50%",
        "sortSite": b.sort_site,
        "sortApp": b.sort_app,
    }


_TRUE = ("1", "true", "True", "on", "yes", True)


def _apply_banner_fields(b, post, files):
    """Обновить поля баннера из multipart-формы (image опционально). Кидает ValueError."""
    if "title" in post:
        b.title = str(post.get("title") or "").strip()[:200]
    if "subtitle" in post:
        b.subtitle = str(post.get("subtitle") or "").strip()[:200]
    if "action" in post:
        b.action = str(post.get("action") or "").strip()[:80]
    if "isPublished" in post:
        b.is_published = post.get("isPublished") in _TRUE
    if "imageFit" in post:
        b.image_fit = "contain" if post.get("imageFit") == "contain" else "cover"
    if "imageFocal" in post:
        v = str(post.get("imageFocal") or "").strip()[:16]
        b.image_focal = v if v else "50% 50%"
    f = files.get("image")
    if f:
        if f.size > 40 * 1024 * 1024:
            raise ValueError("Файл слишком большой (макс 40 МБ)")
        if not (f.content_type or "").startswith("image/"):
            raise ValueError("Нужен файл-изображение")
        b.image = f


@staff_member_required
@require_http_methods(["GET"])
def merch_banners(request):
    """Список баннеров для конструктора в порядке выбранной площадки."""
    from catalog.models import Banner

    platform = (request.GET.get("platform") or "site").strip().lower()
    field = _PLATFORM_FIELD.get(platform, "sort")
    qs = Banner.objects.all().order_by(field, "sort", "id")
    return JsonResponse({"banners": [_banner_json(b) for b in qs]})


@staff_member_required
@require_http_methods(["POST"])
def merch_banner_create(request):
    """Создать баннер (multipart: title/subtitle/action/isPublished + image)."""
    from django.db.models import Max

    from catalog.models import Banner

    b = Banner()
    try:
        _apply_banner_fields(b, request.POST, request.FILES)
    except ValueError as e:
        return JsonResponse({"detail": str(e)}, status=400)
    if not b.title:
        return JsonResponse({"detail": "Нужен заголовок"}, status=400)
    agg = Banner.objects.aggregate(s=Max("sort_site"), a=Max("sort_app"), g=Max("sort"))
    b.sort_site = (agg["s"] if agg["s"] is not None else -1) + 1
    b.sort_app = (agg["a"] if agg["a"] is not None else -1) + 1
    b.sort = (agg["g"] if agg["g"] is not None else -1) + 1
    b.save()
    return JsonResponse({"ok": True, "banner": _banner_json(b)})


@staff_member_required
@require_http_methods(["POST"])
def merch_banner(request, bid):
    """Правка баннера (multipart, image опционально)."""
    from catalog.models import Banner

    b = Banner.objects.filter(id=bid).first()
    if not b:
        return JsonResponse({"detail": "Баннер не найден"}, status=404)
    try:
        _apply_banner_fields(b, request.POST, request.FILES)
    except ValueError as e:
        return JsonResponse({"detail": str(e)}, status=400)
    b.save()
    return JsonResponse({"ok": True, "banner": _banner_json(b)})


@staff_member_required
@require_http_methods(["POST"])
def merch_banner_delete(request, bid):
    """Удалить баннер."""
    from catalog.models import Banner

    n, _ = Banner.objects.filter(id=bid).delete()
    if not n:
        return JsonResponse({"detail": "Баннер не найден"}, status=404)
    return JsonResponse({"ok": True})


@staff_member_required
@require_http_methods(["POST"])
def merch_banner_reorder(request):
    """Порядок баннеров для площадки: {platform, order:[id,...]} → sort_site/app."""
    from catalog.models import Banner

    try:
        data = json.loads(request.body or b"{}")
    except ValueError:
        return JsonResponse({"detail": "Некорректный JSON"}, status=400)
    field = _PLATFORM_FIELD.get((data.get("platform") or "").strip().lower())
    if not field:
        return JsonResponse({"detail": "Неизвестная площадка"}, status=400)
    order = data.get("order") or []
    for i, bid in enumerate(order):
        Banner.objects.filter(id=bid).update(**{field: i})
    return JsonResponse({"ok": True, "count": len(order)})
