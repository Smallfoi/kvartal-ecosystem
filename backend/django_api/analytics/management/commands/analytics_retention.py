"""Печать недельного ретеншна по когортам регистрации (D-30).

Запуск:  python manage.py analytics_retention [--weeks 8]
Строка = когорта: дата недели, размер, и % активных по неделям (week-0 = регистрация).
"""
from django.core.management.base import BaseCommand

from analytics.retention import weekly_cohorts


class Command(BaseCommand):
    help = "Недельный ретеншн по когортам регистрации (когорта × активные по неделям)."

    def add_arguments(self, parser):
        parser.add_argument("--weeks", type=int, default=8, help="сколько когорт (недель) назад")

    def handle(self, *args, **options):
        cohorts = weekly_cohorts(options["weeks"])
        if not any(c["size"] for c in cohorts):
            self.stdout.write("Нет данных за период (нет регистраций).")
            return
        self.stdout.write("Когорта     n     ретеншн по неделям (week-0 = регистрация)")
        for c in cohorts:
            cells = "  ".join(f"{r['pct']:>5.1f}%" for r in c["retention"])
            self.stdout.write(f"{c['cohortWeek']}  {c['size']:<4}  {cells}")
