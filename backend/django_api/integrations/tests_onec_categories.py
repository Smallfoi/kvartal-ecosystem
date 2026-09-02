"""Справочник категорий из 1С и остаток по размерам (D-62, вторая очередь).

Две вещи, которых не хватало обмену: категории приходилось заводить руками, а
остаток по размерам приезжал и терялся — витрина знала только «есть/нет» целиком.
"""
from django.test import TestCase, override_settings

from catalog.models import Category, Product

TOKEN = "test-1c-token"
CATEGORIES = "/v1/integrations/1c/categories"
CATALOG = "/v1/integrations/1c/catalog"
PRICES = "/v1/integrations/1c/prices"


@override_settings(INTEGRATION_1C_TOKEN=TOKEN)
class OneCCategoryTests(TestCase):
    def _post(self, url, payload, token=TOKEN):
        headers = {"HTTP_AUTHORIZATION": f"Bearer {token}"} if token else {}
        return self.client.post(url, payload, content_type="application/json", **headers)

    def test_token_required(self):
        r = self.client.post(CATEGORIES, {"categories": []}, content_type="application/json")
        self.assertEqual(r.status_code, 401)

    def test_creates_categories(self):
        r = self._post(CATEGORIES, {"categories": [
            {"id": "shoes", "name": "Кроссовки", "sort": 10},
            {"id": "tshirts", "name": "Футболки", "parentId": "clothes", "sort": 20},
        ]})
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["created"], 2)
        shoes = Category.objects.get(id="shoes")
        self.assertEqual(shoes.name, "Кроссовки")
        self.assertEqual(shoes.sort, 10)
        self.assertEqual(Category.objects.get(id="tshirts").parent_id, "clothes")

    def test_repeat_updates_not_duplicates(self):
        self._post(CATEGORIES, {"categories": [{"id": "shoes", "name": "Кроссовки"}]})
        r = self._post(CATEGORIES, {"categories": [{"id": "shoes", "name": "Обувь"}]})
        self.assertEqual(r.json()["updated"], 1)
        self.assertEqual(Category.objects.filter(id="shoes").count(), 1)
        self.assertEqual(Category.objects.get(id="shoes").name, "Обувь")

    def test_our_emoji_and_photo_survive_import(self):
        """Эмодзи и фото в 1С нет — выгрузка не должна их стирать."""
        Category.objects.create(id="shoes", name="Кроссовки", emoji="👟",
                                image_url="https://cdn/shoes.jpg")
        self._post(CATEGORIES, {"categories": [{"id": "shoes", "name": "Обувь"}]})
        c = Category.objects.get(id="shoes")
        self.assertEqual(c.emoji, "👟")
        self.assertEqual(c.image_url, "https://cdn/shoes.jpg")

    def test_missing_category_is_not_deleted(self):
        """Пропала из выгрузки — не удаляем: на неё ссылаются товары."""
        Category.objects.create(id="old", name="Старая")
        self._post(CATEGORIES, {"categories": [{"id": "shoes", "name": "Кроссовки"}]})
        self.assertTrue(Category.objects.filter(id="old").exists())

    def test_bad_items_reported_not_fatal(self):
        r = self._post(CATEGORIES, {"categories": [
            {"name": "Без id"},
            {"id": "new-one"},                       # новая без названия
            {"id": "ok", "name": "Нормальная"},
        ]})
        body = r.json()
        self.assertEqual(body["created"], 1)
        self.assertEqual(len(body["errors"]), 2)

    def test_plain_array_accepted(self):
        """1С удобнее слать по-разному — принимаем и голый массив."""
        r = self._post(CATEGORIES, [{"id": "shoes", "name": "Кроссовки"}])
        self.assertEqual(r.json()["created"], 1)

    def test_unknown_category_reported_on_catalog_import(self):
        """Товар с незаведённой категорией сохраняется, но об этом говорим вслух."""
        r = self._post(CATALOG, {"products": [
            {"id": "SS-1", "name": "Товар", "categoryId": "nowhere"}]})
        body = r.json()
        self.assertEqual(body["created"], 1)
        self.assertEqual(body["unknownCategories"], ["nowhere"])
        self.assertTrue(any("nowhere" in e for e in body["errors"]))

    def test_known_category_no_complaint(self):
        Category.objects.create(id="shoes", name="Кроссовки")
        r = self._post(CATALOG, {"products": [
            {"id": "SS-2", "name": "Товар", "categoryId": "shoes"}]})
        self.assertEqual(r.json()["unknownCategories"], [])
        self.assertEqual(r.json()["errors"], [])


