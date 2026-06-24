"""ShoeAsset — связка экосистемы Store ↔ Квартал (ECOSYSTEM_API §2.5, IDEAS.md).
Купил кроссовки в Store → создаётся ресурс «износа»; Квартал показывает остаток
километража и убавляет его после пробежек (POST /shoes/<id>/distance)."""
from django.db import models
from django.utils import timezone


class ShoeAsset(models.Model):
    # pending — куплены, но пользователь ещё не подтвердил, что носит их для бега
    #           (мог купить в подарок / не для бега); active — подтверждены, считаем
    #           километраж; declined — пользователь отказался добавлять в трекер.
    STATUS_PENDING = "pending"
    STATUS_ACTIVE = "active"
    STATUS_DECLINED = "declined"
    STATUS_CHOICES = [
        (STATUS_PENDING, "Ожидает подтверждения"),
        (STATUS_ACTIVE, "Активные"),
        (STATUS_DECLINED, "Отклонены"),
    ]

    user_id = models.CharField(max_length=40, db_index=True, verbose_name="Пользователь (ID)")
    product_id = models.CharField(max_length=40, verbose_name="Товар (ID)")
    order_id = models.CharField(max_length=40, blank=True, default="", verbose_name="Заказ (ID)")
    model = models.CharField(max_length=200, blank=True, default="", verbose_name="Модель")
    image_url = models.CharField(max_length=400, blank=True, default="", verbose_name="Фото")
    status = models.CharField(
        max_length=12, default=STATUS_PENDING, db_index=True,
        choices=STATUS_CHOICES, verbose_name="Статус",
    )
    total_km = models.FloatField(default=0, verbose_name="Пробег, км")
    max_km = models.FloatField(default=600, verbose_name="Ресурс, км")
    retired = models.BooleanField(default=False, verbose_name="Списаны")
    # runId уже учтённых пробежек — идемпотентность distance (офлайн-очередь
    # Квартала может переслать одну пробежку повторно; повтор не задвоит км).
    applied_runs = models.JSONField(default=list, verbose_name="Учтённые забеги")
    created_at = models.DateTimeField(default=timezone.now, verbose_name="Куплены")

    class Meta:
        db_table = "store_shoes"
        ordering = ["-created_at"]
        # Идемпотентность: одна пара кроссовок из заказа не дублируется.
        unique_together = (("user_id", "order_id", "product_id"),)
        verbose_name = "Кроссовки"
        verbose_name_plural = "Кроссовки"

    def __str__(self) -> str:
        return self.model or f"shoe_{self.pk}"

    def to_json(self) -> dict:
        return {
            "id": f"shoe_{self.pk}",
            "userId": self.user_id,
            "productId": self.product_id,
            "orderId": self.order_id,
            "model": self.model,
            "imageUrl": self.image_url,
            "status": self.status,
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
