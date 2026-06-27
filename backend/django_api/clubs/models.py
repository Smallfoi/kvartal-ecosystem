from django.db import models
from django.utils import timezone


class Club(models.Model):
    JOIN_CHOICES = [("open", "Открытый"), ("request", "По заявке")]

    id = models.CharField(primary_key=True, max_length=40, verbose_name="ID")
    name = models.CharField(max_length=200, verbose_name="Название")
    logo = models.CharField(max_length=200, null=True, blank=True, verbose_name="Логотип")
    city = models.CharField(max_length=120, null=True, blank=True, verbose_name="Город")
    description = models.TextField(null=True, blank=True, verbose_name="Описание")
    owner_id = models.CharField(max_length=40, verbose_name="Владелец (ID)")
    join_policy = models.CharField(
        max_length=20, default="open", choices=JOIN_CHOICES, verbose_name="Приём в клуб"
    )
    # Пресет оформления клуба (акцент-цвет + анимированный фон шапки + рамка лого).
    style = models.CharField(
        max_length=20, default="minimal", verbose_name="Стиль оформления"
    )
    created_at = models.DateTimeField(default=timezone.now, verbose_name="Создан")
    # Модерация (S-10): скрытый клуб не виден в списке и в него нельзя вступить.
    is_hidden = models.BooleanField(default=False, db_index=True, verbose_name="Скрыт (модерация)")

    class Meta:
        db_table = "clubs"
        verbose_name = "Клуб"
        verbose_name_plural = "Клубы"

    def __str__(self) -> str:
        return self.name


class ClubMember(models.Model):
    ROLE_CHOICES = [("owner", "Владелец"), ("member", "Участник")]

    club_id = models.CharField(max_length=40, db_index=True, verbose_name="Клуб (ID)")
    # уникальность user_id = один клуб на человека (как в FastAPI на уровне БД)
    user_id = models.CharField(max_length=40, unique=True, verbose_name="Пользователь (ID)")
    role = models.CharField(
        max_length=20, default="member", choices=ROLE_CHOICES, verbose_name="Роль"
    )
    joined_at = models.DateTimeField(default=timezone.now, verbose_name="Вступил")

    class Meta:
        db_table = "club_members"
        unique_together = (("club_id", "user_id"),)
        verbose_name = "Участник клуба"
        verbose_name_plural = "Участники клубов"


class ClubJoinRequest(models.Model):
    STATUS_CHOICES = [
        ("pending", "Ожидает"), ("approved", "Одобрена"), ("rejected", "Отклонена"),
    ]

    id = models.CharField(primary_key=True, max_length=40, verbose_name="ID")
    club_id = models.CharField(max_length=40, db_index=True, verbose_name="Клуб (ID)")
    user_id = models.CharField(max_length=40, verbose_name="Пользователь (ID)")
    status = models.CharField(
        max_length=20, default="pending", choices=STATUS_CHOICES, verbose_name="Статус"
    )
    created_at = models.DateTimeField(default=timezone.now, verbose_name="Создана")

    class Meta:
        db_table = "club_join_requests"
        verbose_name = "Заявка в клуб"
        verbose_name_plural = "Заявки в клуб"
