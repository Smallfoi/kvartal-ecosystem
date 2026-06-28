from django.contrib import admin
from django.db.models import Avg, Count
from django.utils.html import format_html, format_html_join
from unfold.admin import ModelAdmin

from .models import Banner, Category, Product, Review


@admin.action(description="Опубликовать (на витрину)")
def make_published(modeladmin, request, queryset):
    n = queryset.update(is_published=True)
    modeladmin.message_user(request, f"Опубликовано: {n}")


@admin.action(description="Снять с публикации (в черновик)")
def make_draft(modeladmin, request, queryset):
    n = queryset.update(is_published=False)
    modeladmin.message_user(request, f"В черновик: {n}")


@admin.register(Category)
class CategoryAdmin(ModelAdmin):
    list_display = ("id", "name", "emoji", "sort")
    list_display_links = ("id", "name")  # имя кликабельно → открыть/редактировать
    list_editable = ("sort",)
    search_fields = ("id", "name")
    ordering = ("sort",)


@admin.register(Product)
class ProductAdmin(ModelAdmin):
    list_display = (
        "preview",
        "id",
        "name",
        "brand",
        "category_id",
        "price",
        "old_price",
        "in_stock",
        "is_published",
        "is_featured",
        "is_new",
        "sort",
    )
    list_display_links = ("id", "name")
    list_editable = (
        "price",
        "old_price",
        "in_stock",
        "is_published",
        "is_featured",
        "is_new",
        "sort",
    )
    list_filter = ("category_id", "brand", "in_stock", "is_published", "is_featured", "is_new")
    search_fields = ("id", "name", "brand", "description")
    ordering = ("sort",)
    actions = [make_published, make_draft]
    fieldsets = (
        ("Основное", {
            "fields": ("id", "name", "brand", "category_id", "description"),
        }),
        ("Фото", {
            "fields": ("image", "preview_large", "image_urls"),
            "description": "Загрузите фото — оно используется в каталоге и трекере "
            "кроссовок Квартала. image_urls — старые бандл-ассеты (можно не трогать).",
        }),
        ("Цена и наличие", {
            "fields": ("price", "old_price", "in_stock", "sizes", "colors"),
        }),
        ("Витрина", {
            "fields": ("is_published", "is_new", "is_featured", "rating",
                       "review_count", "sort"),
            "description": "is_published — виден ли товар на витрине (сайт/приложение). "
            "Снимите галочку, чтобы держать как черновик и смотреть в превью.",
        }),
    )
    readonly_fields = ("preview_large",)

    @admin.display(description="Фото")
    def preview(self, obj):
        url = obj.network_image_url()
        if url:
            return format_html(
                '<img src="{}" style="height:38px;width:38px;'
                'object-fit:cover;border-radius:6px"/>',
                url,
            )
        return "—"

    @admin.display(description="Текущее фото")
    def preview_large(self, obj):
        url = obj.network_image_url()
        if url:
            return format_html(
                '<img src="{}" style="max-height:160px;border-radius:10px"/>', url
            )
        return "Нет фото"


@admin.register(Banner)
class BannerAdmin(ModelAdmin):
    list_display = ("id", "title", "subtitle", "action", "is_published", "sort")
    list_display_links = ("id", "title")  # заголовок кликабелен → открыть/редактировать
    list_editable = ("is_published", "sort")
    list_filter = ("is_published",)
    search_fields = ("title", "subtitle")
    ordering = ("sort",)
    actions = [make_published, make_draft]


# ── Модерация отзывов ───────────────────────────────────────────────────────

def _recompute_product_rating(product_id):
    """Пересчёт рейтинга/кол-ва товара по видимым отзывам (скрытые не считаются)."""
    agg = Review.objects.filter(product_id=product_id, hidden=False).aggregate(
        a=Avg("rating"), c=Count("id")
    )
    Product.objects.filter(id=product_id).update(
        rating=round(agg["a"] or 0, 1), review_count=agg["c"] or 0
    )


@admin.action(description="Скрыть (модерация)")
def hide_reviews(modeladmin, request, queryset):
    pids = set(queryset.values_list("product_id", flat=True))
    n = queryset.update(hidden=True)
    for pid in pids:
        _recompute_product_rating(pid)
    modeladmin.message_user(request, f"Скрыто отзывов: {n}")


@admin.action(description="Показать (снять скрытие)")
def show_reviews(modeladmin, request, queryset):
    pids = set(queryset.values_list("product_id", flat=True))
    n = queryset.update(hidden=False)
    for pid in pids:
        _recompute_product_rating(pid)
    modeladmin.message_user(request, f"Показано отзывов: {n}")


@admin.register(Review)
class ReviewAdmin(ModelAdmin):
    list_display = (
        "id", "product_id", "user_id", "rating", "short_text",
        "photos_count", "hidden", "created_at",
    )
    list_display_links = ("id",)
    list_editable = ("hidden",)
    list_filter = ("hidden", "rating", "created_at")
    search_fields = ("id", "product_id", "user_id", "text")
    ordering = ("-created_at",)
    actions = [hide_reviews, show_reviews]
    readonly_fields = ("photos_preview", "created_at")

    @admin.display(description="Текст")
    def short_text(self, obj):
        t = obj.text or ""
        return (t[:60] + "…") if len(t) > 60 else (t or "—")

    @admin.display(description="Фото")
    def photos_count(self, obj):
        return len(obj.photos or [])

    @admin.display(description="Фото отзыва")
    def photos_preview(self, obj):
        urls = obj.photos or []
        if not urls:
            return "Нет фото"
        return format_html_join(
            "",
            '<img src="{}" style="height:90px;border-radius:8px;'
            'margin:0 6px 6px 0;object-fit:cover"/>',
            ((u,) for u in urls),
        )
