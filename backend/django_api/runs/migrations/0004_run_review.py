"""Разбор помеченных забегов человеком (S-04, фаза 2).

Раньше «уже смотрели» помечалось припиской ` [проверено]` прямо в тексте причины —
хрупко (обрезка по 200 символам, поиск подстрокой) и не видно, кто и когда решил.
Переносим это в отдельные поля и чистим старые приписки.
"""
from django.db import migrations, models
from django.utils import timezone


def move_reviewed_marker(apps, schema_editor):
    Run = apps.get_model("runs", "Run")
    now = timezone.now()
    for run in Run.objects.filter(flag_reason__contains="[проверено]"):
        run.flag_reason = run.flag_reason.replace("[проверено]", "").strip()
        run.reviewed_at = now
        run.reviewed_by = "перенос из старой пометки"
        run.save(update_fields=["flag_reason", "reviewed_at", "reviewed_by"])


def back(apps, schema_editor):
    """Обратно — приписка в причине, чтобы старый код снова видел «проверено»."""
    Run = apps.get_model("runs", "Run")
    for run in Run.objects.filter(reviewed_at__isnull=False):
        if "[проверено]" not in run.flag_reason:
            run.flag_reason = (run.flag_reason + " [проверено]").strip()[:200]
            run.save(update_fields=["flag_reason"])


class Migration(migrations.Migration):

    dependencies = [
        ("runs", "0003_alter_run_options_alter_run_captured_territory_and_more"),
    ]

    operations = [
        migrations.AddField(
            model_name="run",
            name="reviewed_at",
            field=models.DateTimeField(blank=True, null=True, verbose_name="Разобран"),
        ),
        migrations.AddField(
            model_name="run",
            name="reviewed_by",
            field=models.CharField(blank=True, default="", max_length=150,
                                   verbose_name="Кто разобрал"),
        ),
        migrations.RunPython(move_reviewed_marker, back),
    ]
