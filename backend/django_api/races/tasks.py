"""Фоновые задачи «Стартов» (D-07). Периодический авто-импорт забегов из источников
— по расписанию beat (CELERY_BEAT_SCHEDULE) и вручную командой import_races."""
from celery import shared_task


@shared_task(name="races.import_races", ignore_result=True)
def import_races():
    """Обёртка над services.run_import — единая логика для beat и ручного запуска."""
    from .services import run_import

    return run_import()
