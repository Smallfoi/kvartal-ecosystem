"""Профиль бегуна — то, чего не хватает аккаунту для «своей лиги».

Отдельная таблица, а не поля в `accounts`: контракт аккаунта используют все три
продукта экосистемы, и трогать его ради беговых полей нельзя.

Все поля необязательные — и это принципиально. Спрашивать возраст и пол на входе
нельзя: часть людей просто закроет приложение. Не указал — попадаешь в общий
зачёт, «своя лига» тебе не показывается, всё остальное работает.

Год рождения, а не дата: для возрастной группы дата не нужна, а хранить меньше
персональных данных — лучше.
"""
from django.db import models
from django.utils import timezone


class RunnerProfile(models.Model):
    GENDER_CHOICES = [("m", "Мужской"), ("f", "Женский")]
    LEVEL_CHOICES = [
        ("novice", "Новичок"),
        ("amateur", "Любитель"),
        ("advanced", "Опытный"),
    ]

    user_id = models.CharField(primary_key=True, max_length=40, verbose_name="Пользователь (ID)")
    birth_year = models.IntegerField(null=True, blank=True, verbose_name="Год рождения")
    gender = models.CharField(
        max_length=1, blank=True, default="", choices=GENDER_CHOICES, verbose_name="Пол"
    )
    level = models.CharField(
        max_length=12, blank=True, default="", choices=LEVEL_CHOICES, verbose_name="Уровень"
    )
    weekly_goal_km = models.FloatField(null=True, blank=True, verbose_name="Цель на неделю, км")
    # Участие в тропах: выключено — трек забега не уходит на сервер вовсе (D-60).
    # По умолчанию включено, иначе функция мертва; выключатель виден в настройках.
    trails_enabled = models.BooleanField(default=True, verbose_name="Участвовать в тропах")
    updated_at = models.DateTimeField(default=timezone.now, verbose_name="Обновлён")

    class Meta:
        db_table = "runner_profile"
        verbose_name = "Профиль бегуна"
        verbose_name_plural = "Профили бегунов"

    def to_json(self) -> dict:
        return {
            "birthYear": self.birth_year,
            "gender": self.gender or None,
            "level": self.level or None,
            "weeklyGoalKm": self.weekly_goal_km,
            "trailsEnabled": self.trails_enabled,
        }
