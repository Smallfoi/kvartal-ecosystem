from django.contrib import admin
from unfold.admin import ModelAdmin

from common.adminutils import ExportCsvMixin, UserRefMixin

from .models import LoyaltyTransaction


@admin.register(LoyaltyTransaction)
class LoyaltyTransactionAdmin(ExportCsvMixin, UserRefMixin, ModelAdmin):
    list_display = (
        "id",
        "user_ref",
        "amount",
        "source",
        "description",
        "order_id",
        "created_at",
    )
    list_filter = ("source",)
    search_fields = ("user_id", "description", "order_id", "run_id")
    date_hierarchy = "created_at"
    ordering = ("-created_at",)
    readonly_fields = ("id",)
    actions = ("export_as_csv",)
    csv_filename = "loyalty_transactions"
    export_fields = ("id", "user_id", "amount", "source", "description",
                     "order_id", "run_id", "created_at")

    # Финансовый реестр: баланс/уровень пользователя = сумма транзакций
    # (loyalty.models.balance_of). Ручная правка/удаление молча исказит баланс,
    # поэтому существующие записи — только просмотр. Корректировка — новой записью
    # (add остаётся доступным), а не редактированием/удалением истории.
    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False
