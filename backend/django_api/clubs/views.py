import secrets

from rest_framework.decorators import api_view
from rest_framework.response import Response

from accounts.models import Account
from common.security import user_id_from_request
from loyalty.models import LoyaltyTransaction

from .models import Club, ClubJoinRequest, ClubMember


def _uid(request):
    return user_id_from_request(request)


def _balance(uid) -> int:
    return sum(
        t.amount for t in LoyaltyTransaction.objects.filter(user_id=uid).only("amount")
    )


def _km(uid) -> float:
    """Суммарный пробег за всё время (км). Растёт с каждым забегом, не тратится —
    в отличие от баллов кошелька. Источник — начисления за бег (runnerRun)/10."""
    pts = sum(
        t.amount
        for t in LoyaltyTransaction.objects.filter(
            user_id=uid, source="runnerRun"
        ).only("amount")
    )
    return round(pts / 10.0, 1)


def _current_club_id(uid):
    m = ClubMember.objects.filter(user_id=uid).first()
    return m.club_id if m else None


def _name_of(uid):
    a = Account.objects.filter(id=uid).only("name").first()
    return a.name if a else "—"


def _members_json(club_id):
    # Личные баллы кошелька в клубе не показываем — у участника отдаём вклад в км.
    out = [
        {"userId": m.user_id, "name": _name_of(m.user_id), "role": m.role,
         "km": _km(m.user_id)}
        for m in ClubMember.objects.filter(club_id=club_id)
    ]
    out.sort(key=lambda x: x["km"], reverse=True)
    return out


def _summary(club: Club) -> dict:
    members = list(ClubMember.objects.filter(club_id=club.id))
    return {
        "id": club.id, "name": club.name, "logo": club.logo, "city": club.city,
        "description": club.description, "ownerId": club.owner_id,
        "joinPolicy": club.join_policy, "memberCount": len(members),
        # Активность клуба — суммарный пробег (км), а не баллы (баллы тратятся/динамичны).
        "totalKm": round(sum(_km(m.user_id) for m in members), 1),
    }


def _detail(club: Club, uid) -> dict:
    base = _summary(club)
    base["members"] = _members_json(club.id)
    m = ClubMember.objects.filter(club_id=club.id, user_id=uid).first()
    base["myRole"] = m.role if m else None
    return base


@api_view(["GET", "POST"])
def clubs_root(request):
    uid = _uid(request)
    if not uid:
        return Response({"detail": "Нет токена"}, status=401)
    if request.method == "GET":
        search = request.query_params.get("search")
        qs = Club.objects.all()
        if search:
            from django.db.models import Q
            qs = qs.filter(Q(name__icontains=search) | Q(city__icontains=search))
        result = [_summary(c) for c in qs.order_by("-created_at")]
        result.sort(key=lambda c: c["totalKm"], reverse=True)
        return Response(result)
    # POST — create
    d = request.data
    name = (d.get("name") or "").strip()
    if not name:
        return Response({"detail": "Название клуба обязательно"}, status=400)
    if _current_club_id(uid):
        return Response({"detail": "Вы уже состоите в клубе"}, status=409)
    policy = d.get("joinPolicy") if d.get("joinPolicy") in ("open", "request") else "open"
    club = Club.objects.create(
        id=f"c_{secrets.token_hex(8)}",
        name=name,
        logo=d.get("logo"),
        city=((d.get("city") or "").strip() or None),
        description=((d.get("description") or "").strip() or None),
        owner_id=uid,
        join_policy=policy,
    )
    ClubMember.objects.create(club_id=club.id, user_id=uid, role="owner")
    return Response(_detail(club, uid))


@api_view(["GET"])
def my_club(request):
    uid = _uid(request)
    if not uid:
        return Response({"detail": "Нет токена"}, status=401)
    cid = _current_club_id(uid)
    if not cid:
        return Response({"club": None})
    club = Club.objects.filter(id=cid).first()
    return Response({"club": _detail(club, uid)})


