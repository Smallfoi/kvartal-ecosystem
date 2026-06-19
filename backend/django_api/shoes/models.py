"""ShoeAsset — связка экосистемы Store ↔ Квартал (ECOSYSTEM_API §2.5, IDEAS.md).
Купил кроссовки в Store → создаётся ресурс «износа»; Квартал показывает остаток
километража и убавляет его после пробежек (POST /shoes/<id>/distance)."""
from django.db import models
from django.utils import timezone


class ShoeAsset(models.Model):
    user_id = models.CharField(max_length=40, db_index=True)
    product_id = models.CharField(max_length=40)
    order_id = models.CharField(max_length=40, blank=True, default="")
    model = models.CharField(max_length=200, blank=True, default="")
    image_url = models.CharField(max_length=400, blank=True, default="")
    total_km = models.FloatField(default=0)
    max_km = models.FloatField(default=600)
    retired = models.BooleanField(default=False)
    created_at = models.DateTimeField(default=timezone.now)

    class Meta:
        db_table = "store_shoes"
        ordering = ["-created_at"]
        # Идемпотентность: одна пара кроссовок из заказа не дублируется.
        unique_together = (("user_id", "order_id", "product_id"),)

    def to_json(self) -> dict:
        return {
            "id": f"shoe_{self.pk}",
            "userId": self.user_id,
            "productId": self.product_id,
            "orderId": self.order_id,
            "model": self.model,
            "imageUrl": self.image_url,
            "purchasedAt": self.created_at.isoformat(),
            "totalKm": round(self.total_km, 1),
            "maxKm": self.max_km,
            "retired": self.retired,
            # удобные производные для UI Квартала
            "remainingKm": max(0.0, round(self.max_km - self.total_km, 1)),
            "wearPercent": (
                min(100, round(self.total_km / self.max_km * 100))
                if self.max_km
                else 0
            ),
        }
