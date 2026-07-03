"""Конструктор витрины (мерчендайзинг): раздельный порядок по площадкам +
правка центрального товара. Эндпоинты staff-only."""
import json

from django.contrib.auth.models import User
from django.test import TestCase

from catalog.models import Product


class MerchConsoleTests(TestCase):
    def setUp(self):
        User.objects.create_superuser("merch_admin", "a@t.dev", "pass12345")
        self.client.login(username="merch_admin", password="pass12345")
        Product.objects.create(id="m1", name="M1", category_id="c", price=100,
                               sort_site=0, sort_app=0)
        Product.objects.create(id="m2", name="M2", category_id="c", price=200,
                               sort_site=1, sort_app=1)

    def _post(self, url, body):
        return self.client.post(url, data=json.dumps(body),
                                content_type="application/json")

    def test_reorder_updates_only_that_platform(self):
        r = self._post("/admin/merch/reorder", {"platform": "site", "order": ["m2", "m1"]})
        self.assertEqual(r.status_code, 200)
        self.assertEqual(Product.objects.get(id="m2").sort_site, 0)
        self.assertEqual(Product.objects.get(id="m1").sort_site, 1)
        # Порядок приложения не затронут.
        self.assertEqual(Product.objects.get(id="m2").sort_app, 1)
        self.assertEqual(Product.objects.get(id="m1").sort_app, 0)

    def test_reorder_bad_platform(self):
        self.assertEqual(self._post("/admin/merch/reorder", {"platform": "x", "order": []}).status_code, 400)

    def test_product_edit_is_central(self):
        r = self._post("/admin/merch/product/m1",
                       {"price": 999, "oldPrice": 1200, "isPublished": False,
                        "inStock": False, "sizes": ["M", "L"], "description": "новое"})
        self.assertEqual(r.status_code, 200)
        p = Product.objects.get(id="m1")
        self.assertEqual(p.price, 999)
        self.assertEqual(p.old_price, 1200)
        self.assertFalse(p.is_published)
        self.assertFalse(p.in_stock)
        self.assertEqual(p.sizes, ["M", "L"])
        self.assertEqual(p.description, "новое")

    def test_product_empty_old_price_clears(self):
        Product.objects.filter(id="m1").update(old_price=1200)
        self._post("/admin/merch/product/m1", {"oldPrice": ""})
        self.assertIsNone(Product.objects.get(id="m1").old_price)

    def test_product_404(self):
        self.assertEqual(self._post("/admin/merch/product/nope", {"price": 1}).status_code, 404)

    def test_products_list_ordered_by_platform(self):
        Product.objects.filter(id="m1").update(sort_app=5)
        Product.objects.filter(id="m2").update(sort_app=1)
        ids = [p["id"] for p in self.client.get("/admin/merch/products?platform=app").json()["products"]]
        self.assertEqual(ids[:2], ["m2", "m1"])

    def test_console_page_renders(self):
        r = self.client.get("/admin/merch/")
        self.assertEqual(r.status_code, 200)
        self.assertContains(r, "Конструктор витрины")

    def test_requires_staff(self):
        self.client.logout()
        r = self._post("/admin/merch/reorder", {"platform": "site", "order": []})
        self.assertIn(r.status_code, (302, 403))
