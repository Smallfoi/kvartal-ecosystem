"""Races API — фильтр по региону клиента, upcoming/past, авто-«завершён»."""
import datetime as dt

from django.test import TestCase
from django.utils import timezone

from races.models import Race


class RacesApiTests(TestCase):
    def setUp(self):
        today = timezone.localdate()
        Race.objects.create(
            title="Фед марафон", date=today + dt.timedelta(days=30), city="Москва",
            region="Москва", scope="federal", type="road", distances=["42.2 км"],
            reg_status="soon", is_published=True,
        )
        Race.objects.create(
            title="Казанский", date=today + dt.timedelta(days=20), city="Казань",
            region="Республика Татарстан", scope="regional", type="road", is_published=True,
        )
        Race.objects.create(
            title="Прошедший Омск", date=today - dt.timedelta(days=5), city="Омск",
            region="Омская область", scope="regional", reg_status="open", is_published=True,
        )
        Race.objects.create(
            title="Черновик", date=today + dt.timedelta(days=10), city="Москва",
            scope="federal", is_published=False,
        )

    def test_list_only_published(self):
        r = self.client.get("/v1/races")
        self.assertEqual(r.status_code, 200)
        titles = [x["title"] for x in r.json()["races"]]
        self.assertIn("Фед марафон", titles)
        self.assertNotIn("Черновик", titles)

    def test_region_shows_federal_plus_own_region(self):
        r = self.client.get("/v1/races", {"region": "Республика Татарстан"})
        titles = [x["title"] for x in r.json()["races"]]
        self.assertIn("Фед марафон", titles)      # федеральный — всем
        self.assertIn("Казанский", titles)         # свой регион
        self.assertNotIn("Прошедший Омск", titles)  # чужой регион — скрыт

    def test_city_filter(self):
        r = self.client.get("/v1/races", {"city": "Казань"})
        titles = [x["title"] for x in r.json()["races"]]
        self.assertIn("Казанский", titles)
        self.assertIn("Фед марафон", titles)

    def test_when_upcoming_and_past(self):
        today = timezone.localdate().isoformat()
        up = self.client.get("/v1/races", {"when": "upcoming"}).json()["races"]
        self.assertTrue(all(x["date"] >= today for x in up))
        past = self.client.get("/v1/races", {"when": "past"}).json()["races"]
        self.assertIn("Прошедший Омск", [x["title"] for x in past])

    def test_past_auto_done_status(self):
        past = self.client.get("/v1/races", {"when": "past"}).json()["races"]
        p = [x for x in past if x["title"] == "Прошедший Омск"][0]
        self.assertEqual(p["regStatus"], "done")  # авто-завершён, хотя reg_status=open

    def test_detail_and_404(self):
        rid = Race.objects.get(title="Фед марафон").pk
        self.assertEqual(self.client.get(f"/v1/races/{rid}").status_code, 200)
        self.assertEqual(self.client.get("/v1/races/999999").status_code, 404)