@api_view(["GET", "PATCH"])
def club_detail_or_update(request, club_id):
    uid = _uid(request)
    if not uid:
        return Response({"detail": "Нет токена"}, status=401)
    club = Club.objects.filter(id=club_id).first()
    if not club:
        return Response({"detail": "Клуб не найден"}, status=404)
    if request.method == "GET":
        return Response(_detail(club, uid))
    # PATCH — owner only
    if club.owner_id != uid:
        return Response({"detail": "Только владелец клуба"}, status=403)
    d = request.data
    if d.get("name") is not None and (d.get("name") or "").strip():
        club.name = d["name"].strip()
    if d.get("logo") is not None:
        club.logo = d["logo"]
    if d.get("city") is not None:
        club.city = (d.get("city") or "").strip() or None
    if d.get("description") is not None:
        club.description = (d.get("description") or "").strip() or None
    if d.get("joinPolicy") in ("open", "request"):
        club.join_policy = d["joinPolicy"]
    club.save()
    return Response(_detail(club, uid))


@api_view(["POST"])
def join_club(request, club_id):
    uid = _uid(request)
    if not uid:
        return Response({"detail": "Нет токена"}, status=401)
    club = Club.objects.filter(id=club_id).first()
    if not club:
        return Response({"detail": "Клуб не найден"}, status=404)
    if _current_club_id(uid):
        return Response({"detail": "Вы уже состоите в клубе"}, status=409)
    if club.join_policy == "open":
        ClubMember.objects.create(club_id=club_id, user_id=uid, role="member")
        return Response({"status": "joined"})
    if not ClubJoinRequest.objects.filter(
        club_id=club_id, user_id=uid, status="pending"
    ).exists():
        ClubJoinRequest.objects.create(
            id=f"r_{secrets.token_hex(8)}", club_id=club_id, user_id=uid, status="pending"
        )
    return Response({"status": "requested"})


@api_view(["POST"])
def leave_club(request, club_id):
    uid = _uid(request)
    if not uid:
        return Response({"detail": "Нет токена"}, status=401)
    m = ClubMember.objects.filter(club_id=club_id, user_id=uid).first()
    if not m:
        return Response({"detail": "Вы не состоите в этом клубе"}, status=404)
    if m.role == "owner":
        cnt = ClubMember.objects.filter(club_id=club_id).count()
        if cnt > 1:
            return Response({"detail": "Владелец не может выйти, пока есть участники"}, status=409)
        ClubMember.objects.filter(club_id=club_id).delete()
        ClubJoinRequest.objects.filter(club_id=club_id).delete()
        Club.objects.filter(id=club_id).delete()
        return Response({"status": "left", "clubDeleted": True})
    m.delete()
    return Response({"status": "left"})


@api_view(["GET"])
def club_requests(request, club_id):
    uid = _uid(request)
    if not uid:
        return Response({"detail": "Нет токена"}, status=401)
    club = Club.objects.filter(id=club_id).first()
    if not club:
        return Response({"detail": "Клуб не найден"}, status=404)
    if club.owner_id != uid:
        return Response({"detail": "Только владелец клуба"}, status=403)
    rows = ClubJoinRequest.objects.filter(club_id=club_id, status="pending").order_by("created_at")
    return Response(
        [{"id": r.id, "userId": r.user_id, "name": _name_of(r.user_id)} for r in rows]
    )


@api_view(["POST"])
def approve_request(request, req_id):
    uid = _uid(request)
    if not uid:
        return Response({"detail": "Нет токена"}, status=401)
    req = ClubJoinRequest.objects.filter(id=req_id).first()
    if not req or req.status != "pending":
        return Response({"detail": "Заявка не найдена"}, status=404)
    club = Club.objects.filter(id=req.club_id).first()
    if not club or club.owner_id != uid:
        return Response({"detail": "Только владелец клуба"}, status=403)
    if _current_club_id(req.user_id):
        req.status = "rejected"
        req.save(update_fields=["status"])
        return Response({"detail": "Пользователь уже состоит в клубе"}, status=409)
    ClubMember.objects.create(club_id=req.club_id, user_id=req.user_id, role="member")
    req.status = "approved"
    req.save(update_fields=["status"])
    return Response({"status": "approved"})


@api_view(["POST"])
def reject_request(request, req_id):
    uid = _uid(request)
    if not uid:
        return Response({"detail": "Нет токена"}, status=401)
    req = ClubJoinRequest.objects.filter(id=req_id).first()
    if not req:
        return Response({"detail": "Заявка не найдена"}, status=404)
    club = Club.objects.filter(id=req.club_id).first()
    if not club or club.owner_id != uid:
        return Response({"detail": "Только владелец клуба"}, status=403)
    req.status = "rejected"
    req.save(update_fields=["status"])
    return Response({"status": "rejected"})
