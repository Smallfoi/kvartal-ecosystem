"""Удаление треков, которые больше не нужны (D-60).

Трек живёт ровно столько, сколько нужно, чтобы разобрать спор о накрутке.
Дальше он — просто карта передвижений человека, и хранить её мы не будем.
"""
from datetime import timedelta

from celery import shared_task
from django.utils import timezone

from trails.models import PendingTrack

TRACK_RETENTION_DAYS = 14


@shared_task(name="trails.cleanup_tracks", ignore_result=True)
def cleanup_tracks():
    edge = timezone.now() - timedelta(days=TRACK_RETENTION_DAYS)
    removed, _ = PendingTrack.objects.filter(received_at__lt=edge).delete()
    if removed:
        print(f"Тропы: удалено треков старше {TRACK_RETENTION_DAYS} дней — {removed}.")
    return removed
