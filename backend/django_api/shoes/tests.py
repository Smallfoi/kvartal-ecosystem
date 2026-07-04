"""Трекер износа кроссовок (ECOSYSTEM §2.5): покупка → pending → подтверждение →
active; идемпотентный учёт км по runId; списание при исчерпании ресурса."""
from catalog.models import Product
from common.testutils import ApiTestCase
from shoes.models import ShoeAsset
from shoes.views import create_for_order


class ShoeTrackerTests(ApiTestCase):
    phone = "+79990007001"

    def setUp(self):
        super().setUp()
        Product.objects.create(
            id="p_shoe", name="Кроссовки Бег X", category_id="shoes", price=8000
        )
        Product.objects.create(
            id="p_tee", name="Футболка", category_id="apparel", price=2000
        )

    def _buy(self, order_id="SS-1", pid="p_shoe", qty=1):
        return create_for_order(
            self.uid, order_id, [{"productId": pid, "quantity": qty}]
        )

    def _sid(self):
        return f"shoe_{ShoeAsset.objects.filter(user_id=self.uid).first().pk}"

    def _activate(self):
        self._buy()
        sid = self._sid()
        self.api_post(f"/v1/shoes/{sid}/confirm", {"add": True})
        return sid

    def test_buy_creates_pending_only_for_shoes(self):
        n = create_for_order(self.uid, "SS-1", [
            {"productId": "p_shoe", "quantity": 1},
            {"productId": "p_tee", "quantity": 1},  # не обувь — пропускается
        ])
        self.assertEqual(n, 1)
        s = ShoeAsset.objects.get(user_id=self.uid)
        self.assertEqual(s.status, ShoeAsset.STATUS_PENDING)

    def test_create_idempotent_by_order(self):
        self._buy("SS-1")
        self._buy("SS-1")  # повтор того же заказа не задвоит
        self.assertEqual(ShoeAsset.objects.filter(user_id=self.uid).count(), 1)

    def test_pending_not_in_active_list(self):
        self._buy()
        self.assertEqual(len(self.api_get("/v1/shoes/pending").json()), 1)
        self.assertEqual(len(self.api_get("/v1/shoes").json()), 0)

    def test_confirm_add_activates(self):
        sid = self._activate()
        self.assertEqual(len(self.api_get("/v1/shoes").json()), 1)
        self.assertEqual(len(self.api_get("/v1/shoes/pending").json()), 0)
        del sid

    def test_confirm_decline_hides(self):
        self._buy()
        r = self.api_post(f"/v1/shoes/{self._sid()}/confirm", {"add": False})
        self.assertEqual(r.json()["status"], "declined")
        self.assertEqual(len(self.api_get("/v1/shoes").json()), 0)

    def test_distance_only_on_active(self):
        self._buy()
        sid = self._sid()
        self.assertEqual(
            self.api_post(f"/v1/shoes/{sid}/distance", {"km": 5}).status_code, 409
        )

    def test_distance_adds_km_and_remaining(self):
        sid = self._activate()
        r = self.api_post(f"/v1/shoes/{sid}/distance", {"km": 5.0}).json()
        self.assertEqual(r["totalKm"], 5.0)
        self.assertEqual(r["remainingKm"], 595.0)

    def test_distance_idempotent_by_run(self):
        sid = self._activate()
        self.api_post(f"/v1/shoes/{sid}/distance", {"km": 5, "runId": "r1"})
        r = self.api_post(f"/v1/shoes/{sid}/distance", {"km": 5, "runId": "r1"})
        self.assertTrue(r.json().get("deduped"))
        self.assertEqual(
            ShoeAsset.objects.get(user_id=self.uid).total_km, 5.0
        )

    def test_retire_when_resource_exhausted(self):
        sid = self._activate()
        r = self.api_post(f"/v1/shoes/{sid}/distance", {"km": 600}).json()
        self.assertTrue(r["retired"])

    def test_delete_removes(self):
        self._buy()
        sid = self._sid()
        r = self.client.delete(
            f"/v1/shoes/{sid}", HTTP_AUTHORIZATION=f"Bearer {self.token}"
        )
        self.assertEqual(r.status_code, 200)
        self.assertEqual(ShoeAsset.objects.filter(user_id=self.uid).count(), 0)

    def test_requires_auth(self):
        self.assertEqual(self.client.get("/v1/shoes").status_code, 401)
