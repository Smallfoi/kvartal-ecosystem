"""Отзывы на товары: доступны только купившим, пересчёт рейтинга, один на юзера,
фото-вложения и модерация (скрытие)."""
import tempfile

from django.test import override_settings

from catalog.models import Product, Review
from common.testutils import ApiTestCase
from orders.models import Order


class ReviewTests(ApiTestCase):
    phone = "+79990005001"

    def setUp(self):
        super().setUp()
        self.p = Product.objects.create(
            id="p_test", name="Кроссовки X", category_id="c1", price=5000
        )

    def _review(self, body, pid="p_test"):
        return self.api_post(f"/v1/products/{pid}/reviews", body)

    def _buy(self, pid="p_test"):
        Order.objects.create(
            user_id=self.uid,
            order_id="SS-1",
            total=5000,
            payload={"id": "SS-1", "items": [{"productId": pid, "qty": 1}]},
        )

    def test_cannot_review_without_purchase(self):
        self.assertEqual(self._review({"rating": 5, "text": "Огонь"}).status_code, 403)

    def test_review_after_purchase_recomputes_rating(self):
        self._buy()
        r = self._review({"rating": 4, "text": "Хорошие"})
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["rating"], 4.0)
        self.assertEqual(r.json()["reviewCount"], 1)
        self.p.refresh_from_db()
        self.assertEqual(self.p.rating, 4.0)
        self.assertEqual(self.p.review_count, 1)

    def test_one_review_per_user_updates(self):
        self._buy()
        self._review({"rating": 3, "text": "Ок"})
        self._review({"rating": 5, "text": "Передумал — топ"})
        self.assertEqual(
            Review.objects.filter(product_id="p_test", user_id=self.uid).count(), 1
        )
        self.p.refresh_from_db()
        self.assertEqual(self.p.rating, 5.0)

    def test_invalid_rating_rejected(self):
        self._buy()
        self.assertEqual(self._review({"rating": 0}).status_code, 400)
        self.assertEqual(self._review({"rating": 6}).status_code, 400)

    def test_get_reviews_lists_and_flags(self):
        self._buy()
        self._review({"rating": 5, "text": "Класс"})
        data = self.api_get("/v1/products/p_test/reviews").json()
        self.assertEqual(data["reviewCount"], 1)
        self.assertEqual(len(data["reviews"]), 1)
        self.assertTrue(data["reviews"][0]["mine"])
        self.assertTrue(data["canReview"])

    def test_reviews_404_for_unknown_product(self):
        self.assertEqual(self.api_get("/v1/products/nope/reviews").status_code, 404)

    # ── Фото отзыва ──────────────────────────────────────────────────────────

    def test_review_with_photos_stored_and_returned(self):
        self._buy()
        r = self._review({
            "rating": 5,
            "text": "С фото",
            "photos": ["/media/uploads/reviews/a.jpg", "/media/uploads/reviews/b.jpg"],
        })
        self.assertEqual(r.status_code, 200)
        self.assertEqual(len(r.json()["review"]["photos"]), 2)
        data = self.api_get("/v1/products/p_test/reviews").json()
        self.assertEqual(len(data["reviews"][0]["photos"]), 2)

    def test_review_photos_capped_at_5(self):
        self._buy()
        many = [f"/media/uploads/reviews/{i}.jpg" for i in range(8)]
        r = self._review({"rating": 4, "photos": many})
        self.assertEqual(len(r.json()["review"]["photos"]), 5)

    def test_review_photos_ignores_non_strings(self):
        self._buy()
        r = self._review({"rating": 4, "photos": ["/media/ok.jpg", 123, None, "  "]})
        self.assertEqual(r.json()["review"]["photos"], ["/media/ok.jpg"])

    @override_settings(MEDIA_ROOT=tempfile.mkdtemp())
    def test_review_photo_upload_returns_url(self):
        from io import BytesIO

        from django.core.files.uploadedfile import SimpleUploadedFile
        from PIL import Image

        buf = BytesIO()
        Image.new("RGB", (32, 32), (10, 200, 90)).save(buf, "PNG")
        img = SimpleUploadedFile("r.png", buf.getvalue(), content_type="image/png")
        r = self.client.post(
            "/v1/reviews/photo",
            {"image": img},
            HTTP_AUTHORIZATION=f"Bearer {self.token}",
        )
        self.assertEqual(r.status_code, 200)
        self.assertTrue(r.json()["url"].startswith("/media/uploads/reviews/"))

    def test_review_photo_upload_requires_auth(self):
        self.assertEqual(self.client.post("/v1/reviews/photo", {}).status_code, 401)

    # ── Модерация (скрытие) ──────────────────────────────────────────────────

    def test_hidden_review_excluded_from_list_and_rating(self):
        from catalog.views import _recompute_rating

        self._buy()
        self._review({"rating": 5, "text": "Топ"})
        self.p.refresh_from_db()
        self.assertEqual(self.p.rating, 5.0)
        Review.objects.filter(product_id="p_test").update(hidden=True)
        _recompute_rating("p_test")
        self.p.refresh_from_db()
        self.assertEqual(self.p.review_count, 0)
        self.assertEqual(self.p.rating, 0.0)
        data = self.api_get("/v1/products/p_test/reviews").json()
        self.assertEqual(len(data["reviews"]), 0)
        self.assertEqual(data["reviewCount"], 0)
