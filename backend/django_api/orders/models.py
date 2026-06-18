"""Заказы Store на бэке (D-13). Храним полный payload заказа (контракт SportStore)
как JSON + несколько колонок для запросов. Заказ привязан к пользователю (Bearer)."""
from django.db import models
from django.utils import timezone


class Order(models.Model):
    user_id = models.CharField(max_length=40, db_index=True)
    order_id = models.CharField(max_length=40)  # клиентский id (SS-xxxxx)
    total = models.FloatField(default=0)
    status = models.CharField(max_length=20, default="pending")
    points_redeemed = models.IntegerField(default=0)
    payload = models.JSONField(default=dict)  # полный json заказа от клиента
    created_at = models.DateTimeField(default=timezone.now)

    class Meta:
        db_table = "store_orders"
        ordering = ["-created_at"]
        # Идемпотентность: один и тот же заказ пользователя не дублируется.
        unique_together = (("user_id", "order_id"),)

    def to_json(self) -> dict:
        # payload уже в точном контракте SportStore (Order.fromJson).
        return self.payload
