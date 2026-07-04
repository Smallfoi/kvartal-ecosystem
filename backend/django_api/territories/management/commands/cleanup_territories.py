"""Плановая чистка территорий (доводка Квартала).

Живой слой и защита захвата чистятся лениво при каждом захвате, но без активности
таблицы пухнут. Эта команда — для cron/Celery beat: безопасно удаляет
  • протухший живой слой `territories` (captured_at старше HOLD_HOURS = 7 дней);
  • истёкшую защиту `recent_captures` (старше PROTECT_HOURS = 24 ч);
  • старые записи идемпотентности `processed_captures` (created_at старше
    PROCESSED_RETENTION_HOURS = 30 дней — переотправки офлайн-очереди так долго не живут).
`footprints` (вечный след) НЕ трогаем — это по определению вечная история.

Запуск:  python manage.py cleanup_territories
"""
from django.core.management.base import BaseCommand
from django.db import connection

from territories.views import HOLD_HOURS, PROCESSED_RETENTION_HOURS, PROTECT_HOURS


class Command(BaseCommand):
    help = "Удаляет протухший живой слой территорий, истёкшую защиту и старую идемпотентность."

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
            cur.execute(
                "DELETE FROM processed_captures "
                "WHERE created_at <= now() - make_interval(hours => %s)",
                [PROCESSED_RETENTION_HOURS],
            )
            proc = cur.rowcount
        self.stdout.write(self.style.SUCCESS(
            f"Чистка территорий: удалено протухших зон {terr}, "
            f"истёкших защит захвата {rec}, старых идемпотент-записей {proc}."
        ))
