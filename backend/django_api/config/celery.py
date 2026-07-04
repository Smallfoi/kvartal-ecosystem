"""Celery-приложение экосистемы STAW (D-07).

Фоновые задачи: async-пуши (не блокируем HTTP-ответ на провайдере), периодическая
чистка протухших территорий (beat). Конфиг берётся из Django settings (namespace
CELERY_*). БЕЗ брокера (нет REDIS_URL/CELERY_BROKER_URL) — режим EAGER: задачи
выполняются синхронно inline, отдельная инфра не нужна (dev/CI/тесты работают как есть).
"""
import os

from celery import Celery

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

app = Celery("staw")
# Все настройки берём из Django settings по префиксу CELERY_ (ленивая привязка).
app.config_from_object("django.conf:settings", namespace="CELERY")
# Автопоиск tasks.py во всех установленных приложениях.
app.autodiscover_tasks()
