"""Приём каталога из 1С (D-62).

Источник правды по номенклатуре — 1С, но владелец может точечно переопределить
поле в Конструкторе. Правило одно: импорт обновляет поле, ТОЛЬКО если владелец
его не трогал. Что пришло из 1С, всегда сохраняем в `from_1c` — чтобы показать
расхождение и дать кнопку «вернуть как в 1С».

Остаток владельцу переопределять нельзя: показать размер, которого нет на складе,
дороже, чем неудобство. Поэтому `stock` всегда пишется из 1С.
"""
import hashlib

from django.utils import timezone
from django.utils.dateparse import parse_datetime

from catalog.models import Product

# Поле в JSON от 1С → поле модели. Ключи совпадают с Product.OVERRIDABLE.
FIELD_MAP = {
    "price": "price",
    "oldPrice": "old_price",
    "description": "description",
    "sizes": "sizes",
    "colors": "colors",
    "images": "image_urls",
}


def _make_id(external_id: str, article: str) -> str:
    """Внутренний id для НОВОГО товара. Идентификатор 1С в первичный ключ не кладём:
    на него уже ссылаются заказы и отзывы, менять их формат нельзя."""
    base = (article or external_id or "").strip()
    if base and len(base) <= 40 and not Product.objects.filter(id=base).exists():
        return base
    return "p_" + hashlib.sha1((external_id or article).encode("utf-8")).hexdigest()[:16]


def _find(external_id: str, article: str):
    if external_id:
        p = Product.objects.filter(external_id=external_id).first()
        if p:
            return p
    if article:
        return Product.objects.filter(article=article).first()
    return None


def _apply(product: Product, payload: dict, fields: dict) -> list:
    """Записать пришедшие поля: эффективное значение — только если не переопределено.
    Возвращает список полей, которые владелец удержал за собой (для отчёта)."""
    kept = []
    src = dict(product.from_1c or {})
    for json_field, model_field in fields.items():
        if json_field not in payload:
            continue
        value = payload[json_field]
        src[json_field] = value
        if product.is_overridden(json_field):
            kept.append(json_field)
            continue
        setattr(product, model_field, value)
    product.from_1c = src
    return kept


def import_catalog(items) -> dict:
    """Карточки товаров: наименование, категория, бренд, описание, размеры, фото."""
    created = updated = skipped = 0
    kept_fields: set = set()
    errors = []

    for raw in items:
        if not isinstance(raw, dict):
            errors.append("элемент не объект")
            continue
        external_id = str(raw.get("id") or "").strip()
        article = str(raw.get("article") or "").strip()
        if not external_id and not article:
            errors.append("нет id и артикула")
            continue

        product = _find(external_id, article)
        is_new = product is None
        if is_new:
            if not raw.get("name"):
                errors.append(f"{external_id or article}: нет наименования")
                continue
            product = Product(id=_make_id(external_id, article), price=0)

        # Поля, которые ведёт только 1С.
        product.external_id = external_id or product.external_id
        product.article = article or product.article
        if raw.get("name"):
            product.name = raw["name"]
        if raw.get("categoryId"):
            product.category_id = raw["categoryId"]
        if "brand" in raw:
            product.brand = raw.get("brand") or ""
        if "active" in raw:
            product.is_active_1c = bool(raw["active"])
        if raw.get("updatedAt"):
            product.source_updated_at = parse_datetime(raw["updatedAt"]) or timezone.now()

        kept_fields.update(_apply(product, raw, FIELD_MAP))
        product.save()
        created += int(is_new)
        updated += int(not is_new)

    return {
        "received": len(items), "created": created, "updated": updated,
        "skipped": skipped, "keptByOwner": sorted(kept_fields), "errors": errors[:20],
    }


def import_prices(items) -> dict:
    """Цены и остатки — частый поток. Остаток пишем всегда, цену — если не переопределена."""
    updated = 0
    kept_fields: set = set()
    errors = []

    for raw in items:
        if not isinstance(raw, dict):
            errors.append("элемент не объект")
            continue
        external_id = str(raw.get("id") or "").strip()
        article = str(raw.get("article") or "").strip()
        product = _find(external_id, article)
        if product is None:
            errors.append(f"{external_id or article}: товар не найден")
            continue

        kept_fields.update(_apply(product, raw, {"price": "price", "oldPrice": "old_price"}))

        variants = raw.get("variants")
        if isinstance(variants, list):
            total = sum(int(v.get("stock") or 0) for v in variants if isinstance(v, dict))
            product.stock_count = total
            src = dict(product.from_1c or {})
            src["variants"] = variants
            product.from_1c = src
        elif "stock" in raw:
            product.stock_count = int(raw.get("stock") or 0)

        if product.stock_count is not None:
            product.in_stock = product.stock_count > 0

        product.save()
        updated += 1

    return {"received": len(items), "updated": updated,
            "keptByOwner": sorted(kept_fields), "errors": errors[:20]}
