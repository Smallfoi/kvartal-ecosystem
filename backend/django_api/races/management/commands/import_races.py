"""import_races — ручной запуск авто-парсера афиши «Стартов».

    docker compose exec web python manage.py import_races
    docker compose exec web python manage.py import_races --source parser-demo
    docker compose exec web python manage.py import_races --dry-run

Идемпотентно (upsert по source+external_id). См. races/services.run_import и
races/importers/. Периодически то же делает Celery-задача races.import_races (beat).
"""
from django.core.management.base import BaseCommand

from races.services import run_import


class Command(BaseCommand):
    help = "Импортировать забеги из внешних источников (идемпотентно)."

    def add_arguments(self, parser):
        parser.add_argument("--source", action="append", dest="sources",
                            help="Код источника (можно несколько). Без него — все.")
        parser.add_argument("--dry-run", action="store_true",
                            help="Не писать в БД, только показать, что нашлось.")

    def handle(self, *args, **opts):
        stats = run_import(sources=opts.get("sources"), dry_run=opts.get("dry_run", False))
        by_src = ", ".join(
            f"{src}: +{s['created']}/~{s['updated']}/skip {s['skipped']}/err {s['errors']}"
            for src, s in stats.get("sources", {}).items()
        )
        self.stdout.write(self.style.SUCCESS(
            f"import_races: создано {stats['created']}, обновлено {stats['updated']}, "
            f"пропущено {stats['skipped']}, ошибок {stats['errors']}. [{by_src}]"
        ))
