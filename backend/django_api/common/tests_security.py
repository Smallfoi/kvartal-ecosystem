"""Попытки сломать вход и админку (D-68).

Это не проверка «работает ли» — это проверка «не работает ли то, что не должно».
Каждый тест здесь воспроизводит конкретную атаку: обойти второй фактор, подделать
сессию, увести администратора на чужой сайт, перебрать код, подставить чужой
идентификатор, подделать токен, дописать себе прав.

Тесты стоят ровно там, где я эти дыры искал руками, — чтобы найденное однажды
не вернулось следующей правкой.
"""
import json
import time

from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.test import TestCase
from django.urls import reverse

from common.security import JWT_SECRET, make_token

# Все страницы админки, живущие мимо ModelAdmin: их гейтит не Django, а наши
# декораторы и middleware, поэтому каждую проверяем отдельно.
CUSTOM_ADMIN_PAGES = [
    "/admin/", "/admin/merch/", "/admin/errors/", "/admin/storage/",
    "/admin/1c-log/", "/admin/runs-review/", "/admin/staff/",
    "/admin/merch/products", "/admin/merch/banners",
]


def _device(user, confirmed=True):
    from django_otp.plugins.otp_totp.models import TOTPDevice

    return TOTPDevice.objects.create(user=user, name="test", confirmed=confirmed)


class SecondFactorCannotBeBypassed(TestCase):
    """Второй фактор обязателен: обойти его нельзя ни адресом, ни сессией."""

    PASSWORD = "strong-pass-12345"

    def setUp(self):
        cache.clear()
        User = get_user_model()
        self.owner = User.objects.create_superuser("sec_owner", "o@t.dev", self.PASSWORD)
        self.other = User.objects.create_user("sec_other", "x@t.dev", self.PASSWORD,
                                              is_staff=True)
        self.client.login(username="sec_owner", password=self.PASSWORD)

    def test_every_admin_page_is_closed_without_device(self):
        """Ни одна страница не должна открыться, пока фактор не привязан."""
        for path in CUSTOM_ADMIN_PAGES:
            with self.subTest(path=path):
                r = self.client.get(path)
                self.assertEqual(r.status_code, 302, f"{path} открылась без фактора")
                self.assertTrue(r["Location"].startswith("/admin/2fa/"),
                                f"{path} увела не на второй фактор: {r['Location']}")

    def test_every_admin_page_is_closed_with_device_but_unverified(self):
        """Устройство есть, код не введён — тоже мимо."""
        _device(self.owner)
        for path in CUSTOM_ADMIN_PAGES:
            with self.subTest(path=path):
                r = self.client.get(path)
                self.assertEqual(r.status_code, 302, f"{path} открылась без кода")
                self.assertTrue(r["Location"].startswith("/admin/2fa/"))

    def test_post_is_gated_too(self):
        """Гейт не должен зависеть от метода: POST мимо GET-проверки не проскочит."""
        _device(self.owner)
        r = self.client.post("/admin/merch/products", {})
        self.assertEqual(r.status_code, 302)
        self.assertTrue(r["Location"].startswith("/admin/2fa/"))

    def test_path_tricks_do_not_slip_past_the_gate(self):
        """Двойные слеши и точки не должны выводить путь из-под проверки."""
        _device(self.owner)
        for path in ["//admin/", "/admin//", "/admin/./", "/admin/merch/../"]:
            with self.subTest(path=path):
                r = self.client.get(path)
                # Либо гейт, либо 404/301 — но НЕ 200 с содержимым админки.
                self.assertNotEqual(r.status_code, 200, f"{path} отдала страницу")

    def test_session_forged_with_someone_elses_device_does_not_verify(self):
        """Подстановка чужого устройства в свою сессию — не подтверждение.

        Именно этот класс атаки владелец просил проверить: «подменил номер
        пользователя — получил чужой доступ». django-otp сверяет владельца
        устройства с текущим пользователем; проверяем, что так и есть.
        """
        from django_otp import DEVICE_ID_SESSION_KEY

        victim_device = _device(self.other)
        _device(self.owner)
        session = self.client.session
        session[DEVICE_ID_SESSION_KEY] = victim_device.persistent_id
        session.save()

        r = self.client.get("/admin/")
        self.assertEqual(r.status_code, 302)
        self.assertTrue(r["Location"].startswith("/admin/2fa/"))

    def test_setup_page_binds_only_to_self(self):
        """Страница привязки не принимает чужой идентификатор ни в каком виде."""
        from django_otp.plugins.otp_totp.models import TOTPDevice

        self.client.post("/admin/2fa/setup/", {"code": "000000",
                                               "user": self.other.pk,
                                               "user_id": self.other.pk})
        self.assertFalse(TOTPDevice.objects.filter(user=self.other).exists())


