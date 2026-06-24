"""История пробежек на сервере (синхронизация с устройства).
Храним СВОДКУ забега (дистанция/время/дата/флаги захвата), НЕ сырой GPS-трек —
приватность по умолчанию (LAUNCH_READINESS §2: ограничиваем хранение сырых точек;
маршрут остаётся локально на устройстве). Даёт кросс-девайс историю, бэкап при
переустановке и фундамент под серверный анти-чит (S-04)."""
from django.db import models
from django.utils import timezone


class Run(models.Model):
    # id = клиентский runId → идемпотентность (повторная отправка из офлайн-очереди
    # не задвоит забег).
    id = models.CharField(primary_key=True, max_length=40, verbose_name="ID")
    user_id = models.CharField(max_length=40, db_index=True, verbose_name="Пользователь (ID)")
    distance_m = models.FloatField(default=0, verbose_name="Дистанция, м")
    duration_s = models.IntegerField(default=0, verbose_name="Длительность, с")
    captured_territory = models.BooleanField(default=False, verbose_name="Захват территории")
    captured_zones = models.IntegerField(default=0, verbose_name="Захвачено зон")
    finished_at = models.DateTimeField(verbose_name="Завершён")
    created_at = models.DateTimeField(default=timezone.now, verbose_name="Загружен")

    # Серверный анти-чит (S-04): очки за бег считает сервер, не клиент.
    points_awarded = models.IntegerField(default=0, verbose_name="Начислено баллов")
    flagged = models.BooleanField(default=False, db_index=True, verbose_name="Помечен (чит)")
    flag_reason = models.CharField(max_length=200, blank=True, default="", verbose_name="Причина пометки")

    class Meta:
        db_table = "runs"
        ordering = ["-finished_at"]
        verbose_name = "Пробежка"
        verbose_name_plural = "Пробежки"

    @property
    def distance_km(self) -> float:
        return self.distance_m / 1000.0

    def to_json(self) -> dict:
        return {
            "id": self.id,
            "distanceMeters": self.distance_m,
            "elapsedSeconds": self.duration_s,
            "capturedTerritory": self.captured_territory,
            "capturedZones": self.captured_zones,
            "finishedAtMs": int(self.finished_at.timestamp() * 1000),
        }
