"""Уведомления экосистемы (ECOSYSTEM_API §2.6): единая лента для всех приложений.
Создаются на сервере (статус заказа, заявки в клуб и т.п.). FCM-пуш — поверх позже."""
from django.db import models
from django.utils import timezone


class Notification(models.Model):
    TYPE_CHOICES = [
        ("system", "Системное"),
        ("order", "Заказ"),
        ("promo", "Акция"),
    ]

    user_id = models.CharField(max_length=40, db_index=True, verbose_name="Пользователь (ID)")
    title = models.CharField(max_length=200, verbose_name="Заголовок")
    body = models.CharField(max_length=500, blank=True, default="", verbose_name="Текст")
    type = models.CharField(
        max_length=20, default="system", choices=TYPE_CHOICES, verbose_name="Тип"
    )
    order_id = models.CharField(max_length=40, null=True, blank=True, verbose_name="Заказ (ID)")
    read = models.BooleanField(default=False, verbose_name="Прочитано")
    created_at = models.DateTimeField(default=timezone.now, verbose_name="Создано")

    class Meta:
        db_table = "notifications"
        ordering = ["-created_at"]
        verbose_name = "Уведомление"
        verbose_name_plural = "Уведомления"

    def __str__(self) -> str:
        return self.title

    def to_json(self) -> dict:
        return {
            "id": str(self.pk),
            "userId": self.user_id,
            "title": self.title,
            "body": self.body,
            "type": self.type,
            "orderId": self.order_id,
            "read": self.read,
            "createdAt": self.created_at.isoformat(),
        }


def create_notification(user_id, title, body="", type="system", order_id=None):
    """Создать уведомление пользователю. Безопасно (без user_id — ничего не делает)."""
    if not user_id:
        return None
    return Notification.objects.create(
        user_id=user_id, title=title, body=body, type=type, order_id=order_id,
    )
