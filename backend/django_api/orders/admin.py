from django.contrib import admin, messages
from unfold.admin import ModelAdmin

from common.adminutils import ExportCsvMixin, UserRefMixin

from .awards import refund_redeemed_points, revoke_purchase_points
from .models import Order
from .payment import PaymentError, create_refund


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
               "refund_payment", "export_as_csv")

    @admin.action(description="Вернуть деньги покупателю (ЮKassa)")
    def refund_payment(self, request, queryset):
        """Полный возврат оплаченного заказа + возврат списанных баллов.

        Возврат делает ЮKassa по нашему запросу; заказ помечается «возвращён».
        Заказы без платежа (dev-режим, неоплаченные) пропускаем — возвращать нечего.
        """
        done, skipped, failed = 0, 0, []
        for order in queryset:
            if not order.payment_id or order.payment_status != "paid":
                skipped += 1
                continue
            try:
                create_refund(order.payment_id, order.total, f"Возврат заказа {order.order_id}")
            except PaymentError as e:
                failed.append(f"{order.order_id}: {e}")
                continue
            order.payment_status = "refunded"
            order.status = "cancelled"
            order.save(update_fields=["payment_status", "status"])
            refund_redeemed_points(order)  # баллы, потраченные на этот заказ, — назад
            revoke_purchase_points(order)  # и начисленные за покупку — снять
            done += 1
        if done:
            self.message_user(request, f"Возвращено заказов: {done}", messages.SUCCESS)
        if skipped:
            self.message_user(
                request, f"Пропущено (нет оплаты): {skipped}", messages.WARNING
            )
        for err in failed:
            self.message_user(request, f"Ошибка возврата — {err}", messages.ERROR)

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
