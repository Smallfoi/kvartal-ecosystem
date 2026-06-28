"""S-10 фаза 2: группа «Модератор» с ограниченными правами.

Создаёт/обновляет Django-группу «Модератор», которой доступна только модерация
(забеги, отзывы, аккаунты-баны, клубы), но НЕ полное администрирование (товары,
настройки, пользователи/группы). Запуск:  python manage.py setup_moderator_group

Назначение сотрудника модератором — интерактивно в /admin/: отметить is_staff и
добавить в группу «Модератор».
"""
from django.contrib.auth.models import Group, Permission
from django.core.management.base import BaseCommand


class Command(BaseCommand):
    help = "Создаёт/обновляет группу «Модератор» с правами модерации (S-10 ф.2)."

    # (app_label, model, [actions]) — что может модерировать.
    PERMS = [
        ("runs", "run", ["view", "change"]),          # одобрить/отклонить флаг-забег
        ("catalog", "review", ["view", "change", "delete"]),  # скрыть/удалить отзыв
        ("accounts", "account", ["view", "change"]),  # бан аккаунта
        ("clubs", "club", ["view", "change"]),        # скрыть клуб
    ]

    def handle(self, *args, **options):
        group, created = Group.objects.get_or_create(name="Модератор")
        group.permissions.clear()
        added, missing = 0, []
        for app_label, model, actions in self.PERMS:
            for action in actions:
                codename = f"{action}_{model}"
                perm = Permission.objects.filter(
                    content_type__app_label=app_label, codename=codename
                ).first()
                if perm:
                    group.permissions.add(perm)
                    added += 1
                else:
                    missing.append(f"{app_label}.{codename}")
        for m in missing:
            self.stdout.write(self.style.WARNING(f"нет права: {m}"))
        self.stdout.write(self.style.SUCCESS(
            f"Группа «Модератор» {'создана' if created else 'обновлена'}; "
            f"назначено прав: {added}. Дальше: /admin/ → Пользователи → выбрать "
            "сотрудника → is_staff + группа «Модератор»."
        ))
