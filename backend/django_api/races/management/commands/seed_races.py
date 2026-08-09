"""seed_races — наполнить афишу «Стартов» реальными забегами 2026 (черновик-набор).

Федеральные крупные (видны всем) + региональные (видны по региону клиента). Идемпотентно
(update_or_create по названию). Реальные данные позже дополняются авто-парсером (source!=manual).

    docker compose exec web python manage.py seed_races
"""
import datetime as dt

from django.core.management.base import BaseCommand

from races.models import Race

FED = Race.SCOPE_FEDERAL
REG = Race.SCOPE_REGIONAL

# (title, date, city, region, place, scope, type, distances, reg_status, points, reg_url, desc)
RACES = [
    # ── Федеральные крупные (видны всем) ──
    ("Московский полумарафон", dt.date(2026, 4, 25), "Москва", "Москва", "Старт у «Лужников»",
     FED, "road", ["21.1 км", "10 км"], Race.REG_DONE, 150, "https://runc.run/",
     "Весенний полумарафон по центру Москвы — одна из главных дистанций сезона."),
    ("Эстафета по Садовому кольцу", dt.date(2026, 5, 16), "Москва", "Москва", "Садовое кольцо",
     FED, "relay", ["Эстафета"], Race.REG_DONE, 100, "https://runc.run/",
     "Командная эстафета по легендарному кольцу столицы."),
    ("Марафон «Белые ночи»", dt.date(2026, 7, 4), "Санкт-Петербург", "Санкт-Петербург", "Дворцовая площадь",
     FED, "road", ["42.2 км", "21.1 км"], Race.REG_DONE, 300, "https://runc.run/",
     "Марафон в самое светлое время года по историческому центру Петербурга."),
    ("Большой фестиваль бега", dt.date(2026, 8, 22), "Москва", "Москва", "Лужники",
     FED, "fest", ["10 км", "5 км", "1 км · дети"], Race.REG_OPEN, 120, "https://runc.run/",
     "Семейный праздник бега: дистанции для всех — от детей до опытных бегунов."),
    ("Московский марафон", dt.date(2026, 9, 20), "Москва", "Москва", "Лужники",
     FED, "road", ["42.2 км", "10 км"], Race.REG_SOON, 300, "https://runc.run/",
     "Главный марафон страны — 42.2 км по центру Москвы."),

    # ── Региональные (видны по региону/городу клиента) ──
    ("Казанский марафон", dt.date(2026, 5, 10), "Казань", "Республика Татарстан", "Центр Казани",
     REG, "road", ["42.2 км", "21.1 км", "10 км", "3 км"], Race.REG_DONE, 250, "",
     "Крупнейший марафон Поволжья по красивейшим набережным Казани."),
    ("Ночной забег в Казани", dt.date(2026, 8, 30), "Казань", "Республика Татарстан", "Кремлёвская набережная",
     REG, "night", ["10 км", "5 км"], Race.REG_OPEN, 90, "",
     "Вечерний старт по подсвеченной набережной — атмосферный городской забег."),
    ("Сибирский международный марафон (SIM)", dt.date(2026, 8, 2), "Омск", "Омская область", "Соборная площадь",
     REG, "road", ["42.2 км", "21.1 км", "10 км"], Race.REG_DONE, 250, "",
     "Один из старейших марафонов России."),
    ("Иркутский международный марафон", dt.date(2026, 9, 13), "Иркутск", "Иркутская область", "Остров Юность",
     REG, "road", ["42.2 км", "21.1 км", "5 км"], Race.REG_SOON, 250, "",
     "Марафон у Байкала — живописная трасса по берегу Ангары."),
    ("Полумарафон «Золотое кольцо»", dt.date(2026, 9, 6), "Ярославль", "Ярославская область", "Стрелка",
     REG, "road", ["21.1 км", "10 км"], Race.REG_SOON, 180, "",
     "Полумарафон по историческому Ярославлю."),
]


class Command(BaseCommand):
    help = "Наполнить афишу «Стартов» реальными забегами 2026 (идемпотентно)."

    def handle(self, *args, **opts):
        created = updated = 0
        for (title, date, city, region, place, scope, rtype, dists, reg, pts, url, desc) in RACES:
            obj, was_created = Race.objects.update_or_create(
                title=title,
                defaults=dict(
                    date=date, city=city, region=region, place=place, scope=scope,
                    type=rtype, distances=dists, reg_status=reg, points=pts,
                    reg_url=url, description=desc, is_published=True, source="manual",
                ),
            )
            created += int(was_created)
            updated += int(not was_created)
        self.stdout.write(self.style.SUCCESS(f"seed_races: создано {created}, обновлено {updated}"))
