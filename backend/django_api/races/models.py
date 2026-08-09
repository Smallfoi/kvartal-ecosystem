"""Race — беговое соревнование/старт для вкладки «Старты» в «Квартале».

Афиша забегов (марафоны/полумарафоны/трейлы/эстафеты/детские) с фильтрами и
эко-связью экосистемы (баллы за финиш, клубный зачёт — поверх этой модели).
Заводится владельцем в админке. Публичный API `GET /v1/races` (токен не нужен).
"""
from django.db import models
from django.utils import timezone


class Race(models.Model):
    TYPE_CHOICES = [
        ("road", "Шоссе"),
        ("trail", "Трейл"),
        ("night", "Ночной"),
        ("fest", "Фестиваль"),
        ("relay", "Эстафета"),
        ("kids", "Детский"),
        ("other", "Другое"),
    ]
    REG_OPEN = "open"
    REG_SOON = "soon"
    REG_CLOSED = "closed"
    REG_DONE = "done"
    REG_CHOICES = [
        (REG_OPEN, "Регистрация открыта"),
        (REG_SOON, "Скоро"),
        (REG_CLOSED, "Регистрация закрыта"),
        (REG_DONE, "Завершён"),
    ]

    SCOPE_FEDERAL = "federal"
    SCOPE_REGIONAL = "regional"
    SCOPE_LOCAL = "local"
    SCOPE_CHOICES = [
        (SCOPE_FEDERAL, "Федеральный (крупный) — показывать всем"),
        (SCOPE_REGIONAL, "Региональный — по региону клиента"),
        (SCOPE_LOCAL, "Местный — по городу клиента"),
    ]

    title = models.CharField(max_length=200, verbose_name="Название")
    city = models.CharField(max_length=120, blank=True, default="", db_index=True, verbose_name="Город")
    region = models.CharField(
        max_length=120, blank=True, default="", db_index=True,
        verbose_name="Регион", help_text="Напр. «Республика Татарстан», «Москва» — для показа по региону клиента",
    )
    scope = models.CharField(
        max_length=10, choices=SCOPE_CHOICES, default=SCOPE_REGIONAL, db_index=True,
        verbose_name="Масштаб",
        help_text="federal — большие старты, видны всем; regional/local — по региону/городу клиента",
    )
    place = models.CharField(max_length=200, blank=True, default="", verbose_name="Место старта")
    date = models.DateField(db_index=True, verbose_name="Дата старта")
    date_end = models.DateField(null=True, blank=True, verbose_name="Дата окончания (если многодневный)")
    type = models.CharField(max_length=12, choices=TYPE_CHOICES, default="road", db_index=True, verbose_name="Тип")
    # Список строк-дистанций как показываем: ["42.2 км", "21.1 км", "10 км"].
    distances = models.JSONField(default=list, blank=True, verbose_name="Дистанции")
    reg_status = models.CharField(max_length=12, choices=REG_CHOICES, default=REG_SOON, verbose_name="Регистрация")
    reg_url = models.URLField(blank=True, default="", verbose_name="Ссылка на регистрацию")
    description = models.TextField(blank=True, default="", verbose_name="Описание")
    cover = models.ImageField(upload_to="races/", blank=True, null=True, verbose_name="Обложка (необязательно)")
    lat = models.FloatField(null=True, blank=True, verbose_name="Широта старта")
    lng = models.FloatField(null=True, blank=True, verbose_name="Долгота старта")
    points = models.IntegerField(default=0, verbose_name="Баллы за финиш")
    is_published = models.BooleanField(default=True, db_index=True, verbose_name="Опубликован")
    # Источник данных: "manual" (завёл владелец) или код парсера ("runc"/"getrun"/…).
    # external_id + source — ключ дедупликации при повторном авто-импорте (upsert).
    source = models.CharField(max_length=40, blank=True, default="manual", db_index=True, verbose_name="Источник")
    source_url = models.URLField(blank=True, default="", verbose_name="Ссылка на источник")
    external_id = models.CharField(max_length=120, blank=True, default="", db_index=True, verbose_name="ID в источнике")
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "races"
        ordering = ["date", "id"]
        constraints = [
            models.UniqueConstraint(
                fields=["source", "external_id"],
                condition=models.Q(external_id__gt=""),
                name="uniq_race_source_external",
            )
        ]
        verbose_name = "Забег (старт)"
        verbose_name_plural = "Забеги (старты)"

    def __str__(self) -> str:
        return f"{self.title} · {self.date}"

    def effective_status(self) -> str:
        """Автоматически «завершён», если событие уже прошло (по дате окончания)."""
        end = self.date_end or self.date
        if end < timezone.localdate():
            return self.REG_DONE
        return self.reg_status

    def to_json(self) -> dict:
        cover_url = ""
        if self.cover:
            try:
                cover_url = self.cover.url
            except ValueError:
                cover_url = ""
        return {
            "id": self.pk,
            "title": self.title,
            "city": self.city,
            "region": self.region,
            "scope": self.scope,
            "place": self.place,
            "date": self.date.isoformat(),
            "dateEnd": self.date_end.isoformat() if self.date_end else None,
            "type": self.type,
            "typeLabel": self.get_type_display(),
            "distances": self.distances or [],
            "regStatus": self.effective_status(),
            "regUrl": self.reg_url,
            "description": self.description,
            "coverUrl": cover_url,
            "lat": self.lat,
            "lng": self.lng,
            "points": self.points,
        }
