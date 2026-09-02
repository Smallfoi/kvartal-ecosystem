from django.db import migrations, models
import django.utils.timezone


class Migration(migrations.Migration):
    initial = True
    dependencies = []

    operations = [
        migrations.CreateModel(
            name="MedalAward",
            fields=[
                ("id", models.CharField(max_length=40, primary_key=True, serialize=False, verbose_name="ID")),
                ("user_id", models.CharField(db_index=True, max_length=40, verbose_name="Пользователь (ID)")),
                ("medal_id", models.CharField(max_length=40, verbose_name="Медаль")),
                ("earned_at", models.DateTimeField(default=django.utils.timezone.now, verbose_name="Получена")),
                ("v", models.CharField(blank=True, default="", max_length=24, verbose_name="Значение")),
                ("u", models.CharField(blank=True, default="", max_length=32, verbose_name="Подпись")),
                ("sub", models.CharField(blank=True, default="", max_length=48, verbose_name="Дуга (дата)")),
            ],
            options={
                "db_table": "medal_awards",
                "verbose_name": "Медаль (выдача)",
                "verbose_name_plural": "Медали (выдачи)",
                "unique_together": {("user_id", "medal_id")},
            },
        ),
    ]
