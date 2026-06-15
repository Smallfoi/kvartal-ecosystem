"""
Одноразовый импорт данных из SQLite (FastAPI ecosystem.db) в Postgres (Django).
Идемпотентно (по PK). Запуск:
  docker compose cp ecosystem.db web:/tmp/ecosystem.db
  docker compose exec web python manage.py import_sqlite --path /tmp/ecosystem.db
"""
import sqlite3
from datetime import datetime

from django.core.management.base import BaseCommand
from django.utils import timezone

from accounts.models import Account
from clubs.models import Club, ClubJoinRequest, ClubMember
from loyalty.models import LoyaltyTransaction


def _dt(s):
    if not s:
        return timezone.now()
    try:
        return datetime.fromisoformat(s)
    except Exception:
        return timezone.now()


class Command(BaseCommand):
    help = "Импорт данных из SQLite (FastAPI) в Postgres"

    def add_arguments(self, parser):
        parser.add_argument("--path", default="/tmp/ecosystem.db")

    def handle(self, *args, **opts):
        con = sqlite3.connect(opts["path"])
        con.row_factory = sqlite3.Row
        counts = {"users": 0, "loyalty": 0, "clubs": 0, "members": 0, "requests": 0}

        for r in con.execute("SELECT * FROM users"):
            if Account.objects.filter(id=r["id"]).exists():
                continue
            cols = r.keys()
            Account.objects.create(
                id=r["id"], name=r["name"] or "", email=r["email"], phone=r["phone"],
                provider=r["provider"] or "email", avatar_path=r["avatar_path"],
                city=(r["city"] if "city" in cols else None),
                password_hash=r["password_hash"],
            )
            counts["users"] += 1

        for r in con.execute("SELECT * FROM loyalty_transactions"):
            if LoyaltyTransaction.objects.filter(id=r["id"]).exists():
                continue
            LoyaltyTransaction.objects.create(
                id=r["id"], user_id=r["user_id"], amount=r["amount"], source=r["source"],
                description=r["description"] or "", order_id=r["order_id"],
                run_id=r["run_id"], created_at=_dt(r["created_at"]),
            )
            counts["loyalty"] += 1

        for r in con.execute("SELECT * FROM clubs"):
            if Club.objects.filter(id=r["id"]).exists():
                continue
            Club.objects.create(
                id=r["id"], name=r["name"], logo=r["logo"], city=r["city"],
                description=r["description"], owner_id=r["owner_id"],
                join_policy=r["join_policy"] or "open", created_at=_dt(r["created_at"]),
            )
            counts["clubs"] += 1

        for r in con.execute("SELECT * FROM club_members"):
            if ClubMember.objects.filter(user_id=r["user_id"]).exists():
                continue  # один клуб на человека
            ClubMember.objects.create(
                club_id=r["club_id"], user_id=r["user_id"], role=r["role"] or "member",
                joined_at=_dt(r["joined_at"]),
            )
            counts["members"] += 1

        for r in con.execute("SELECT * FROM club_join_requests"):
            if ClubJoinRequest.objects.filter(id=r["id"]).exists():
                continue
            ClubJoinRequest.objects.create(
                id=r["id"], club_id=r["club_id"], user_id=r["user_id"],
                status=r["status"] or "pending", created_at=_dt(r["created_at"]),
            )
            counts["requests"] += 1

        con.close()
        self.stdout.write(self.style.SUCCESS(f"Импортировано: {counts}"))
