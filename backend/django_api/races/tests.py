"""Races API — СТРОГИЙ фильтр по региону клиента, upcoming/past, авто-«завершён»."""
import datetime as dt

from django.test import TestCase
from django.utils import timezone

from races.models import Race
from races.regions import canonical_region, resolve_client_region


class RacesApiTests(TestCase):
    def setUp(self):
        today = timezone.localdate()
        Race.objects.create(
            title="Московский марафон", date=today + dt.timedelta(days=30), city="Москва",
            region="Москва", scope="federal", type="road", distances=["42.2 км"],
            reg_status="soon", is_published=True,
        )
        Race.objects.create(
            title="Подмосковный трейл", date=today + dt.timedelta(days=25), city="Мытищи",
            region="Московская область", scope="regional", type="trail", is_published=True,
        )
        Race.objects.create(
            title="Казанский", date=today + dt.timedelta(days=20), city="Казань",
            region="Республика Татарстан", scope="regional", type="road", is_published=True,
        )
        Race.objects.create(
            title="Якутский ночной", date=today + dt.timedelta(days=15), city="Якутск",
            region="Республика Саха (Якутия)", scope="regional", type="night", is_published=True,
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
        self.assertIn("Московский марафон", titles)
        self.assertNotIn("Черновик", titles)

    def test_region_strict_only_own_region(self):
        # Клиент в Якутске видит ТОЛЬКО забеги Республики Саха — не Москву, не Казань.
        r = self.client.get("/v1/races", {"city": "Якутск"})
        titles = [x["title"] for x in r.json()["races"]]
        self.assertEqual(titles, ["Якутский ночной"])

    def test_region_groups_moscow_and_oblast(self):
        # Москва и Московская область — один регion для клиента из Москвы.
        r = self.client.get("/v1/races", {"city": "Москва"})
        titles = [x["title"] for x in r.json()["races"]]
        self.assertIn("Московский марафон", titles)
        self.assertIn("Подмосковный трейл", titles)
        self.assertNotIn("Казанский", titles)
        self.assertNotIn("Якутский ночной", titles)

    def test_city_maps_to_region(self):
        # Казань → Республика Татарстан; чужие регионы скрыты.
        r = self.client.get("/v1/races", {"city": "Казань"})
        titles = [x["title"] for x in r.json()["races"]]
        self.assertEqual(titles, ["Казанский"])

    def test_region_display_returned(self):
        r = self.client.get("/v1/races", {"city": "Якутск"}).json()
        self.assertEqual(r["region"], "Республика Саха (Якутия)")

    def test_gps_bbox_resolves_region(self):
        # GPS в Якутске (без города) → регион Саха.
        r = self.client.get("/v1/races", {"lat": "62.03", "lng": "129.73"})
        titles = [x["title"] for x in r.json()["races"]]
        self.assertEqual(titles, ["Якутский ночной"])

    def test_no_region_returns_all(self):
        r = self.client.get("/v1/races")
        titles = [x["title"] for x in r.json()["races"]]
        self.assertIn("Московский марафон", titles)
        self.assertIn("Казанский", titles)
        self.assertIn("Якутский ночной", titles)

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
        rid = Race.objects.get(title="Московский марафон").pk
        self.assertEqual(self.client.get(f"/v1/races/{rid}").status_code, 200)
        self.assertEqual(self.client.get("/v1/races/999999").status_code, 404)


class RegionResolverTests(TestCase):
    def test_canonical_groups_moscow(self):
        self.assertEqual(canonical_region("Москва"), canonical_region("Московская область"))
        self.assertEqual(canonical_region("Мытищи"), canonical_region("Москва"))

    def test_canonical_city_to_republic(self):
        self.assertEqual(canonical_region("Якутск"), canonical_region("Республика Саха (Якутия)"))
        self.assertEqual(canonical_region("Казань"), canonical_region("Республика Татарстан"))

    def test_unknown_self_matches(self):
        self.assertEqual(canonical_region("Тьмутаракань"), canonical_region("тьмутаракань"))
        self.assertNotEqual(canonical_region("Тьмутаракань"), canonical_region("Москва"))

    def test_resolve_priority(self):
        # region важнее city; city важнее GPS.
        self.assertEqual(resolve_client_region(region="Казань", city="Москва"), canonical_region("Казань"))
        self.assertEqual(resolve_client_region(city="Якутск"), canonical_region("Саха"))
        self.assertEqual(resolve_client_region(lat=55.75, lng=37.62), canonical_region("Москва"))
        self.assertEqual(resolve_client_region(), "")
