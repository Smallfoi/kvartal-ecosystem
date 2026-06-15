import secrets

from django.db import models
from django.utils import timezone


class LoyaltyTransaction(models.Model):
    """Транзакция баллов — те же поля, что в FastAPI loyalty_transactions."""
    id = models.CharField(primary_key=True, max_length=40)
    user_id = models.CharField(max_length=40, db_index=True)
    amount = models.IntegerField()
    source = models.CharField(max_length=40)
    description = models.CharField(max_length=300, blank=True, default="")
    order_id = models.CharField(max_length=40, null=True, blank=True)
    run_id = models.CharField(max_length=80, null=True, blank=True)
    created_at = models.DateTimeField(default=timezone.now)

    class Meta:
        db_table = "loyalty_transactions"

    def to_json(self) -> dict:
        return {
            "id": self.id,
            "amount": self.amount,
            "source": self.source,
            "description": self.description,
            "orderId": self.order_id,
            "createdAt": self.created_at.isoformat(),
        }


def add_txn(user_id, amount, source, description="", order_id=None, run_id=None):
    return LoyaltyTransaction.objects.create(
        id=f"tx_{secrets.token_hex(8)}",
        user_id=user_id,
        amount=amount,
        source=source,
        description=description,
        order_id=order_id,
        run_id=run_id,
    )


def seed_runner_points(user_id):
    """Демо-баллы «из Квартала» при создании пользователя (как в FastAPI)."""
    demo = [
        (20, "registration", "Бонус за регистрацию"),
        (120, "runnerRun", "Пробежка 12.0 км"),
        (50, "runnerTerritory", "Захват территории: ул. Спортивная"),
        (200, "runnerCompetition", "Победа в забеге «Весенний круг»"),
        (40, "runnerRun", "Пробежка 4.0 км"),
    ]
    for amount, source, desc in demo:
        add_txn(user_id, amount, source, desc)


def level_for(balance: int) -> str:
    if balance >= 1000:
        return "platinum"
    if balance >= 500:
        return "gold"
    if balance >= 200:
        return "silver"
    return "basic"
