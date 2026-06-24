"""Чистка осиротевших данных — строк, чей user_id/owner_id больше не имеет Account.

Появляются, если аккаунт удалили в обход delete_account (например, прямым
`Account.objects.delete()` в shell при чистке тестов) — тогда баллы/забеги
повисают и, например, засоряют лидерборд. Штатное удаление (delete_account)
теперь чистит всё, включая runs; эта команда добивает исторический мусор.

  python manage.py clean_orphans          # dry-run: только показать
  python manage.py clean_orphans --apply  # реально удалить
"""
from django.core.management.base import BaseCommand
from django.db import connection


class Command(BaseCommand):
    help = "Удаляет осиротевшие данные (user_id/owner_id без Account)."

    def add_arguments(self, parser):
        parser.add_argument(
            "--apply", action="store_true",
            help="реально удалить (по умолчанию — только показать, dry-run)",
        )

    def handle(self, *args, **opts):
        from accounts.models import Account
        from clubs.models import ClubJoinRequest, ClubMember
        from legal.models import UserConsent
        from loyalty.models import LoyaltyTransaction
        from notifications.models import Notification
        from orders.models import Order
        from runs.models import Run
        from shoes.models import ShoeAsset

        apply = opts["apply"]
        valid = set(Account.objects.values_list("id", flat=True))
        report = {}

        def sweep(label, manager):
            orphans = manager.exclude(user_id__in=valid)
            n = orphans.count()
            if n and apply:
                orphans.delete()
            report[label] = n

        sweep("loyalty", LoyaltyTransaction.objects)
        sweep("orders", Order.objects)
        sweep("runs", Run.objects)
        sweep("shoes", ShoeAsset.objects)
        sweep("notifications", Notification.objects)
        sweep("consents", UserConsent.objects)
        sweep("clubMemberships", ClubMember.objects)
        sweep("clubRequests", ClubJoinRequest.objects)

        # Гео (PostGIS, raw SQL): owner_id без аккаунта.
        with connection.cursor() as cur:
            for tbl in ("territories", "footprints"):
                cur.execute(
                    f"SELECT count(*) FROM {tbl} "
                    "WHERE owner_id NOT IN (SELECT id FROM accounts)"
                )
                n = cur.fetchone()[0]
                if n and apply:
                    cur.execute(
                        f"DELETE FROM {tbl} "
                        "WHERE owner_id NOT IN (SELECT id FROM accounts)"
                    )
                report[tbl] = n

        total = sum(report.values())
        mode = "УДАЛЕНО" if apply else "НАЙДЕНО (dry-run; для удаления --apply)"
        self.stdout.write(self.style.WARNING(f"Осиротевшие данные [{mode}]: всего {total}"))
        for k, v in report.items():
            if v:
                self.stdout.write(f"  {k}: {v}")
        if total == 0:
            self.stdout.write(self.style.SUCCESS("Мусора нет — всё чисто."))