@override_settings(INTEGRATION_1C_TOKEN=TOKEN)
class OneCStockBySizeTests(TestCase):
    def _post(self, url, payload):
        return self.client.post(url, payload, content_type="application/json",
                                HTTP_AUTHORIZATION=f"Bearer {TOKEN}")

    def setUp(self):
        self._post(CATALOG, {"products": [{
            "id": "SS-0042", "article": "AR-X1", "name": "Кроссовки",
            "categoryId": "shoes", "sizes": ["40", "41", "42"],
        }]})

    def test_variants_fill_stock_by_size(self):
        r = self._post(PRICES, {"prices": [{
            "id": "SS-0042", "price": 11990,
            "variants": [
                {"variantId": "a", "size": "40", "stock": 3},
                {"variantId": "b", "size": "41", "stock": 0},
                {"variantId": "c", "size": "42", "stock": 7},
            ],
        }]})
        self.assertEqual(r.status_code, 200)
        p = Product.objects.get(external_id="SS-0042")
        self.assertEqual(p.stock_by_size, {"40": 3, "41": 0, "42": 7})
        self.assertEqual(p.stock_count, 10)      # общий остаток — сумма
        self.assertTrue(p.in_stock)

    def test_same_size_from_several_rows_is_summed(self):
        """Один размер в разных цветах или на разных складах — это один размер."""
        self._post(PRICES, {"prices": [{
            "id": "SS-0042", "price": 100,
            "variants": [
                {"size": "41", "stock": 2, "color": "чёрный"},
                {"size": "41", "stock": 3, "color": "белый"},
            ],
        }]})
        self.assertEqual(Product.objects.get(external_id="SS-0042").stock_by_size, {"41": 5})

    def test_all_sizes_empty_means_out_of_stock(self):
        self._post(PRICES, {"prices": [{
            "id": "SS-0042", "price": 100,
            "variants": [{"size": "40", "stock": 0}, {"size": "41", "stock": 0}],
        }]})
        p = Product.objects.get(external_id="SS-0042")
        self.assertEqual(p.stock_count, 0)
        self.assertFalse(p.in_stock)

    def test_plain_stock_clears_stale_breakdown(self):
        """Пришёл общий остаток без размеров — старая разбивка уже неправда."""
        self._post(PRICES, {"prices": [{
            "id": "SS-0042", "price": 100, "variants": [{"size": "40", "stock": 5}]}]})
        self._post(PRICES, {"prices": [{"id": "SS-0042", "price": 100, "stock": 9}]})
        p = Product.objects.get(external_id="SS-0042")
        self.assertEqual(p.stock_by_size, {})
        self.assertEqual(p.stock_count, 9)

    def test_breakdown_goes_to_storefront(self):
        self._post(PRICES, {"prices": [{
            "id": "SS-0042", "price": 100,
            "variants": [{"size": "41", "stock": 0}, {"size": "42", "stock": 4}]}]})
        Category.objects.create(id="shoes", name="Кроссовки")
        item = self.client.get("/v1/products").json()[0]
        self.assertEqual(item["stockBySize"], {"41": 0, "42": 4})

    def test_no_breakdown_is_empty_not_missing(self):
        """Товар не из 1С: поле есть и пустое — витрина считает доступным всё."""
        Product.objects.create(id="manual", name="Ручной", category_id="shoes", price=10)
        item = [p for p in self.client.get("/v1/products").json() if p["id"] == "manual"][0]
        self.assertEqual(item["stockBySize"], {})

    def test_broken_stock_is_reported_not_fatal(self):
        r = self._post(PRICES, {"prices": [{
            "id": "SS-0042", "price": 100,
            "variants": [{"size": "40", "stock": "много"}, {"size": "41", "stock": 2}]}]})
        self.assertTrue(r.json()["errors"])
        self.assertEqual(Product.objects.get(external_id="SS-0042").stock_by_size, {"41": 2})
