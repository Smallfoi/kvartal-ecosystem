"""Реестр импортёров забегов. Добавить источник = добавить класс сюда.

Настоящие сайты-агрегаторы (runc.run, russiarunning, get.run) подключаются
отдельными импортёрами по мере готовности: у большинства нет открытого API →
нужен аккуратный HTML-скрейпинг (хрупкий, ломается при смене вёрстки), а фото/лого
защищены авторским правом + ToS — импортировать их нельзя. Пока: DemoImporter
(демонстрация пайплайна) + JsonFeedImporter (реальный, тянет нормализованный JSON-фид).
"""
from .demo import DemoImporter
from .jsonfeed import JsonFeedImporter

# Порядок = порядок запуска.
ALL_IMPORTERS = [DemoImporter(), JsonFeedImporter()]


def get_importers(sources=None):
    """Импортёры по списку кодов source; без аргумента — все."""
    if not sources:
        return list(ALL_IMPORTERS)
    wanted = set(sources)
    return [imp for imp in ALL_IMPORTERS if imp.source in wanted]
