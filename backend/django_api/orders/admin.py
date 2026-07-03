from django.contrib import admin
from unfold.admin import ModelAdmin

from common.adminutils import ExportCsvMixin, UserRefMixin

from .models import Order


@admin.register(Order)
class OrderAdmin(ExportCsvMixin, UserRefMixin, ModelAdmin):
    list_display = (
        "order_id",
        "user_ref",
        "total",
        "status",
        "payment_status",
        "points_redeemed",
        "created_at",
    )
    list_display_links = ("order_id",)
    list_editable = ("status",)
    list_filter = ("status", "payment_status")
    search_fields = ("order_id", "user_id")
    date_hierarchy = "created_at"
    ordering = ("-created_at",)
    readonly_fields = ("payload", "created_at")
    csv_filename = "orders"
    export_fields = ("order_id", "user_id", "total", "status", "payment_status",
                     "points_redeemed", "created_at")
    actions = ("mark_paid", "mark_shipped", "mark_delivered", "mark_cancelled",
               "export_as_csv")

    @admin.action(description="Отметить: Оплачен")
    def mark_paid(self, request, queryset):
        n = queryset.update(status="paid")
        self.message_user(request, f"Отмечено «Оплачен»: {n}")

    @admin.action(description="Отметить: Отправлен")
    def mark_shipped(self, request, queryset):
        n = queryset.update(status="shipped")
        self.message_user(request, f"Отмечено «Отправлен»: {n}")

    @admin.action(description="Отметить: Доставлен")
    def mark_delivered(self, request, queryset):
        n = queryset.update(status="delivered")
        self.message_user(request, f"Отмечено «Доставлен»: {n}")

    @admin.action(description="Отметить: Отменён")
    def mark_cancelled(self, request, queryset):
        n = queryset.update(status="cancelled")
        self.message_user(request, f"Отмечено «Отменён»: {n}")
