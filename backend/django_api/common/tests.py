"""Тесты страховки прод-конфигурации (fail-fast на дефолтные секреты) + launch-gate."""
import os
from unittest import mock

from django.test import SimpleTestCase, TestCase

from common.prodcheck import insecure_prod_settings

_DEV = "dev-secret-change-in-prod"
_SECURE = dict(
    debug=False,
    secret_key="x" * 50,
    jwt_secret="y" * 50,
    db_password="strong-pass",
    allowed_hosts=["api.mata-store.ru"],
)


class ProdCheckTests(SimpleTestCase):
    def test_dev_mode_never_blocks(self):
        # В dev (DEBUG=1) дефолты допустимы — список пуст.
        self.assertEqual(
            insecure_prod_settings(
                debug=True,
                secret_key=_DEV,
                jwt_secret=_DEV,
                db_password="kvartal",
                allowed_hosts=["*"],
            ),
            [],
        )

    def test_secure_prod_ok(self):
        self.assertEqual(insecure_prod_settings(**_SECURE), [])

    def test_all_defaults_flagged(self):
        bad = insecure_prod_settings(
            debug=False,
            secret_key=_DEV,
            jwt_secret=_DEV,
            db_password="kvartal",
            allowed_hosts=["*"],
        )
        self.assertEqual(
            set(bad),
            {"DJANGO_SECRET_KEY", "JWT_SECRET", "POSTGRES_PASSWORD",
             "DJANGO_ALLOWED_HOSTS"},
        )

    def test_single_default_flagged(self):
        bad = insecure_prod_settings(**{**_SECURE, "jwt_secret": _DEV})
        self.assertEqual(bad, ["JWT_SECRET"])

    def test_wildcard_allowed_hosts_flagged(self):
        bad = insecure_prod_settings(**{**_SECURE, "allowed_hosts": ["mata-store.ru", "*"]})
        self.assertEqual(bad, ["DJANGO_ALLOWED_HOSTS"])


class LaunchReadinessTests(SimpleTestCase):
    """Отчёт готовности к запуску: интеграции dev→no-op, включаются ключами (D-30 арк 2)."""

    def _by_key(self, items, key):
        return next(i for i in items if i["key"] == key)

    @mock.patch.dict(os.environ, {}, clear=True)
    def test_integrations_dev_all_not_ready(self):
        from common.launch import integrations

        self.assertTrue(all(not i["ready"] for i in integrations()))

    @mock.patch.dict(
        os.environ,
        {"SMS_PROVIDER": "smsc", "SMS_LOGIN": "l", "SMS_PASSWORD": "p"},
        clear=True,
    )
    def test_sms_ready_when_provider_and_keys(self):
        from common.launch import integrations

        self.assertTrue(self._by_key(integrations(), "sms")["ready"])

    @mock.patch.dict(os.environ, {"SMS_PROVIDER": "smsc"}, clear=True)
    def test_sms_not_ready_provider_without_keys(self):
        from common.launch import integrations

        self.assertFalse(self._by_key(integrations(), "sms")["ready"])

    @mock.patch.dict(os.environ, {"REDIS_URL": "redis://x:6379/0"}, clear=True)
    def test_infra_redis_ready_with_url(self):
        from common.launch import infra

        self.assertTrue(self._by_key(infra(), "redis")["ready"])

    @mock.patch.dict(os.environ, {}, clear=True)
    def test_infra_media_local_not_ready(self):
        from common.launch import infra

        self.assertFalse(self._by_key(infra(), "media")["ready"])  # локальный диск — не прод

    @mock.patch.dict(
        os.environ,
        {"MEDIA_S3_BUCKET": "b", "MEDIA_S3_ACCESS_KEY": "a", "MEDIA_S3_SECRET_KEY": "s"},
        clear=True,
    )
    def test_infra_media_ready_with_s3(self):
        from common.launch import infra

        self.assertTrue(self._by_key(infra(), "media")["ready"])

    @mock.patch.dict(os.environ, {}, clear=True)
    def test_security_dev_mode_no_blockers(self):
        from common.launch import security

        sec = security()
        self.assertFalse(sec["prodMode"])  # DEBUG по умолчанию dev
        self.assertEqual(sec["insecure"], [])


class MediaStorageTests(SimpleTestCase):
    """Выбор хранилища медиа (D-31): S3 при ключах, иначе локальный диск (dev/CI)."""

    def test_local_when_no_s3_env(self):
        from common.media import media_backend_kind, media_storages

        st = media_storages({})
        self.assertIn("FileSystemStorage", st["default"]["BACKEND"])
        self.assertEqual(media_backend_kind({}), "local")

    def test_s3_when_fully_configured(self):
        from common.media import media_backend_kind, media_storages

        env = {"MEDIA_S3_BUCKET": "b", "MEDIA_S3_ACCESS_KEY": "a", "MEDIA_S3_SECRET_KEY": "s"}
        st = media_storages(env)
        self.assertIn("s3", st["default"]["BACKEND"].lower())
        self.assertEqual(st["default"]["OPTIONS"]["bucket_name"], "b")
        self.assertFalse(st["default"]["OPTIONS"]["querystring_auth"])  # публичные URL
        self.assertEqual(media_backend_kind(env), "s3")

    def test_partial_s3_env_falls_back_local(self):
        from common.media import media_storages

        # Есть бакет, но нет ключей → безопасный откат на локальный диск, не падаем.
        st = media_storages({"MEDIA_S3_BUCKET": "b"})
        self.assertIn("FileSystemStorage", st["default"]["BACKEND"])

    def test_custom_domain_applied(self):
        from common.media import media_storages

        env = {
            "MEDIA_S3_BUCKET": "b", "MEDIA_S3_ACCESS_KEY": "a", "MEDIA_S3_SECRET_KEY": "s",
            "MEDIA_S3_CUSTOM_DOMAIN": "cdn.mata-store.ru",
        }
        self.assertEqual(
            media_storages(env)["default"]["OPTIONS"]["custom_domain"], "cdn.mata-store.ru"
        )


class LegalGateTests(TestCase):
    """Launch-gate по юр-документам: обязательные должны быть опубликованы."""

    def test_missing_required_unpublished(self):
        from django.utils import timezone

        from common.launch import legal_gate
        from legal.models import LegalDocument

        LegalDocument.objects.create(
            doc_type="terms", version="1.0", title="T", is_required=True,
            published_at=timezone.now(),
        )
        LegalDocument.objects.create(
            doc_type="privacy", version="1.0", title="P", is_required=True,
            published_at=None,  # черновик
        )
        gate = legal_gate()
        self.assertIn("privacy", gate["missing"])
        self.assertFalse(gate["ok"])

    def test_ok_when_all_required_published(self):
        from django.utils import timezone

        from common.launch import legal_gate
        from legal.models import LegalDocument

        LegalDocument.objects.create(
            doc_type="terms", version="1.0", title="T", is_required=True,
            published_at=timezone.now(),
        )
        gate = legal_gate()
        self.assertEqual(gate["missing"], [])
        self.assertTrue(gate["ok"])
