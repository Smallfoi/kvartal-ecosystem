"""Полнота удаления аккаунта (152-ФЗ) + команда чистки осиротевших данных."""
from io import StringIO

from django.core.management import call_command
from django.utils import timezone

from accounts.models import Account
from common.testutils import ApiTestCase
from loyalty.models import LoyaltyTransaction, add_txn
from runs.models import Run


class AccountDeletionTests(ApiTestCase):
    phone = "+79990004050"

    def test_delete_account_purges_runs_and_loyalty(self):
        add_txn(self.uid, 100, "runnerRun", "Пробежка 10 км")
        Run.objects.create(
            id="r_del_1", user_id=self.uid, distance_m=10000,
            duration_s=3600, finished_at=timezone.now(),
        )
        r = self.api_post("/v1/account/delete", {"confirm": True})
        self.assertEqual(r.status_code, 200)
        self.assertFalse(Account.objects.filter(id=self.uid).exists())
        # Раньше Run оставался осиротевшим — теперь чистится (GPS-история = ПДн).
        self.assertFalse(Run.objects.filter(user_id=self.uid).exists())
        self.assertFalse(LoyaltyTransaction.objects.filter(user_id=self.uid).exists())

    def test_delete_requires_confirm(self):
        r = self.api_post("/v1/account/delete", {})
        self.assertEqual(r.status_code, 400)


class CleanOrphansCommandTests(ApiTestCase):
    phone = "+79990004051"

    def test_removes_orphans_keeps_valid(self):
        # Данные несуществующего аккаунта (как после прямого удаления Account в обход API).
        add_txn("ghost_user", 160, "runnerRun", "Пробежка 16 км")
        Run.objects.create(
            id="r_ghost", user_id="ghost_user", distance_m=16000,
            duration_s=3600, finished_at=timezone.now(),
        )
        # Валидные данные текущего пользователя — трогать нельзя.
        add_txn(self.uid, 50, "runnerRun", "Пробежка 5 км")

        out = StringIO()
        call_command("clean_orphans", stdout=out)  # dry-run — ничего не удаляет
        self.assertTrue(LoyaltyTransaction.objects.filter(user_id="ghost_user").exists())

        call_command("clean_orphans", "--apply", stdout=out)  # удаляет только сирот
        self.assertFalse(LoyaltyTransaction.objects.filter(user_id="ghost_user").exists())
        self.assertFalse(Run.objects.filter(user_id="ghost_user").exists())
        self.assertTrue(LoyaltyTransaction.objects.filter(user_id=self.uid).exists())
