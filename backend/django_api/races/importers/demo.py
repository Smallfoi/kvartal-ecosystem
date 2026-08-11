"""Демо-импортёр — показывает работу авто-парсера end-to-end без скрейпинга.

Возвращает небольшой НАБОР забегов из разных регионов (source="parser-demo",
у каждого свой external_id). На повторном запуске те же external_id → update, а не
дубликаты. Служит и наглядным примером формата для настоящих источников, и наполняет
карту регионов, пока не подключены реальные парсеры.

Данные — черновой демонстрационный набор (не официальная афиша).
"""
from __future__ import annotations

from .base import RaceImporter

# (external_id, title, date, city, region, place, type, distances, reg_status, points)
_DEMO = [
    ("demo-ekb-marathon-2026", "Марафон «Европа–Азия»", "2026-08-09", "Екатеринбург",
     "Свердловская область", "Площадь 1905 года", "road",
     ["42.2 км", "10 км"], "soon", 250),
    ("demo-nnov-halfmarathon-2026", "Нижегородский полумарафон «Беги, герой!»",
     "2026-09-27", "Нижний Новгород", "Нижегородская область", "Нижегородский кремль",
     "road", ["21.1 км", "10 км", "5 км"], "soon", 200),
    ("demo-sochi-trail-2026", "Sochi Trail — горный забег", "2026-10-11", "Сочи",
     "Краснодарский край", "Красная Поляна", "trail", ["30 км", "15 км"], "soon", 220),
    ("demo-vlad-bridges-2026", "Владивостокский марафон «Мосты»", "2026-10-18",
     "Владивосток", "Приморский край", "Золотой мост", "road",
     ["42.2 км", "21.1 км", "10 км"], "soon", 260),
    ("demo-ufa-halfmarathon-2026", "Уфимский международный марафон", "2026-09-13",
     "Уфа", "Республика Башкортостан", "Советская площадь", "road",
     ["42.2 км", "21.1 км", "10 км", "3 км"], "soon", 240),
]


class DemoImporter(RaceImporter):
    source = "parser-demo"
    label = "Демо-источник (показывает работу парсера)"

    def fetch(self) -> list[dict]:
        return [
            {
                "external_id": eid,
                "title": title,
                "date": date,
                "city": city,
                "region": region,
                "place": place,
                "type": rtype,
                "distances": dists,
                "reg_status": reg,
                "points": pts,
                "scope": "regional",
                "description": f"{title} — данные добавлены авто-парсером (демо-источник).",
                "source_url": "",
            }
            for (eid, title, date, city, region, place, rtype, dists, reg, pts) in _DEMO
        ]
