# -*- coding: utf-8 -*-
"""GET /v1/me/medals — состояние 44 наград «Штамп МАТА».

Ленивая выдача: заслуженные, но не записанные медали фиксируются здесь же
(гравировка — цифрами на момент получения). Ответ — только состояние;
каталог (названия/ранги/ассеты) живёт в клиенте, чтобы не гонять статику.
"""
from datetime import timedelta

from django.utils import timezone
from rest_framework.decorators import api_view
from rest_framework.response import Response

from common.security import user_id_from_request

from .catalog import CATALOG, Facts
from .models import MedalAward

NEW_DAYS = 3  # «новая» — лаймовая метка три дня после получения (эталон)


@api_view(["GET"])
def me_medals(request):
    uid = user_id_from_request(request)
    if not uid:
        return Response({"detail": "Нет токена"}, status=401)

    facts = Facts(uid)
    existing = {m.medal_id: m for m in MedalAward.objects.filter(user_id=uid)}
    now = timezone.now()
    items = []
    for d in CATALOG:
        mid = d["id"]
        award = existing.get(mid)
        check = d.get("check")
        if award is None and check is not None and check(facts):
            v, u, sub = d["engrave"](facts)
            award, _ = MedalAward.objects.get_or_create(
                user_id=uid,
                medal_id=mid,
                defaults={
                    "id": MedalAward.new_id(),
                    "v": v[:24], "u": u[:32], "sub": sub[:48],
                },
            )
        item = {
            "id": mid,
            "available": check is not None,
            "earnedAtMs": int(award.earned_at.timestamp() * 1000) if award else None,
            "new": bool(award and now - award.earned_at < timedelta(days=NEW_DAYS)),
            "engraving": (
                {"v": award.v, "u": award.u, "sub": award.sub} if award else None
            ),
        }
        prog = d.get("progress")
        if award is None and prog is not None:
            cur, target = prog(facts)
            item["progress"] = {"cur": round(float(cur), 1), "target": target}
        items.append(item)

    earned = sum(1 for i in items if i["earnedAtMs"] is not None)
    return Response({"items": items, "earned": earned, "total": len(items)})
