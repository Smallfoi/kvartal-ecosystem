"""Юридические документы и аудит согласий (152-ФЗ / launch-gate): выдача текущих
опубликованных версий, запись/идемпотентность/отзыв согласий."""
from datetime import timedelta

from django.utils import timezone

from common.testutils import ApiTestCase
from legal.models import LegalDocument, UserConsent


def _doc(doc_type, version="1.0", required=True, published=True):
    return LegalDocument.objects.create(
        doc_type=doc_type,
        version=version,
        title=f"{doc_type} {version}",
        is_required=required,
        published_at=timezone.now() if published else None,
    )


class LegalTests(ApiTestCase):
    phone = "+79990008001"

    def test_documents_lists_only_published(self):
        _doc("terms", published=True)
        _doc("privacy", published=False)  # черновик — не показываем
        types = {d["type"] for d in self.client.get("/v1/legal/documents").json()}
        self.assertIn("terms", types)
        self.assertNotIn("privacy", types)

    def test_documents_returns_latest_published_version(self):
        old = _doc("terms", version="1.0")
        LegalDocument.objects.filter(pk=old.pk).update(
            published_at=timezone.now() - timedelta(days=1)
        )
        _doc("terms", version="2.0")  # опубликован позже
        terms = [
            d for d in self.client.get("/v1/legal/documents").json()
            if d["type"] == "terms"
        ]
        self.assertEqual(len(terms), 1)
        self.assertEqual(terms[0]["version"], "2.0")

    def test_documents_without_token(self):
        _doc("terms")
        r = self.client.get("/v1/legal/documents")
        self.assertEqual(r.status_code, 200)
        self.assertNotIn("accepted", r.json()[0])  # без токена — без пометки

    def test_accept_records_consents(self):
        _doc("terms")
        _doc("pd_consent")
        r = self.api_post(
            "/v1/legal/consent", {"accept": ["terms", "pd_consent"], "source": "kvartal"}
        )
        self.assertEqual(set(r.json()["recorded"]), {"terms", "pd_consent"})
        self.assertEqual(len(self.api_get("/v1/legal/consents").json()), 2)

    def test_accept_single_type(self):
        _doc("marketing", required=False)
        r = self.api_post("/v1/legal/consent", {"type": "marketing"})
        self.assertEqual(r.json()["recorded"], ["marketing"])

    def test_accept_idempotent(self):
        _doc("terms")
        self.api_post("/v1/legal/consent", {"accept": ["terms"]})
        self.api_post("/v1/legal/consent", {"accept": ["terms"]})
        self.assertEqual(UserConsent.objects.filter(user_id=self.uid).count(), 1)

    def test_accept_skips_unknown_type(self):
        _doc("terms")
        r = self.api_post("/v1/legal/consent", {"accept": ["terms", "nope"]})
        self.assertEqual(r.json()["recorded"], ["terms"])
        self.assertEqual(r.json()["skipped"], ["nope"])

    def test_documents_shows_accepted_flag(self):
        _doc("terms")
        self.api_post("/v1/legal/consent", {"accept": ["terms"]})
        self.assertTrue(self.api_get("/v1/legal/documents").json()[0]["accepted"])

    def test_revoke_deactivates_and_clears_flag(self):
        _doc("marketing", required=False)
        self.api_post("/v1/legal/consent", {"type": "marketing"})
        r = self.api_post("/v1/legal/consent/revoke", {"type": "marketing"})
        self.assertEqual(r.json()["revoked"], 1)
        self.assertFalse(UserConsent.objects.get(user_id=self.uid).active)
        self.assertFalse(self.api_get("/v1/legal/documents").json()[0]["accepted"])

    def test_accept_no_types_400(self):
        self.assertEqual(self.api_post("/v1/legal/consent", {}).status_code, 400)

    def test_requires_auth(self):
        self.assertEqual(self.client.post("/v1/legal/consent").status_code, 401)
        self.assertEqual(self.client.get("/v1/legal/consents").status_code, 401)
