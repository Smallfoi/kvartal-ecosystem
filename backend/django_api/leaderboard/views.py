from datetime import datetime, timedelta
from datetime import timezone as dt_tz

from django.db import connection
from django.db.models import Sum
from rest_framework.decorators import api_view
from rest_framework.response import Response

from accounts.models import Account
from clubs.models import Club, ClubMember
from common.cache import LEADERBOARD_TTL, cache_json, leaderboard_key
from common.security import user_id_from_request
from loyalty.models import LoyaltyTransaction
from territories.views import HOLD_HOURS


def _period_start(period: str):
    now = datetime.now(dt_tz.utc)
    if period == "week":
        return (now - timedelta(days=now.weekday())).replace(
            hour=0, minute=0, second=0, microsecond=0
        )
    if period == "month":
        return now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    return datetime(1970, 1, 1, tzinfo=dt_tz.utc)


def _name_of(uid):
    a = Account.objects.filter(id=uid).only("name").first()
    return a.name if a else "—"


def _club_name_of(uid):
    m = ClubMember.objects.filter(user_id=uid).first()
    if not m:
        return None
    c = Club.objects.filter(id=m.club_id).only("name").first()
    return c.name if c else None


@api_view(["GET"])
def users(request):
    me = user_id_from_request(request)
    if not me:
        return Response({"detail": "Нет токена"}, status=401)
    period = request.query_params.get("period", "week")
    if period not in ("week", "month", "all"):
        period = "week"
    limit = int(request.query_params.get("limit", 50) or 50)
    # Тяжёлое (агрегация + имена/клубы) кэшируем без пер-юзерных полей; isMe/me — на запрос.
    data = cache_json(
        leaderboard_key("users", period, limit),
        LEADERBOARD_TTL,
        lambda: _users_payload(period, limit),
    )
    top = [{**t, "isMe": t["userId"] == me} for t in data["top"]]
    ranked = data["ranked"]
    my_rank = next((i + 1 for i, (uid, _) in enumerate(ranked) if uid == me), None)
    my_km = next((km for (uid, km) in ranked if uid == me), 0.0)
    return Response({"period": period, "top": top, "me": {"rank": my_rank, "km": round(my_km, 1)}})


def _users_payload(period, limit):
    """Тяжёлый расчёт личного рейтинга (кэшируемая, юзеро-НЕзависимая часть):
    ранжированный список (uid, km) + топ с именами/клубами. isMe добавляется на запрос."""
    start = _period_start(period)
    rows = (
        LoyaltyTransaction.objects.filter(source="runnerRun", created_at__gte=start)
        .values("user_id")
        .annotate(pts=Sum("amount"))
    )
    ranked = sorted(
        ((r["user_id"], (r["pts"] or 0) / 10.0) for r in rows if (r["pts"] or 0) > 0),
        key=lambda x: x[1],
        reverse=True,
    )
    top = [
        {
            "userId": uid,
            "name": _name_of(uid),
            "km": round(km, 1),
            "club": _club_name_of(uid),
            "rank": i + 1,
        }
        for i, (uid, km) in enumerate(ranked[:limit])
    ]
    # ranked целиком нужен для расчёта моего ранга вне топа (список пар, компактно).
    return {"top": top, "ranked": [[uid, km] for uid, km in ranked]}


@api_view(["GET"])
def clubs(request):
    me = user_id_from_request(request)
    if not me:
        return Response({"detail": "Нет токена"}, status=401)
    period = request.query_params.get("period", "week")
    if period not in ("week", "month", "all"):
        period = "week"
    limit = int(request.query_params.get("limit", 50) or 50)
    mm = ClubMember.objects.filter(user_id=me).first()
    my_club = mm.club_id if mm else None
    result = cache_json(
        leaderboard_key("clubs", period, limit),
        LEADERBOARD_TTL,
        lambda: _clubs_payload(period),
    )
    top = [{**c, "rank": i + 1, "isMine": c["id"] == my_club} for i, c in enumerate(result[:limit])]
    my_rank = next((i + 1 for i, c in enumerate(result) if c["id"] == my_club), None)
    return Response({"period": period, "top": top, "myRank": my_rank})


def _clubs_payload(period):
    """Клубный рейтинг (кэшируемая часть): отсортированный список клубов с км.
    Ранг/isMine добавляются на запрос (полный список нужен для myRank вне топа)."""
    start = _period_start(period)
    result = []
    for club in Club.objects.all():
        members = list(
            ClubMember.objects.filter(club_id=club.id).values_list("user_id", flat=True)
        )
        pts = 0
        if members:
            agg = LoyaltyTransaction.objects.filter(
                source="runnerRun", created_at__gte=start, user_id__in=members
            ).aggregate(s=Sum("amount"))
            pts = agg["s"] or 0
        result.append(
            {"id": club.id, "name": club.name, "logo": club.logo,
             "members": len(members), "km": round(pts / 10.0, 1)}
        )
    result.sort(key=lambda c: c["km"], reverse=True)
    return result


@api_view(["GET"])
def districts(request):
    """Контроль территорий (D-09): клубы по суммарной площади удерживаемых
    территорий (только активные, < 72ч). Источник — таблица territories (PostGIS)."""
    me = user_id_from_request(request)
    if not me:
        return Response({"detail": "Нет токена"}, status=401)
    limit = int(request.query_params.get("limit", 50) or 50)
    mm = ClubMember.objects.filter(user_id=me).first()
    my_club = mm.club_id if mm else None
    result = cache_json(
        leaderboard_key("districts", "all", limit),
        LEADERBOARD_TTL,
        _districts_payload,
    )
    top = [
        {**c, "rank": i + 1, "isMine": c["id"] == my_club}
        for i, c in enumerate(result[:limit])
    ]
    my_rank = next((i + 1 for i, c in enumerate(result) if c["id"] == my_club), None)
    return Response({"top": top, "myRank": my_rank})


def _districts_payload():
    """Районный рейтинг (кэшируемая часть): клубы по площади удерживаемых территорий
    (PostGIS). Ранг/isMine добавляются на запрос."""
    with connection.cursor() as cur:
        cur.execute(
            "SELECT club_id, SUM(ST_Area(geom::geography)) AS area, COUNT(*) AS pieces "
            "FROM territories "
            "WHERE club_id IS NOT NULL "
            "AND captured_at > now() - make_interval(hours => %s) "
            "GROUP BY club_id",
            [HOLD_HOURS],
        )
        rows = cur.fetchall()
    result = []
    for club_id, area, pieces in rows:
        c = Club.objects.filter(id=club_id).only("name", "logo").first()
        if not c:
            continue
        result.append(
            {
                "id": club_id,
                "name": c.name,
                "logo": c.logo,
                "areaM2": round(area or 0),
                "pieces": int(pieces),
            }
        )
    result.sort(key=lambda x: x["areaM2"], reverse=True)
    return result
