"""Заказы Store на бэке (D-13). Храним полный payload заказа (контракт SportStore)
как JSON + несколько колонок для запросов. Заказ привязан к пользователю (Bearer)."""
from django.db import models
from django.utils import timezone


class Order(models.Model):
    STATUS_CHOICES = [
        ("pending", "Ожидает"),
        ("paid", "Оплачен"),
        ("shipped", "Отправлен"),
        ("delivered", "Доставлен"),
        ("cancelled", "Отменён"),
    ]

    user_id = models.CharField(max_length=40, db_index=True, verbose_name="Пользователь (ID)")
    order_id = models.CharField(max_length=40, verbose_name="Номер заказа")  # клиентский id (SS-xxxxx)
    total = models.FloatField(default=0, verbose_name="Сумма, ₽")
    status = models.CharField(
        max_length=20, default="pending", choices=STATUS_CHOICES, verbose_name="Статус"
    )
    points_redeemed = models.IntegerField(default=0, verbose_name="Списано баллов")
    payload = models.JSONField(default=dict, verbose_name="Данные заказа (JSON)")
    created_at = models.DateTimeField(default=timezone.now, verbose_name="Создан")

    class Meta:
        db_table = "store_orders"
        ordering = ["-created_at"]
        # Идемпотентность: один и тот же заказ пользователя не дублируется.
        unique_together = (("user_id", "order_id"),)
        verbose_name = "Заказ"
        verbose_name_plural = "Заказы"

    def __str__(self) -> str:
        return self.order_id

    def to_json(self) -> dict:
        # payload уже в точном контракте SportStore (Order.fromJson).
        return self.payload
