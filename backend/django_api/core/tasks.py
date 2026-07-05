"""Фоновые задачи ядра (D-07). Авто-удаление данных по срокам хранения (152-ФЗ §2) —
по расписанию beat (см. CELERY_BEAT_SCHEDULE)."""
from celery import shared_task
from django.core.management import call_command


@shared_task(name="core.cleanup_old_data", ignore_result=True)
def cleanup_old_data():
    """Обёртка над командой cleanup_old_data — единая логика для beat и ручного запуска."""
    call_command("cleanup_old_data")