class OpenRedirectIsClosed(TestCase):
    """`?next=` не должен уводить с нашего домена (фишинг на своей же ссылке)."""

    PASSWORD = "strong-pass-12345"

    def setUp(self):
        cache.clear()
        User = get_user_model()
        self.user = User.objects.create_superuser("red_owner", "r@t.dev", self.PASSWORD)
        self.device = _device(self.user)
        self.client.login(username="red_owner", password=self.PASSWORD)

    def _code(self):
        from django_otp.oath import totp

        d = self.device
        return f"{totp(d.bin_key, d.step, d.t0, d.digits, d.drift):06d}"

    def test_external_next_is_refused_by_the_check(self):
        """Все формы чужого адреса, включая схемы-обманки, отбрасываются."""
        from common.admin2fa import safe_next

        evil = [
            "https://evil.example",
            "//evil.example",
            "http://evil.example/x",
            "https:/" + chr(92) + "evil.example",
            chr(92) * 2 + "evil.example",
            "javascript:alert(1)",
            "  //evil.example",
        ]
        for candidate in evil:
            with self.subTest(next=candidate):
                self.assertEqual(safe_next(candidate), "/admin/",
                                 "пропустили чужой адрес: %r" % candidate)

    def test_external_next_is_ignored_after_successful_code(self):
        """Сквозная проверка: ввели верный код с чужим next — остались у себя."""
        r = self.client.post("/admin/2fa/", {"token": self._code(),
                                             "next": "https://evil.example"})
        self.assertEqual(r.status_code, 302)
        self.assertEqual(r["Location"], "/admin/")


    def test_internal_next_still_works(self):
        r = self.client.post("/admin/2fa/", {"token": self._code(),
                                             "next": "/admin/1c-log/"})
        self.assertEqual(r["Location"], "/admin/1c-log/")


class CodeCannotBeBruteForced(TestCase):
    """Шестизначный код: перебор упирается в общий по человеку лимит."""

    PASSWORD = "strong-pass-12345"

    def setUp(self):
        cache.clear()
        User = get_user_model()
        self.user = User.objects.create_superuser("bf_owner", "b@t.dev", self.PASSWORD)
        self.device = _device(self.user)
        self.client.login(username="bf_owner", password=self.PASSWORD)

    def test_locks_after_a_few_wrong_codes(self):
        from common.admin2fa import OTP_MAX_FAILS

        for _ in range(OTP_MAX_FAILS):
            self.client.post("/admin/2fa/", {"token": "000000", "next": "/admin/"})

        # Даже верный код теперь не проходит — пауза общая, а не пер-девайсная.
        from django_otp.oath import totp

        d = self.device
        good = f"{totp(d.bin_key, d.step, d.t0, d.digits, d.drift):06d}"
        r = self.client.post("/admin/2fa/", {"token": good, "next": "/admin/"})
        self.assertEqual(r.status_code, 200)          # остались на странице кода
        self.assertEqual(self.client.get("/admin/").status_code, 302)

    def test_failed_code_is_written_to_the_journal(self):
        """Промах по коду — это либо сбой времени, либо чужой с нашим паролем."""
        from staff.models import StaffAudit

        r = self.client.post("/admin/2fa/", {"token": "000000", "next": "/admin/"})
        assert r.status_code == 200, ("не дошли до второго шага: %s -> %s"
                                      % (r.status_code, r.get("Location")))
        actions = list(StaffAudit.objects.values_list("action", flat=True))
        self.assertTrue(any("фактор" in a for a in actions),
                        "в журнале нет записи о промахе: %r" % actions)


