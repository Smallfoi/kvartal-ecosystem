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
    # Оплата (каркас, D-13): none — не требуется/dev, pending — ждёт оплаты, paid — оплачен.
    payment_status = models.CharField(max_length=20, default="none", verbose_name="Оплата")
    # db_index: по этому полю ищет вебхук на каждом уведомлении провайдера.
    payment_id = models.CharField(
        max_length=80, blank=True, default="", db_index=True, verbose_name="ID платежа"
    )
    payload = models.JSONField(default=dict, verbose_name="Данные заказа (JSON)")
    created_at = models.DateTimeField(default=timezone.now, verbose_name="Создан")

    # ── Обратный поток «заказ → 1С» (D-62). 1С забирает заказы сама и подтверждает
    # приём: свой сервер 1С обычно за NAT, достучаться до него мы не можем, а без
    # подтверждения потерянная передача означала бы потерянный заказ.
    onec_taken_at = models.DateTimeField(null=True, blank=True, db_index=True,
                                         verbose_name="Забран в 1С")
    onec_number = models.CharField(max_length=64, blank=True, default="",
                                   verbose_name="Номер документа в 1С")
    # Этапы 1С: «принят» и «собран» пары в нашем `status` не имеют — это кухня
    # склада, её показываем отдельной строкой.
    ONEC_STATUS_CHOICES = [
        ("accepted", "Принят в 1С"),
        ("assembled", "Собран"),
        ("shipped", "Отгружен"),
        ("delivered", "Доставлен"),
        ("canceled", "Отменён"),
        ("cancelled", "Отменён"),
    ]
    onec_status = models.CharField(max_length=20, blank=True, default="",
                                   choices=ONEC_STATUS_CHOICES,
                                   verbose_name="Статус в 1С")
    onec_status_at = models.DateTimeField(null=True, blank=True,
                                          verbose_name="Статус обновлён")

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
