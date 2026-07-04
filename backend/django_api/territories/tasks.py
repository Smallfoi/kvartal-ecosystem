"""Фоновые задачи территорий (D-07). Периодическая чистка протухших зон/защит —
по расписанию beat (см. CELERY_BEAT_SCHEDULE), а не только ручной management-командой."""
from celery import shared_task
from django.core.management import call_command


@shared_task(name="territories.cleanup_expired_territories", ignore_result=True)
def cleanup_expired_territories():
    """Удалить протухшие территории (>7д) и истёкшие защиты захвата (>24ч).
    Обёртка над командой cleanup_territories — единая логика, вызывается и из beat, и вручную."""
    call_command("cleanup_territories")
