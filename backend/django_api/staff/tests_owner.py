"""Единственный владелец (S-13).

Проверяем не «работает ли закрепление», а что его нельзя обойти: сделать себя
суперпользователем, разжаловать владельца, отобрать у него вход, подменить
закрепление через админку или сменой почты и пароля.
"""
from django.contrib.auth.models import User
from django.core.management import call_command
from django.test import TestCase, override_settings

from staff.models import OwnerPin
from staff.owner import enforce, is_owner, owner_id


class PinTests(TestCase):
    def setUp(self):
        self.owner = User.objects.create_superuser("owner", "o@t.dev", "OwnerPass!2026")

    def test_first_superuser_is_pinned_automatically(self):
        self.assertEqual(owner_id(), self.owner.pk)
        self.assertTrue(OwnerPin.objects.filter(user=self.owner).exists())

    def test_pin_survives_email_login_and_password_change(self):
        """Главное требование владельца: меняю почту, логин и пароль — остаюсь владельцем."""
        pk = self.owner.pk
        self.owner.username = "boss"
        self.owner.email = "new@mata-club.ru"
        self.owner.set_password("Another-Pass-2026")
        self.owner.save()
        self.assertEqual(owner_id(), pk)
        self.assertTrue(is_owner(User.objects.get(pk=pk)))

    def test_second_superuser_is_demoted_on_save(self):
        rogue = User.objects.create_user("rogue", "r@t.dev", "x", is_staff=True)
        rogue.is_superuser = True
        rogue.save()
        self.assertFalse(User.objects.get(pk=rogue.pk).is_superuser)

    def test_createsuperuser_does_not_create_a_second_owner(self):
        User.objects.create_superuser("second", "s@t.dev", "x")
        supers = list(User.objects.filter(is_superuser=True).values_list("pk", flat=True))
        self.assertEqual(supers, [self.owner.pk])

    def test_owner_cannot_be_demoted(self):
        self.owner.is_superuser = False
        self.owner.save()
        self.assertTrue(User.objects.get(pk=self.owner.pk).is_superuser)

    def test_owner_cannot_be_locked_out(self):
        """Снять вход у владельца нельзя: иначе он запрёт себя снаружи."""
        self.owner.is_active = False
        self.owner.is_staff = False
        self.owner.save()
        fresh = User.objects.get(pk=self.owner.pk)
        self.assertTrue(fresh.is_active)
        self.assertTrue(fresh.is_staff)

    def test_repair_cleans_flags_set_around_django(self):
        """Флаг, поставленный мимо сигналов (прямым запросом), снимается проверкой."""
        rogue = User.objects.create_user("rogue", "r@t.dev", "x", is_staff=True)
        User.objects.filter(pk=rogue.pk).update(is_superuser=True)   # сигнал не сработает
        self.assertTrue(enforce())
        self.assertFalse(User.objects.get(pk=rogue.pk).is_superuser)

    @override_settings(MATA_OWNER_ID="")
    def test_pin_is_not_reassigned_to_a_newcomer(self):
        pk = self.owner.pk
        self.owner.delete()          # закрепление уходит вместе с записью
        newcomer = User.objects.create_superuser("new", "n@t.dev", "x")
        self.assertNotEqual(newcomer.pk, pk)
        self.assertEqual(owner_id(), newcomer.pk)   # система осталась без владельца — берём первого

    def test_env_pin_wins_over_database(self):
        other = User.objects.create_user("other", "x@t.dev", "x")
        with override_settings(MATA_OWNER_ID=str(other.pk)):
            self.assertEqual(owner_id(), other.pk)
            self.assertFalse(is_owner(self.owner))

    def test_command_shows_and_repairs(self):
        call_command("mata_owner")
        call_command("mata_owner", "--repair")
        call_command("mata_owner", set_id=self.owner.pk)
        self.assertEqual(owner_id(), self.owner.pk)


class AdminSurfaceTests(TestCase):
    """Из админки суперпользователем не стать: галочек больше нет."""

    def setUp(self):
        self.owner = User.objects.create_superuser("owner", "o@t.dev", "OwnerPass!2026")
        from django_otp.plugins.otp_totp.models import TOTPDevice
        from django_otp import DEVICE_ID_SESSION_KEY
        device = TOTPDevice.objects.create(user=self.owner, name="t", confirmed=True)
        self.client.force_login(self.owner)
        session = self.client.session
        session[DEVICE_ID_SESSION_KEY] = device.persistent_id
        session.save()
        self.staff = User.objects.create_user("worker@t.dev", "worker@t.dev", "x", is_staff=True)

    def test_permission_checkboxes_are_gone_from_the_form(self):
        r = self.client.get(f"/admin/auth/user/{self.staff.pk}/change/")
        self.assertEqual(r.status_code, 200)
        for field in ("is_superuser", "is_staff", "groups", "user_permissions"):
            self.assertNotContains(r, f'name="{field}"')

    def test_posting_the_flag_by_hand_changes_nothing(self):
        """Поля нет в форме — значит и присланное значение не принимается."""
        self.client.post(f"/admin/auth/user/{self.staff.pk}/change/", {
            "username": self.staff.username, "is_superuser": "on", "is_staff": "on",
            "first_name": "", "last_name": "", "email": "worker@t.dev",
        })
        fresh = User.objects.get(pk=self.staff.pk)
        self.assertFalse(fresh.is_superuser)

    def test_creating_users_here_is_closed(self):
        self.assertEqual(self.client.get("/admin/auth/user/add/").status_code, 403)

    def test_owner_cannot_be_deleted_from_admin(self):
        r = self.client.get(f"/admin/auth/user/{self.owner.pk}/delete/")
        self.assertEqual(r.status_code, 403)

    def test_rogue_superuser_cannot_open_the_staff_tab(self):
        """Даже если флаг как-то всплыл, вкладка проверяет закреплённую запись."""
        from django_otp import DEVICE_ID_SESSION_KEY
        from django_otp.plugins.otp_totp.models import TOTPDevice

        User.objects.filter(pk=self.staff.pk).update(is_superuser=True)
        device = TOTPDevice.objects.create(user=self.staff, name="t", confirmed=True)
        self.client.force_login(self.staff)
        session = self.client.session
        session[DEVICE_ID_SESSION_KEY] = device.persistent_id
        session.save()
        self.assertEqual(self.client.get("/admin/staff/").status_code, 403)
        # И флаг снят тем же обращением.
        self.assertFalse(User.objects.get(pk=self.staff.pk).is_superuser)
