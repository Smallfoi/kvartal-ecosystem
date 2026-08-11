"""Авто-парсер «Стартов»: upsert по (source, external_id), идемпотентность,
неприкосновенность ручных записей, нормализация, dry-run."""
import datetime as dt

from django.test import TestCase

from races.importers.base import normalize, parse_date
from races.models import Race
from races.services import run_import


class ImportServiceTests(TestCase):
    def test_demo_import_creates_then_updates(self):
        # Первый прогон демо-источника — создаёт; второй — обновляет, без дублей.
        s1 = run_import(sources=["parser-demo"])
        self.assertGreater(s1["created"], 0)
        self.assertEqual(s1["updated"], 0)
        count_after_first = Race.objects.filter(source="parser-demo").count()
        self.assertEqual(count_after_first, s1["created"])

        s2 = run_import(sources=["parser-demo"])
        self.assertEqual(s2["created"], 0)
        self.assertEqual(s2["updated"], count_after_first)
        # Дублей не появилось.
        self.assertEqual(
            Race.objects.filter(source="parser-demo").count(), count_after_first
        )

    def test_import_does_not_touch_manual(self):
        manual = Race.objects.create(
            title="Ручной забег", date=dt.date(2026, 12, 1), city="Якутск",
            region="Республика Саха (Якутия)", source="manual", is_published=True,
        )
        run_import(sources=["parser-demo"])
        manual.refresh_from_db()
        self.assertEqual(manual.title, "Ручной забег")
        self.assertEqual(manual.source, "manual")

    def test_dry_run_writes_nothing(self):
        s = run_import(sources=["parser-demo"], dry_run=True)
        self.assertEqual(Race.objects.filter(source="parser-demo").count(), 0)
        self.assertEqual(s["created"], 0)
        self.assertGreater(s["skipped"], 0)

    def test_jsonfeed_empty_without_url(self):
        # Без RACES_IMPORT_FEED_URL джсон-фид-импортёр молчит.
        s = run_import(sources=["jsonfeed"])
        self.assertEqual(s["created"], 0)
        self.assertEqual(s["errors"], 0)

    def test_imported_races_visible_by_region(self):
        run_import(sources=["parser-demo"])
        # Демо содержит Екатеринбург (Свердловская область) — виден по своему региону.
        r = self.client.get("/v1/races", {"city": "Екатеринбург"}).json()
        titles = [x["title"] for x in r["races"]]
        self.assertTrue(any("Европа" in t for t in titles))
        # Но не виден якутскому клиенту (строгий регион).
        r2 = self.client.get("/v1/races", {"city": "Якутск"}).json()
        self.assertFalse(any("Европа" in x["title"] for x in r2["races"]))


class NormalizeTests(TestCase):
    def test_parse_date(self):
        self.assertEqual(parse_date("2026-09-20"), dt.date(2026, 9, 20))
        self.assertEqual(parse_date(dt.date(2026, 1, 1)), dt.date(2026, 1, 1))
        self.assertIsNone(parse_date("не дата"))
        self.assertIsNone(parse_date(None))

    def test_normalize_requires_key_fields(self):
        self.assertIsNone(normalize({"title": "Без id и даты"}))
        self.assertIsNone(normalize({"external_id": "x", "title": "Нет даты"}))
        ok = normalize({"external_id": "x", "title": "Ок", "date": "2026-05-01"})
        self.assertIsNotNone(ok)
        self.assertEqual(ok["type"], "road")  # дефолт
        self.assertEqual(ok["reg_status"], "soon")

    def test_normalize_sanitizes_type_and_distances(self):
        ok = normalize({
            "external_id": "y", "title": "Т", "date": "2026-05-01",
            "type": "МУСОР", "distances": ["10 км", "", 5], "points": "70",
        })
        self.assertEqual(ok["type"], "other")
        self.assertEqual(ok["distances"], ["10 км", "5"])
        self.assertEqual(ok["points"], 70)