class TokenCannotBeForged(TestCase):
    """Токен API: подпись, срок и чужой идентификатор."""

    def setUp(self):
        cache.clear()
        from accounts.models import Account

        self.a = Account.objects.create(id="u_sec_a", email="a@sec.dev", name="A")
        self.b = Account.objects.create(id="u_sec_b", email="b@sec.dev", name="B")

    def _get(self, path, token):
        return self.client.get(path, HTTP_AUTHORIZATION=f"Bearer {token}")

    def test_no_token_is_rejected(self):
        self.assertEqual(self.client.get("/v1/me/stats").status_code, 401)

    def test_tampered_signature_is_rejected(self):
        token = make_token("u_sec_a")
        head, payload, sig = token.split(".")
        broken = f"{head}.{payload}.{sig[:-2]}xx"
        self.assertEqual(self._get("/v1/me/stats", broken).status_code, 401)

    def test_alg_none_is_rejected(self):
        """Классика: подменить алгоритм на «none» и остаться без подписи."""
        import base64

        def b64(d):
            return base64.urlsafe_b64encode(json.dumps(d).encode()).rstrip(b"=").decode()

        forged = (b64({"alg": "none", "typ": "JWT"})
                  + "." + b64({"sub": "u_sec_b", "exp": int(time.time()) + 3600}) + ".")
        self.assertEqual(self._get("/v1/me/stats", forged).status_code, 401)

    def test_payload_swap_without_resigning_is_rejected(self):
        """Взять свой валидный токен и переписать в нём чужой id."""
        import base64

        token = make_token("u_sec_a")
        head, _, sig = token.split(".")
        other = base64.urlsafe_b64encode(
            json.dumps({"sub": "u_sec_b", "exp": int(time.time()) + 3600}).encode()
        ).rstrip(b"=").decode()
        self.assertEqual(self._get("/v1/me/stats", f"{head}.{other}.{sig}").status_code, 401)

    def test_expired_token_is_rejected(self):
        import base64
        import hashlib
        import hmac

        def b64(d):
            return base64.urlsafe_b64encode(json.dumps(d).encode()).rstrip(b"=").decode()

        head = b64({"alg": "HS256", "typ": "JWT"})
        payload = b64({"sub": "u_sec_a", "exp": int(time.time()) - 10})
        sig = base64.urlsafe_b64encode(
            hmac.new(JWT_SECRET.encode(), f"{head}.{payload}".encode(), hashlib.sha256).digest()
        ).rstrip(b"=").decode()
        self.assertEqual(self._get("/v1/me/stats", f"{head}.{payload}.{sig}").status_code, 401)

    def test_blocked_account_loses_access_immediately(self):
        from accounts.models import Account

        token = make_token("u_sec_a")
        self.assertEqual(self._get("/v1/me/stats", token).status_code, 200)
        Account.objects.filter(id="u_sec_a").update(is_blocked=True)
        cache.clear()   # мгновенный бан не должен зависеть от прогрева кэша
        self.assertEqual(self._get("/v1/me/stats", token).status_code, 401)


class StaffCannotEscalate(TestCase):
    """Сотрудник не должен дописать себе прав через формы админки."""

    PASSWORD = "strong-pass-12345"

    def setUp(self):
        cache.clear()
        from staff.models import StaffProfile

        User = get_user_model()
        self.owner = User.objects.create_superuser("esc_owner", "o@e.dev", self.PASSWORD)
        self.staff = User.objects.create_user("esc_staff", "s@e.dev", self.PASSWORD,
                                              is_staff=True)
        StaffProfile.objects.create(user=self.staff, full_name="Сотрудник")
        self._verify(self.staff)

    def _verify(self, user):
        from django_otp import DEVICE_ID_SESSION_KEY

        device = _device(user)
        self.client.force_login(user)
        session = self.client.session
        session[DEVICE_ID_SESSION_KEY] = device.persistent_id
        session.save()

    def test_staff_tab_is_owner_only(self):
        for path in ["/admin/staff/", "/admin/staff/create",
                     f"/admin/staff/{self.owner.pk}/",
                     f"/admin/staff/{self.staff.pk}/rights"]:
            with self.subTest(path=path):
                r = self.client.get(path)
                self.assertIn(r.status_code, (403, 302),
                              f"{path} открылась сотруднику")

    def test_posting_superuser_flag_into_user_form_does_nothing(self):
        """Блок прав убран из формы — присланное вручную значение игнорируется."""
        url = reverse("admin:auth_user_change", args=[self.staff.pk])
        self.client.post(url, {
            "username": "esc_staff", "email": "s@e.dev",
            "first_name": "", "last_name": "",
            "is_superuser": "on", "is_staff": "on", "is_active": "on",
            "date_joined_0": "2026-01-01", "date_joined_1": "00:00:00",
        })
        self.staff.refresh_from_db()
        self.assertFalse(self.staff.is_superuser, "сотрудник стал суперпользователем")


class OneCEndpointIsClosed(TestCase):
    """Приём из 1С ходит по постоянному токену — значит токен обязан проверяться."""

    def setUp(self):
        cache.clear()

    def test_without_token_rejected(self):
        r = self.client.post("/v1/integrations/1c/catalog", data="{}", content_type="application/json")
        self.assertEqual(r.status_code, 401)

    def test_wrong_token_rejected(self):
        r = self.client.post("/v1/integrations/1c/catalog", data="{}", content_type="application/json",
                             HTTP_AUTHORIZATION="Bearer definitely-not-the-token")
        self.assertEqual(r.status_code, 401)


