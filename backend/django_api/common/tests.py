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


class ThrottleScopeTests(TestCase):
    """Лимит зависит от назначения эндпоинта (D-36): витринное чтение щедрое,
    вход и запись — без послаблений."""

    def setUp(self):
        from django.core.cache import cache

        cache.clear()  # счётчики лимитов живут в кэше — иначе тесты штрафуют друг друга

    def _drf_request(self, method, path="/v1/products"):
        from rest_framework.request import Request
        from rest_framework.test import APIRequestFactory

        return Request(getattr(APIRequestFactory(), method.lower())(path))

    def test_catalog_read_survives_burst_that_old_limit_would_block(self):
        """150 анонимных чтений каталога подряд — ни одного 429.

        Прежний общий лимит для анонимных (120/мин) резал витрину: за одним IP
        оператора сидят сотни абонентов, а просмотр каталога — 10–20 запросов.
        """
        codes = {self.client.get("/v1/products").status_code for _ in range(150)}
        self.assertEqual(codes, {200})

    def test_login_still_strictly_throttled(self):
        """Вход остаётся под жёстким лимитом 20/мин — послабление витрины его не касается."""
        import json

        seen = set()
        for i in range(25):
            r = self.client.post(
                "/v1/auth/phone/verify",
                data=json.dumps({"phone": f"+7999000{i:04d}", "code": "1234"}),
                content_type="application/json",
            )
            seen.add(r.status_code)
        self.assertIn(429, seen)

    def test_public_scope_counts_reads_only(self):
        """Запись на витринном URL (например, отзыв к товару) в щедрый scope не попадает."""
        from common.throttling import PublicReadThrottle

        t = PublicReadThrottle()
        self.assertIsNotNone(t.get_cache_key(self._drf_request("get"), None))
        self.assertIsNone(t.get_cache_key(self._drf_request("post"), None))

    def test_write_throttles_skip_reads(self):
        """И наоборот: обычные лимиты на смешанной вьюхе не считают чтение дважды."""
        from common.throttling import WriteAnonIPRateThrottle

        t = WriteAnonIPRateThrottle()
        self.assertIsNone(t.get_cache_key(self._drf_request("get"), None))
        self.assertIsNotNone(t.get_cache_key(self._drf_request("post"), None))


class AdminLoginThrottleTests(TestCase):
    """Форма входа в админку прикрыта от перебора (D-39).

    Лимиты DRF живут в DRF-вью и админку не покрывают: до этого `/admin/login/`
    можно было перебирать без ограничений, а за админкой деньги и ПДн.
    """

    PASSWORD = "very-strong-pass-123"

    def setUp(self):
        from django.contrib.auth import get_user_model
        from django.core.cache import cache

        cache.clear()  # счётчик попыток живёт в кэше
        get_user_model().objects.create_superuser(
            "root-test", "root@test.local", self.PASSWORD
        )

    def _login(self, password, ip="203.0.113.7"):
        return self.client.post(
            "/admin/login/",
            {"username": "root-test", "password": password},
            HTTP_X_REAL_IP=ip,
        )

    def test_blocks_after_limit_even_with_correct_password(self):
        from common.adminsec import MAX_FAILS

        for _ in range(MAX_FAILS):
            self._login("wrong")
        # Ключевое: подобравший пароль на этом IP уже не войдёт до конца окна.
        self.assertEqual(self._login(self.PASSWORD).status_code, 429)

    def test_limit_is_per_ip(self):
        from common.adminsec import MAX_FAILS

        for _ in range(MAX_FAILS):
            self._login("wrong", ip="203.0.113.7")
        # Чужой IP не должен страдать из-за перебора с соседнего.
        self.assertNotEqual(self._login("wrong", ip="203.0.113.8").status_code, 429)

    def test_successful_login_resets_counter(self):
        from common.adminsec import MAX_FAILS

        for _ in range(MAX_FAILS - 1):
            self._login("wrong")
        self._login(self.PASSWORD)  # удачный вход обнуляет счётчик
        self.client.logout()
        r = None
        for _ in range(MAX_FAILS - 1):
            r = self._login("wrong")
        self.assertNotEqual(r.status_code, 429)


class AdminTwoFactorTests(TestCase):
    """Второй шаг входа в админку (D-49)."""

    PASSWORD = "strong-pass-12345"

    def setUp(self):
        from django.contrib.auth import get_user_model

        self.user = get_user_model().objects.create_superuser(
            "otp_admin", "otp@t.dev", self.PASSWORD
        )
        self.client.login(username="otp_admin", password=self.PASSWORD)

    def _enroll(self):
        from django_otp.plugins.otp_totp.models import TOTPDevice

        return TOTPDevice.objects.create(user=self.user, name="test", confirmed=True)

    def test_without_device_admin_works_as_before(self):
        """Нельзя запереть админа, который ещё не подключил второй фактор."""
        self.assertEqual(self.client.get("/admin/").status_code, 200)

    def test_with_device_admin_redirects_to_second_step(self):
        self._enroll()
        r = self.client.get("/admin/")
        self.assertEqual(r.status_code, 302)
        self.assertTrue(r["Location"].startswith("/admin/2fa/"))

    def test_wrong_code_does_not_pass(self):
        self._enroll()
        r = self.client.post("/admin/2fa/", {"token": "000000", "next": "/admin/"})
        self.assertEqual(r.status_code, 200)
        self.assertEqual(self.client.get("/admin/").status_code, 302)

    def test_valid_code_opens_admin(self):
        device = self._enroll()
        from django_otp.oath import totp

        token = totp(device.bin_key, device.step, device.t0, device.digits, device.drift)
        r = self.client.post(
            "/admin/2fa/", {"token": f"{token:0{device.digits}d}", "next": "/admin/"}
        )
        self.assertEqual(r.status_code, 302)
        self.assertEqual(self.client.get("/admin/").status_code, 200)

    def test_pause_after_wrong_code_is_explained(self):
        """django-otp после ошибки отклоняет даже верный код — это надо сказать словами."""
        device = self._enroll()
        from django_otp.oath import totp

        self.client.post("/admin/2fa/", {"token": "000000"})
        token = totp(device.bin_key, device.step, device.t0, device.digits, device.drift)
        r = self.client.post("/admin/2fa/", {"token": f"{token:0{device.digits}d}"})
        self.assertContains(r, "Слишком много попыток")

    def test_backup_code_works_once(self):
        from django_otp.plugins.otp_static.models import StaticDevice, StaticToken

        self._enroll()
        static = StaticDevice.objects.create(user=self.user, name="backup", confirmed=True)
        StaticToken.objects.create(device=static, token="rescue42")

        self.assertEqual(
            self.client.post("/admin/2fa/", {"token": "rescue42"}).status_code, 302
        )
        self.assertEqual(self.client.get("/admin/").status_code, 200)
        # Повторное использование того же кода не должно работать.
        self.assertFalse(StaticToken.objects.filter(token="rescue42").exists())

    def test_logout_is_reachable_before_verification(self):
        """Иначе на втором шаге нельзя было бы даже сменить аккаунт."""
        self._enroll()
        self.assertNotEqual(self.client.get("/admin/logout/").status_code, 302)

    def test_launch_report_lists_admins_without_2fa(self):
        from common.launch import admin_access

        self.assertIn("otp_admin", admin_access()["usersWithout2fa"])
        self._enroll()
        self.assertNotIn("otp_admin", admin_access()["usersWithout2fa"])
