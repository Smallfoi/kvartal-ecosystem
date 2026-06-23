from rest_framework.decorators import api_view
from rest_framework.response import Response

from common.security import user_id_from_request

from .models import LoyaltyTransaction, add_txn, level_for


@api_view(["GET"])
def account(request):
    uid = user_id_from_request(request)
    if not uid:
        return Response({"detail": "Нет токена"}, status=401)
    rows = list(LoyaltyTransaction.objects.filter(user_id=uid).order_by("-created_at"))
    balance = sum(r.amount for r in rows)
    return Response(
        {
            "balance": balance,
            "level": level_for(balance),
            "transactions": [r.to_json() for r in rows],
        }
    )


@api_view(["POST"])
def redeem(request):
    """Серверная трата баллов (Store-чекаут). Авторитетно проверяет баланс и
    идемпотентна по orderId — нельзя уйти в минус и нельзя списать дважды.
    body: {amount: >0, orderId, description}."""
    uid = user_id_from_request(request)
    if not uid:
        return Response({"detail": "Нет токена"}, status=401)
    d = request.data
    try:
        amount = int(d.get("amount") or 0)
    except (TypeError, ValueError):
        amount = 0
    if amount <= 0:
        return Response({"detail": "Некорректное количество баллов"}, status=400)

    rows = list(LoyaltyTransaction.objects.filter(user_id=uid))
    balance = sum(r.amount for r in rows)
    order_id = d.get("orderId")

    # Идемпотентность: повторный redeem того же заказа не списывает второй раз.
    if order_id:
        dup = next(
            (r for r in rows if r.order_id == order_id and r.source == "redeem"),
            None,
        )
        if dup:
            return Response(
                {"ok": True, "deduped": True, "balance": balance, "spent": -dup.amount}
            )

    if amount > balance:
        return Response(
            {"detail": "Недостаточно баллов", "balance": balance}, status=400
        )

    add_txn(uid, -amount, "redeem", d.get("description") or "Оплата баллами", order_id)
    new_balance = balance - amount
    return Response(
        {"ok": True, "balance": new_balance, "spent": amount, "level": level_for(new_balance)}
    )


# Источники, которые СЕРВЕР начисляет сам (анти-чит S-04) — клиент их слать не может,
# иначе очки (= деньги в Store) подделываются. runnerRun считается в /v1/runs.
# Phase 2 перенесёт сюда же runnerTerritory (→/territories/capture) и
# purchase/registration (→/orders).
_SERVER_ONLY_SOURCES = {"runnerRun"}


@api_view(["POST"])
def transactions(request):
    uid = user_id_from_request(request)
    if not uid:
        return Response({"detail": "Нет токена"}, status=401)
    d = request.data
    run_id = d.get("runId")
    order_id = d.get("orderId")
    source = d.get("source")
    if source in _SERVER_ONLY_SOURCES:
        return Response({"detail": "Начисления за бег считает сервер"}, status=403)
    # Идемпотентность: по (user, runId, source) для забегов и
    # по (user, orderId, source) для покупок/начислений за заказ — без дублей.
    if run_id and LoyaltyTransaction.objects.filter(
        user_id=uid, run_id=run_id, source=source
    ).exists():
        return Response({"ok": True, "deduped": True})
    if order_id and LoyaltyTransaction.objects.filter(
        user_id=uid, order_id=order_id, source=source
    ).exists():
        return Response({"ok": True, "deduped": True})
    add_txn(
        uid,
        int(d.get("amount") or 0),
        source,
        d.get("description") or "",
        order_id,
        run_id,
    )
    return Response({"ok": True})
