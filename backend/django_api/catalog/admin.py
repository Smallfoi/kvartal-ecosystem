from django.contrib import admin
from django.utils.html import format_html
from unfold.admin import ModelAdmin

from .models import Banner, Category, Product


@admin.register(Category)
class CategoryAdmin(ModelAdmin):
    list_display = ("id", "name", "emoji", "sort")
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
        "is_featured",
        "is_new",
        "sort",
    )
    list_display_links = ("id", "name")
    list_editable = (
        "price",
        "old_price",
        "in_stock",
        "is_featured",
        "is_new",
        "sort",
    )
    list_filter = ("category_id", "brand", "in_stock", "is_featured", "is_new")
    search_fields = ("id", "name", "brand", "description")
    ordering = ("sort",)
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
            "fields": ("is_new", "is_featured", "rating", "review_count", "sort"),
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
    list_display = ("id", "title", "subtitle", "action", "sort")
    list_editable = ("sort",)
    search_fields = ("title", "subtitle")
    ordering = ("sort",)