class SelfServiceTwoFactor(TestCase):
    """Управление своим вторым фактором (D-69): смена устройства и запасные коды.

    Главная угроза здесь не «неудобно», а «перехватили сессию». Если сменить
    устройство можно без подтверждения текущим фактором, то укравший сессию
    перепривязывает фактор на свой телефон и запирает владельца навсегда.
    Поэтому каждое действие требует кода — из приложения или запасного.
    """

    URL = "/admin/account/security/"
    PASSWORD = "strong-pass-12345"

    def setUp(self):
        cache.clear()
        User = get_user_model()
        self.user = User.objects.create_superuser("ss_owner", "s@t.dev", self.PASSWORD)
        self.device = _device(self.user)
        self.client.login(username="ss_owner", password=self.PASSWORD)
        self._verify()

    def _verify(self):
        from django_otp import DEVICE_ID_SESSION_KEY

        session = self.client.session
        session[DEVICE_ID_SESSION_KEY] = self.device.persistent_id
        session.save()

    def _code(self):
        from django_otp.oath import totp

        d = self.device
        return f"{totp(d.bin_key, d.step, d.t0, d.digits, d.drift):06d}"

    def _backup_codes(self):
        from staff.views import _issue_backup_codes

        return _issue_backup_codes(self.user)

    def test_page_opens_for_verified_user(self):
        r = self.client.get(self.URL)
        self.assertEqual(r.status_code, 200)
        self.assertIn("Второй фактор", r.content.decode())

    def test_page_is_not_under_the_open_2fa_prefix(self):
        """Страница обязана быть ВНЕ /admin/2fa/ — тот префикс пропускает без кода."""
        from common.admin2fa import _ALLOWED

        self.assertFalse(self.URL.startswith(_ALLOWED),
                         "страница управления попала под открытый префикс")

    def test_unverified_session_cannot_open_it(self):
        """Не ввёл код при входе — управлять фактором нельзя."""
        from django_otp import DEVICE_ID_SESSION_KEY

        session = self.client.session
        del session[DEVICE_ID_SESSION_KEY]
        session.save()
        r = self.client.get(self.URL)
        self.assertEqual(r.status_code, 302)
        self.assertTrue(r["Location"].startswith("/admin/2fa/"))

    def test_rotate_without_code_is_refused(self):
        """Перехваченная сессия не должна перепривязать фактор на чужой телефон."""
        from django_otp.plugins.otp_totp.models import TOTPDevice

        r = self.client.post(self.URL, {"action": "rotate_device", "code": ""})
        self.assertEqual(r.status_code, 200)
        self.assertTrue(TOTPDevice.objects.filter(user=self.user, confirmed=True).exists())

    def test_rotate_with_wrong_code_is_refused(self):
        from django_otp.plugins.otp_totp.models import TOTPDevice

        r = self.client.post(self.URL, {"action": "rotate_device", "code": "000000"})
        self.assertEqual(r.status_code, 200)
        self.assertIn("не подошёл", r.content.decode())
        self.assertTrue(TOTPDevice.objects.filter(user=self.user, confirmed=True).exists())

    def test_rotate_with_valid_code_sends_to_setup(self):
        from django_otp.plugins.otp_totp.models import TOTPDevice

        r = self.client.post(self.URL, {"action": "rotate_device", "code": self._code()})
        self.assertEqual(r.status_code, 302)
        self.assertEqual(r["Location"], "/admin/2fa/setup/")
        self.assertFalse(TOTPDevice.objects.filter(user=self.user).exists())

    def test_backup_code_works_when_phone_is_lost(self):
        """Телефона нет — именно для этого случая и нужны запасные коды."""
        from django_otp.plugins.otp_totp.models import TOTPDevice

        codes = self._backup_codes()
        r = self.client.post(self.URL, {"action": "rotate_device", "code": codes[0]})
        self.assertEqual(r.status_code, 302)
        self.assertFalse(TOTPDevice.objects.filter(user=self.user).exists())

    def test_new_codes_refused_without_valid_code(self):
        from django_otp.plugins.otp_static.models import StaticToken

        old = self._backup_codes()
        r = self.client.post(self.URL, {"action": "new_codes", "code": "000000"})
        self.assertEqual(r.status_code, 200)
        self.assertTrue(StaticToken.objects.filter(token=old[0]).exists(),
                        "коды перевыпустились без подтверждения")

    def test_new_codes_replace_old_ones(self):
        """Отдельным тестом: после неверной попытки django-otp держит паузу,
        и верный код в том же тесте честно не прошёл бы."""
        from django_otp.plugins.otp_static.models import StaticToken

        old = self._backup_codes()
        r = self.client.post(self.URL, {"action": "new_codes", "code": self._code()},
                             follow=True)
        self.assertEqual(r.status_code, 200)
        self.assertFalse(StaticToken.objects.filter(token=old[0]).exists(),
                         "старые запасные коды продолжают работать")
        self.assertIn("Новые запасные коды", r.content.decode())

    def test_changes_are_written_to_the_journal(self):
        from staff.models import StaffAudit

        self.client.post(self.URL, {"action": "new_codes", "code": self._code()})
        self.assertTrue(
            StaffAudit.objects.filter(action__contains="запасных кодов").exists())
