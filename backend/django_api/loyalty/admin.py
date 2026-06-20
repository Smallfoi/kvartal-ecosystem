from django.contrib import admin
from unfold.admin import ModelAdmin

from .models import LoyaltyTransaction


@admin.register(LoyaltyTransaction)
class LoyaltyTransactionAdmin(ModelAdmin):
    list_display = (
        "id",
        "user_id",
        "amount",
        "source",
        "description",
        "order_id",
        "created_at",
    )
    list_filter = ("source",)
    search_fields = ("user_id", "description", "order_id", "run_id")
    date_hierarchy = "created_at"
    readonly_fields = ("id",)
