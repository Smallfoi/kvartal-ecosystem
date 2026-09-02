"""Награды «Штамп МАТА» (D-64, дизайн docs/design/medals/).

Медаль присваивается ЛЕНИВО и НАВСЕГДА: первый GET /v1/me/medals, при котором
критерий выполнен, записывает строку с гравировкой реверса (значение/подпись/
дата) — цифры фиксируются на момент получения, как на настоящей чеканке.
Каталог (названия, критерии, ранги) живёт в medals/catalog.py и в клиенте;
сервер хранит только факт выдачи.
"""
import secrets

from django.db import models
from django.utils import timezone


class MedalAward(models.Model):
    id = models.CharField(primary_key=True, max_length=40, verbose_name="ID")
    user_id = models.CharField(max_length=40, db_index=True, verbose_name="Пользователь (ID)")
    medal_id = models.CharField(max_length=40, verbose_name="Медаль")
    earned_at = models.DateTimeField(default=timezone.now, verbose_name="Получена")

    # Личная гравировка реверса — фиксируется при выдаче (медали именные).
    v = models.CharField(max_length=24, blank=True, default="", verbose_name="Значение")
    u = models.CharField(max_length=32, blank=True, default="", verbose_name="Подпись")
    sub = models.CharField(max_length=48, blank=True, default="", verbose_name="Дуга (дата)")

    class Meta:
        db_table = "medal_awards"
        unique_together = [("user_id", "medal_id")]
        verbose_name = "Медаль (выдача)"
        verbose_name_plural = "Медали (выдачи)"

    @staticmethod
    def new_id() -> str:
        return f"ma_{secrets.token_hex(8)}"
