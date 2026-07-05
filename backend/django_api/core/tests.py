"""Авто-удаление данных по срокам хранения (152-ФЗ §2)."""
from datetime import timedelta

from django.core.management import call_command
from django.test import TestCase, override_settings
from django.utils import timezone


@override_settings(ANALYTICS_EVENT_RETENTION_DAYS=365, READ_NOTIFICATION_RETENTION_DAYS=90)
class OldDataCleanupTests(TestCase):
    """cleanup_old_data удаляет старые события + старые ПРОЧИТАННЫЕ уведомления,
    свежее и непрочитанное — оставляет. История (лояльность/заказы) не трогается."""

    def _age(self, model, pk, days):
        model.objects.filter(pk=pk).update(created_at=timezone.now() - timedelta(days=days))

    def test_purges_old_events_and_read_notifications(self):
        from analytics.models import Event
        from notifications.models import Notification, create_notification

        old_ev = Event.objects.create(name="old", user_id="u1")
        self._age(Event, old_ev.pk, 400)
        Event.objects.create(name="fresh", user_id="u1")  # свежее — остаётся

        read_old = create_notification("u1", "read old")
        read_old.read = True
        read_old.save(update_fields=["read"])
        self._age(Notification, read_old.pk, 120)
        unread_old = create_notification("u1", "unread old")  # непрочитанное — остаётся
        self._age(Notification, unread_old.pk, 120)

        call_command("cleanup_old_data")

        self.assertFalse(Event.objects.filter(name="old").exists())
        self.assertTrue(Event.objects.filter(name="fresh").exists())
        self.assertFalse(Notification.objects.filter(pk=read_old.pk).exists())
        self.assertTrue(Notification.objects.filter(pk=unread_old.pk).exists())

    @override_settings(ANALYTICS_EVENT_RETENTION_DAYS=0)
    def test_zero_retention_disables_event_cleanup(self):
        from analytics.models import Event

        old_ev = Event.objects.create(name="keep", user_id="u1")
        self._age(Event, old_ev.pk, 9999)
        call_command("cleanup_old_data")
        self.assertTrue(Event.objects.filter(name="keep").exists())  # 0 = не удалять


@override_settings(CELERY_TASK_ALWAYS_EAGER=True, CELERY_TASK_EAGER_PROPAGATES=True,
                   ANALYTICS_EVENT_RETENTION_DAYS=365)
class CleanupTaskTests(TestCase):
    """Beat-обёртка core.cleanup_old_data вызывает команду (EAGER → синхронно)."""

    def test_task_runs_command(self):
        from analytics.models import Event
        from core.tasks import cleanup_old_data

        e = Event.objects.create(name="old", user_id="u1")
        Event.objects.filter(pk=e.pk).update(created_at=timezone.now() - timedelta(days=400))
        cleanup_old_data.delay()
        self.assertFalse(Event.objects.filter(name="old").exists())
