from django.contrib import admin

from .models import ShoeAsset


@admin.register(ShoeAsset)
class ShoeAssetAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "user_id",
        "model",
        "status",
        "total_km",
        "max_km",
        "retired",
        "order_id",
        "created_at",
    )
    list_filter = ("status", "retired")
    search_fields = ("user_id", "model", "order_id", "product_id")
    date_hierarchy = "created_at"
