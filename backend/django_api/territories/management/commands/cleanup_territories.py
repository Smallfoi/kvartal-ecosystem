"""Плановая чистка территорий (доводка Квартала).

Живой слой и защита захвата чистятся лениво при каждом захвате, но без активности
таблицы пухнут. Эта команда — для cron/Celery beat: безопасно удаляет
  • протухший живой слой `territories` (captured_at старше HOLD_HOURS = 7 дней);
  • истёкшую защиту `recent_captures` (старше PROTECT_HOURS = 24 ч).
`footprints` (вечный след) и `processed_captures` (идемпотентность, без времени) НЕ трогаем.

Запуск:  python manage.py cleanup_territories
"""
from django.core.management.base import BaseCommand
from django.db import connection

from territories.views import HOLD_HOURS, PROTECT_HOURS


class Command(BaseCommand):
    help = "Удаляет протухший живой слой территорий и истёкшую защиту захвата."

    def handle(self, *args, **options):
        with connection.cursor() as cur:
            cur.execute(
                "DELETE FROM territories "
                "WHERE captured_at <= now() - make_interval(hours => %s)",
                [HOLD_HOURS],
            )
            terr = cur.rowcount
            cur.execute(
                "DELETE FROM recent_captures "
                "WHERE captured_at <= now() - make_interval(hours => %s)",
                [PROTECT_HOURS],
            )
            rec = cur.rowcount
        self.stdout.write(self.style.SUCCESS(
            f"Чистка территорий: удалено протухших зон {terr}, "
            f"истёкших защит захвата {rec}."
        ))
