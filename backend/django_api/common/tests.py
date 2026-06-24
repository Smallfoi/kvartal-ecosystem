"""Тесты страховки прод-конфигурации (fail-fast на дефолтные секреты)."""
from django.test import SimpleTestCase

from common.prodcheck import insecure_prod_settings

_DEV = "dev-secret-change-in-prod"
_SECURE = dict(
    debug=False,
    secret_key="x" * 50,
    jwt_secret="y" * 50,
    db_password="strong-pass",
    allowed_hosts=["api.staw.ru"],
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
        bad = insecure_prod_settings(**{**_SECURE, "allowed_hosts": ["staw.ru", "*"]})
        self.assertEqual(bad, ["DJANGO_ALLOWED_HOSTS"])
