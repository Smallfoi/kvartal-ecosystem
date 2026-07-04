"""Отчёт готовности к запуску: какие интеграции настроены, безопасна ли прод-конфигурация,
опубликованы ли обязательные юр-документы.

Запуск:  python manage.py check_launch_readiness
Каркасы SMS/оплаты/пуша в dev работают как no-op — команда показывает, что осталось
включить владельцу (вставить ключи аккаунтов). См. docs/LAUNCH_READINESS.md.
"""
from django.core.management.base import BaseCommand

from common.launch import launch_report


def _mark(ok):
    return "[OK]" if ok else "[--]"


class Command(BaseCommand):
    help = "Печатает отчёт готовности к запуску (интеграции/безопасность/юр-документы)."

    def handle(self, *args, **options):
        rep = launch_report()

        self.stdout.write("=== Внешние интеграции (каркасы готовы, ждут ключей владельца) ===")
        for it in rep["integrations"]:
            self.stdout.write(
                f"  {_mark(it['ready'])} {it['name']} — провайдер: {it['provider']}"
            )
            if not it["ready"]:
                self.stdout.write(f"        нужно: {it['needs']}")

        self.stdout.write("=== Инфраструктура ===")
        for it in rep["infra"]:
            self.stdout.write(f"  {_mark(it['ready'])} {it['name']}")
            if not it["ready"]:
                self.stdout.write(f"        нужно: {it['needs']}")

        sec = rep["security"]
        self.stdout.write("=== Прод-безопасность ===")
        if not sec["prodMode"]:
            self.stdout.write("  [--] DEBUG=1 (dev-режим) — прод-проверки секретов не применяются")
        elif sec["insecure"]:
            self.stdout.write(f"  [--] Небезопасные дефолтные настройки: {', '.join(sec['insecure'])}")
        else:
            self.stdout.write("  [OK] Прод-секреты заданы, ALLOWED_HOSTS ограничен")

        legal = rep["legal"]
        self.stdout.write("=== Юр-документы (launch-gate) ===")
        if legal["ok"]:
            self.stdout.write("  [OK] Все обязательные документы опубликованы")
        elif not legal["requiredTypes"]:
            self.stdout.write("  [--] Нет обязательных документов в базе (создать и опубликовать)")
        else:
            self.stdout.write(f"  [--] Не опубликованы: {', '.join(legal['missing'])}")

        # Сводка go/no-go по автономно-проверяемым пунктам (интеграции/хостинг — за владельцем).
        blockers = sec["prodMode"] and (bool(sec["insecure"]) or not legal["ok"])
        self.stdout.write("")
        if not sec["prodMode"]:
            self.stdout.write("ИТОГ: dev-режим. Для прода включи DJANGO_DEBUG=0 и повтори проверку.")
        elif blockers:
            self.stdout.write("ИТОГ: ЕСТЬ БЛОКЕРЫ прода (см. безопасность/документы выше).")
        else:
            self.stdout.write("ИТОГ: прод-конфиг безопасен. Интеграции включаются ключами владельца.")
