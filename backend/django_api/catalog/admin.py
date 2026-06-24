from django.contrib import admin
from django.utils.html import format_html
from unfold.admin import ModelAdmin

from .models import Banner, Category, Product


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
