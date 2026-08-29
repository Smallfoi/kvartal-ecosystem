"""Профиль бегуна — основа «своей лиги» (docs/LEAGUE_PLAN.md, Э1)."""
import django.utils.timezone
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = []

    operations = [
        migrations.CreateModel(
            name="RunnerProfile",
            fields=[
                (
                    "user_id",
                    models.CharField(
                        max_length=40,
                        primary_key=True,
                        serialize=False,
                        verbose_name="Пользователь (ID)",
                    ),
                ),
                ("birth_year", models.IntegerField(blank=True, null=True, verbose_name="Год рождения")),
                (
                    "gender",
                    models.CharField(
                        blank=True,
                        choices=[("m", "Мужской"), ("f", "Женский")],
                        default="",
                        max_length=1,
                        verbose_name="Пол",
                    ),
                ),
                (
                    "level",
                    models.CharField(
                        blank=True,
                        choices=[
                            ("novice", "Новичок"),
                            ("amateur", "Любитель"),
                            ("advanced", "Опытный"),
                        ],
                        default="",
                        max_length=12,
                        verbose_name="Уровень",
                    ),
                ),
                (
                    "weekly_goal_km",
                    models.FloatField(blank=True, null=True, verbose_name="Цель на неделю, км"),
                ),
                (
                    "updated_at",
                    models.DateTimeField(default=django.utils.timezone.now, verbose_name="Обновлён"),
                ),
            ],
            options={
                "verbose_name": "Профиль бегуна",
                "verbose_name_plural": "Профили бегунов",
                "db_table": "runner_profile",
            },
        ),
    ]
