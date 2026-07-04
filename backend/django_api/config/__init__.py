# Celery-приложение поднимается вместе с Django (D-07), чтобы @shared_task находили
# общий инстанс и работал autodiscover. Без брокера — EAGER (см. config/celery.py).
from .celery import app as celery_app

__all__ = ("celery_app",)
