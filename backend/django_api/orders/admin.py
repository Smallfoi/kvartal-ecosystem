from django.contrib import admin
from unfold.admin import ModelAdmin

from .models import Order


@admin.register(Order)
class OrderAdmin(ModelAdmin):
    list_display = (
        "order_id",
        "user_id",
        "total",
        "status",
        "points_redeemed",
        "created_at",
    )
    list_display_links = ("order_id",)
    list_editable = ("status",)
    list_filter = ("status",)
    search_fields = ("order_id", "user_id")
    date_hierarchy = "created_at"
    readonly_fields = ("payload", "created_at")
