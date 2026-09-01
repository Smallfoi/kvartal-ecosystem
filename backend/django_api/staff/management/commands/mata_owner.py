"""Закреплённый владелец: посмотреть, сменить, починить (S-13).

    python manage.py mata_owner                # кто сейчас закреплён
    python manage.py mata_owner --set 1        # закрепить запись с этим id
    python manage.py mata_owner --repair       # снять чужие флаги, вернуть свои

Единственный способ сменить владельца — эта команда на сервере. Из админки
закрепление не меняется намеренно: иначе «единственный владелец» переписывался
бы там же, где его и защищают.
"""
from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError

from staff.models import OwnerPin
from staff.owner import enforce, owner_id


class Command(BaseCommand):
    help = "Показывает или меняет закреплённого владельца (суперпользователя)."

    def add_arguments(self, parser):
        parser.add_argument("--set", type=int, dest="set_id",
                            help="id учётной записи, которую закрепить владельцем")
        parser.add_argument("--repair", action="store_true",
                            help="привести систему к правилу: суперпользователь только владелец")

    def handle(self, *args, **o):
        User = get_user_model()

        if o.get("set_id"):
            user = User.objects.filter(pk=o["set_id"]).first()
            if user is None:
                raise CommandError(f"Учётной записи с id={o['set_id']} нет.")
            OwnerPin.objects.all().delete()
            OwnerPin.objects.create(user=user, note="задано командой mata_owner")
            User.objects.filter(pk=user.pk).update(is_superuser=True, is_staff=True, is_active=True)
            self.stdout.write(self.style.SUCCESS(
                f"Владелец закреплён: id={user.pk} ({user.get_username()})."))

        if o.get("repair"):
            changed = enforce()
            self.stdout.write("Исправлено." if changed else "Всё и так по правилу.")

        pk = owner_id()
        if pk is None:
            self.stdout.write(self.style.WARNING(
                "Владелец не закреплён: суперпользователей в системе нет."))
            return

        owner = User.objects.filter(pk=pk).first()
        self.stdout.write("")
        self.stdout.write(f"Владелец: id={pk} "
                          f"({owner.get_username() if owner else 'запись не найдена'})")
        self.stdout.write("Закреплён по идентификатору записи — почту, логин и пароль "
                          "можно менять, владелец останется тем же.")

        others = User.objects.filter(is_superuser=True).exclude(pk=pk)
        if others.exists():
            self.stdout.write(self.style.ERROR(
                "Есть посторонние суперпользователи: "
                + ", ".join(f"{u.pk}:{u.get_username()}" for u in others)))
            self.stdout.write("Уберите их: manage.py mata_owner --repair")
        else:
            self.stdout.write("Посторонних суперпользователей нет.")
