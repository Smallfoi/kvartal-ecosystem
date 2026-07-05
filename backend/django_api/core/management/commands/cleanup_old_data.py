"""Авто-удаление данных по срокам хранения (152-ФЗ §2, LR §2 «данные без цели»).

Удаляет:
  • события аналитики старше ANALYTICS_EVENT_RETENTION_DAYS (по умолчанию 365 дн.);
  • ПРОЧИТАННЫЕ уведомления старше READ_NOTIFICATION_RETENTION_DAYS (по умолчанию 90 дн.).
Лояльность/заказы/забеги/кроссовки НЕ трогаем — это история и финансы (нужны). Сырой GPS
на бэке не хранится (приватность §2). Каждый срок = 0 отключает соответствующую чистку.

Запуск:  python manage.py cleanup_old_data   (в проде — из Celery beat ежедневно, D-07)
"""
from datetime import timedelta

from django.conf import settings
from django.core.management.base import BaseCommand
from django.utils import timezone


class Command(BaseCommand):
    help = "Удаляет данные без цели по срокам хранения (старые события + прочитанные уведомления)."

    def handle(self, *args, **options):
        from analytics.models import Event
        from notifications.models import Notification

        now = timezone.now()
        ev_days = int(getattr(settings, "ANALYTICS_EVENT_RETENTION_DAYS", 365) or 0)
        nt_days = int(getattr(settings, "READ_NOTIFICATION_RETENTION_DAYS", 90) or 0)

        ev = 0
        if ev_days > 0:
            ev = Event.objects.filter(
                created_at__lt=now - timedelta(days=ev_days)
            ).delete()[0]
        nt = 0
        if nt_days > 0:
            nt = Notification.objects.filter(
                read=True, created_at__lt=now - timedelta(days=nt_days)
            ).delete()[0]

        self.stdout.write(self.style.SUCCESS(
            f"Чистка по срокам хранения: событий {ev}, прочитанных уведомлений {nt}."
        ))
