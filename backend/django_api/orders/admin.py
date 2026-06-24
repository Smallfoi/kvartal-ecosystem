from django.contrib import admin
from unfold.admin import ModelAdmin

from common.adminutils import UserRefMixin

from .models import Order


@admin.register(Order)
class OrderAdmin(UserRefMixin, ModelAdmin):
    list_display = (
        "order_id",
        "user_ref",
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
