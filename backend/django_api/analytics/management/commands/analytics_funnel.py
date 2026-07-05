"""Воронка активации + активные пользователи + топ событий (D-30 фаза 2).

Запуск:  python manage.py analytics_funnel [--days 30]
Считается по потоку событий (накапливается с внедрения аналитики).
"""
from django.core.management.base import BaseCommand

from analytics.funnel import active_users, event_counts, funnel


class Command(BaseCommand):
    help = "Воронка активации (регистрация→забег→покупка), активные, топ событий."

    def add_arguments(self, parser):
        parser.add_argument("--days", type=int, default=30, help="окно в днях (по умолчанию 30)")

    def handle(self, *args, **options):
        days = options["days"]
        rows = funnel(days=days)
        self.stdout.write(f"=== Воронка активации за {days} дн. ===")
        if not rows or not rows[0]["users"]:
            self.stdout.write("  Нет данных (события ещё не накопились).")
        else:
            for r in rows:
                self.stdout.write(
                    f"  {r['label']:<16} {r['users']:>6}  "
                    f"({r['pctOfFirst']:>5.1f}% от старта, {r['pctOfPrev']:>5.1f}% от пред.)"
                )
        self.stdout.write(f"=== Активные пользователи (7 дн.): {active_users(7)} ===")
        top = event_counts(days)[:10]
        self.stdout.write(f"=== Топ событий за {days} дн. ===")
        for e in top:
            self.stdout.write(f"  {e['event']:<24} {e['count']:>7}")
        if not top:
            self.stdout.write("  (событий нет)")
