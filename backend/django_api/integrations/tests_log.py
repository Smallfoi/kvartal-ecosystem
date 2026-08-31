"""Журнал обмена с 1С (D-62): каждая выгрузка оставляет строку, страница её показывает."""
import json

from django.contrib.auth.models import User
from django.core.cache import cache
from django.test import TestCase, override_settings

from catalog.models import Product
from integrations.models import OneCExchange

TOKEN = "test-1c-token"
AUTH = {"HTTP_AUTHORIZATION": f"Bearer {TOKEN}"}


@override_settings(INTEGRATION_1C_TOKEN=TOKEN)
class OneCLogTests(TestCase):
    def setUp(self):
        cache.clear()   # счётчик «не чаще раза в 5 минут» не должен течь между тестами

    def _catalog(self, items, **extra):
        return self.client.post("/v1/integrations/1c/catalog",
                                data=json.dumps({"products": items}),
                                content_type="application/json", **extra)

    def test_successful_exchange_is_logged(self):
        self._catalog([{"id": "g1", "name": "Кроссовки", "categoryId": "c", "price": 100}], **AUTH)
        row = OneCExchange.objects.get()
        self.assertEqual(row.operation, "catalog")
        self.assertEqual(row.status, "ok")
        self.assertEqual(row.received, 1)
        self.assertEqual(row.created_count, 1)
        self.assertEqual(row.updated_count, 0)
        self.assertEqual(row.touched, 1)

    def test_second_run_counts_as_update(self):
        item = {"id": "g1", "name": "Кроссовки", "categoryId": "c", "price": 100}
        self._catalog([item], **AUTH)
        self._catalog([item], **AUTH)
        last = OneCExchange.objects.first()
        self.assertEqual(last.created_count, 0)
        self.assertEqual(last.updated_count, 1)

    def test_bad_item_makes_status_partial(self):
        self._catalog([{"name": "без идентификатора"}], **AUTH)
        row = OneCExchange.objects.get()
        self.assertEqual(row.status, "partial")
        self.assertEqual(row.errors_count, 1)

    def test_wrong_token_logged_as_error(self):
        r = self._catalog([], HTTP_AUTHORIZATION="Bearer nope")
        self.assertEqual(r.status_code, 401)
        row = OneCExchange.objects.get()
        self.assertEqual(row.status, "error")
        self.assertIn("токен", row.detail.lower())

    def test_token_bruteforce_does_not_flood_the_log(self):
        """Перебор ключа не должен превращаться в способ забить базу."""
        for _ in range(5):
            self._catalog([], HTTP_AUTHORIZATION="Bearer nope")
        self.assertEqual(OneCExchange.objects.count(), 1)

    def test_kept_fields_are_visible_in_log(self):
        Product.objects.create(id="p1", name="Товар", category_id="c", price=999,
                               external_id="g1", overrides=["price"], from_1c={"price": 999})
        self._catalog([{"id": "g1", "name": "Товар", "categoryId": "c", "price": 500}], **AUTH)
        self.assertEqual(OneCExchange.objects.get().kept_by_owner, ["price"])


@override_settings(INTEGRATION_1C_TOKEN=TOKEN)
class OneCLogPageTests(TestCase):
    def setUp(self):
        User.objects.create_superuser("log_admin", "c@t.dev", "pass12345")
        self.client.login(username="log_admin", password="pass12345")
        OneCExchange.objects.create(operation="catalog", status="ok",
                                    received=3, created_count=2, updated_count=1)
        OneCExchange.objects.create(operation="prices", status="error",
                                    detail="Требуется токен обмена")

    def test_page_shows_rows_and_totals(self):
        r = self.client.get("/admin/1c-log/")
        self.assertEqual(r.status_code, 200)
        self.assertContains(r, "Каталог")
        self.assertContains(r, "Цены и остатки")
        self.assertEqual(r.context["summary"]["created"], 2)
        self.assertEqual(r.context["summary"]["updated"], 1)
        self.assertEqual(r.context["summary"]["errors"], 1)

    def test_filter_by_operation(self):
        r = self.client.get("/admin/1c-log/?op=prices")
        self.assertEqual(len(r.context["rows"]), 1)
        self.assertEqual(r.context["rows"][0]["op_code"], "prices")

    def test_filter_by_status(self):
        r = self.client.get("/admin/1c-log/?status=error")
        self.assertEqual(len(r.context["rows"]), 1)
        self.assertEqual(r.context["rows"][0]["status_code"], "error")

    def test_page_requires_staff(self):
        self.client.logout()
        r = self.client.get("/admin/1c-log/")
        self.assertIn(r.status_code, (302, 403))
