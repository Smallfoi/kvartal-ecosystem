from django.db import IntegrityError
from rest_framework.decorators import api_view, throttle_classes
from rest_framework.response import Response

from common.throttling import AuthEndpointThrottle

from common.security import (
    hash_password,
    make_token,
    new_user_id,
    normalize_phone,
    synthetic_email_for_phone,
    user_id_from_request,
    verify_password,
)
from loyalty.models import seed_runner_points

from .models import Account
from .sms import check_code, request_code, sms_enabled


@api_view(["POST"])
@throttle_classes([AuthEndpointThrottle])
def register(request):
    d = request.data
    email = (d.get("email") or "").strip().lower()
    if Account.objects.filter(email=email).exists():
        return Response({"detail": "Пользователь с таким email уже существует"}, status=409)
    acc = Account.objects.create(
        id=new_user_id(),
        name=(d.get("name") or "").strip(),
        email=email,
        phone=d.get("phone"),
        provider="email",
        password_hash=hash_password(d.get("password") or ""),
    )
    seed_runner_points(acc.id)
    from analytics.models import E_REGISTER, track

    track(E_REGISTER, user_id=acc.id, source="email")  # аналитика (D-30)
    return Response({"token": make_token(acc.id), "user": acc.to_json()})


@api_view(["POST"])
@throttle_classes([AuthEndpointThrottle])
def login(request):
    d = request.data
    email = (d.get("email") or "").strip().lower()
    acc = Account.objects.filter(email=email).first()
    if not acc or not verify_password(d.get("password") or "", acc.password_hash or ""):
        return Response({"detail": "Неверный email или пароль"}, status=401)
    if acc.is_blocked:
        return Response({"detail": "Аккаунт заблокирован"}, status=403)
    return Response({"token": make_token(acc.id), "user": acc.to_json()})


@api_view(["POST"])
@throttle_classes([AuthEndpointThrottle])
def phone_request(request):
    """Отправить код входа на телефон. В dev (без SMS-провайдера) реальная SMS не
    шлётся — код входа всегда 1234. С SMS_PROVIDER=smsc уходит одноразовый код."""
    phone = normalize_phone(request.data.get("phone") or "")
    if not phone:
        return Response({"detail": "Нет телефона"}, status=400)
    request_code(phone)
    return Response({"ok": True, "smsEnabled": sms_enabled()})


@api_view(["POST"])
@throttle_classes([AuthEndpointThrottle])
def phone_verify(request):
    d = request.data
    phone = normalize_phone(d.get("phone") or "")
    if not check_code(phone, d.get("code") or ""):
        return Response({"detail": "Invalid verification code"}, status=401)
    email = synthetic_email_for_phone(phone)
    acc = Account.objects.filter(phone=phone).first()
    if not acc:
        acc = Account.objects.filter(email=email).first()
        if acc:
            acc.phone = phone
            acc.save(update_fields=["phone"])
    created = False
    if not acc:
        acc = Account.objects.create(
            id=new_user_id(),
            name=(d.get("name") or "Runner").strip(),
            email=email,
            phone=phone,
            provider="phone",
            password_hash=hash_password(f"phone:{phone}"),
        )
        seed_runner_points(acc.id)
        created = True
    if acc.is_blocked:
        return Response({"detail": "Аккаунт заблокирован"}, status=403)
    # Аналитика (D-30): регистрация нового аккаунта или вход существующего.
    from analytics.models import E_LOGIN, E_REGISTER, track

    track(E_REGISTER if created else E_LOGIN, user_id=acc.id, source="phone")
    return Response({"token": make_token(acc.id), "user": acc.to_json()})


@api_view(["GET"])
def me(request):
    uid = user_id_from_request(request)
    if not uid:
        return Response({"detail": "Нет токена"}, status=401)
    acc = Account.objects.filter(id=uid).first()
    if not acc:
        return Response({"detail": "Пользователь не найден"}, status=404)
    return Response(acc.to_json())


@api_view(["PATCH"])
def update_profile(request):
    uid = user_id_from_request(request)
    if not uid:
        return Response({"detail": "Нет токена"}, status=401)
    acc = Account.objects.filter(id=uid).first()
    if not acc:
        return Response({"detail": "User not found"}, status=404)
    d = request.data
    if d.get("name") is not None:
        name = (d.get("name") or "").strip()
        if not name:
            return Response({"detail": "Name cannot be empty"}, status=400)
        acc.name = name
    if d.get("phone") is not None:
        acc.phone = normalize_phone(d.get("phone") or "")
    if d.get("email") is not None:
        em = (d.get("email") or "").strip().lower()
        if em and "@" not in em:
            return Response({"detail": "Invalid email"}, status=400)
        if em:
            acc.email = em
    if d.get("city") is not None:
        acc.city = (d.get("city") or "").strip() or None
    if d.get("avatarPath") is not None:
        acc.avatar_path = (d.get("avatarPath") or "").strip() or None
    if d.get("addresses") is not None:
        # Адреса доставки — единые для экосистемы. Принимаем список (строки или объекты).
        addrs = d.get("addresses")
        acc.addresses = addrs if isinstance(addrs, list) else []
    try:
        acc.save()
    except IntegrityError:
        return Response({"detail": "Email already belongs to another account"}, status=409)
    return Response(acc.to_json())


@api_view(["POST", "DELETE"])
def profile_avatar(request):
    """Аватар профиля — единый для всей экосистемы. POST multipart `image` →
    media, в avatar_path кладём URL; все приложения берут аватар с сервера.
    DELETE — снять аватар (вернуться к инициалам)."""
    uid = user_id_from_request(request)
    if not uid:
        return Response({"detail": "Нет токена"}, status=401)
    acc = Account.objects.filter(id=uid).first()
    if not acc:
        return Response({"detail": "Пользователь не найден"}, status=404)
    if request.method == "DELETE":
        acc.avatar_path = None
        acc.save(update_fields=["avatar_path"])
        return Response(acc.to_json())
    f = request.FILES.get("image")
    if not f:
        return Response({"detail": "Нет файла"}, status=400)
    if f.size > 5 * 1024 * 1024:
        return Response({"detail": "Файл слишком большой (макс 5 МБ)"}, status=400)
    if not (f.content_type or "").startswith("image/"):
        return Response({"detail": "Нужен файл-изображение"}, status=400)
    import secrets

    from django.core.files.storage import default_storage

    ext = (f.name.rsplit(".", 1)[-1] if "." in f.name else "jpg").lower()[:5]
    saved = default_storage.save(
        f"uploads/avatars/{uid}_{secrets.token_hex(4)}.{ext}", f
    )
    acc.avatar_path = default_storage.url(saved)  # локально /media/…, в проде S3/CDN (D-31)
    acc.save(update_fields=["avatar_path"])
    return Response(acc.to_json())


@api_view(["GET", "PATCH"])
def account_privacy(request):
    """Настройки приватности (LAUNCH_READINESS §2). GET → текущие; PATCH → меняет
    {profilePublic, routePublic, realtimePublic}. По умолчанию всё закрыто."""
    uid = user_id_from_request(request)
    if not uid:
        return Response({"detail": "Нет токена"}, status=401)
    acc = Account.objects.filter(id=uid).first()
    if not acc:
        return Response({"detail": "User not found"}, status=404)
    if request.method == "PATCH":
        d = request.data
        if d.get("profilePublic") is not None:
            acc.profile_public = bool(d.get("profilePublic"))
        if d.get("routePublic") is not None:
            acc.route_public = bool(d.get("routePublic"))
        if d.get("realtimePublic") is not None:
            acc.realtime_public = bool(d.get("realtimePublic"))
        acc.save(update_fields=["profile_public", "route_public", "realtime_public"])
    return Response(acc.privacy_json())


@api_view(["GET"])
def me_stats(request):
    """Личная аналитика пользователя: активность бега, баллы, заказы.
    Данные — из общего бэка (источник правды), одинаковы во всех приложениях."""
    uid = user_id_from_request(request)
    if not uid:
        return Response({"detail": "Нет токена"}, status=401)
    # Кэш на юзера (D-29): агрегаты тяжёлые, а меняются только при его транзакциях —
    # add_txn сбрасывает кэш (invalidate_stats). Плюс safety-TTL на изменения мимо add_txn.
    from common.cache import STATS_TTL, cache_json, stats_key

    data = cache_json(stats_key(uid), STATS_TTL, lambda: _compute_stats(uid))
    return Response(data)


def _compute_stats(uid):
    """Тяжёлый расчёт личной статистики (забеги/баллы/заказы). Кэшируется по uid."""
    from django.db.models import Count, Sum

    from loyalty.models import LoyaltyTransaction, balance_of
    from orders.models import Order
    from runs.models import Run

    runs = Run.objects.filter(user_id=uid)
    runs_agg = runs.aggregate(c=Count("id"))
    # «Реальные» км — без флаг-забегов (анти-чит); флаг-дистанцию не считаем.
    km_agg = runs.filter(flagged=False).aggregate(d=Sum("distance_m"))
    txns = LoyaltyTransaction.objects.filter(user_id=uid)
    earned = txns.filter(amount__gt=0).aggregate(s=Sum("amount"))["s"] or 0
    spent = txns.filter(amount__lt=0).aggregate(s=Sum("amount"))["s"] or 0
    orders_agg = Order.objects.filter(user_id=uid).aggregate(
        c=Count("id"), total=Sum("total")
    )
    return {
        "runs": {
            "count": runs_agg["c"] or 0,
            "totalKm": round((km_agg["d"] or 0) / 1000.0, 1),
        },
        "loyalty": {
            "balance": balance_of(uid),
            "earned": int(earned),
            "spent": int(-spent),  # положительное число потраченного
        },
        "orders": {
            "count": orders_agg["c"] or 0,
            "totalSpent": int(orders_agg["total"] or 0),
        },
    }


@api_view(["GET"])
def account_export(request):
    """Выгрузка ВСЕХ персональных данных пользователя (152-ФЗ, LR §2 «портируемость»).
    Зеркало delete_account: всё, что удаляется, — экспортируется. Отдаём JSON-файлом."""
    uid = user_id_from_request(request)
    if not uid:
        return Response({"detail": "Нет токена"}, status=401)
    acc = Account.objects.filter(id=uid).first()
    if not acc:
        return Response({"detail": "Пользователь не найден"}, status=404)

    from django.db import connection

    from analytics.models import Event
    from clubs.models import Club, ClubJoinRequest, ClubMember
    from legal.models import UserConsent
    from loyalty.models import LoyaltyTransaction, balance_of
    from notifications.models import Notification
    from orders.models import Order
    from runs.models import Run
    from shoes.models import ShoeAsset

    def rows(qs):
        return list(qs.values())  # DRF-JSON сериализует datetime/Decimal сам

    data = {
        "userId": uid,
        "profile": acc.to_json(),
        "loyalty": {
            "balance": balance_of(uid),
            "transactions": [
                t.to_json() for t in
                LoyaltyTransaction.objects.filter(user_id=uid).order_by("created_at")
            ],
        },
        "orders": [
            o.to_json() for o in Order.objects.filter(user_id=uid).order_by("created_at")
        ],
        "runs": rows(Run.objects.filter(user_id=uid).order_by("created_at")),
        "shoes": rows(ShoeAsset.objects.filter(user_id=uid)),
        "notifications": rows(Notification.objects.filter(user_id=uid).order_by("created_at")),
        "consents": rows(UserConsent.objects.filter(user_id=uid)),
        "clubMemberships": rows(ClubMember.objects.filter(user_id=uid)),
        "clubJoinRequests": rows(ClubJoinRequest.objects.filter(user_id=uid)),
        "ownedClubs": rows(Club.objects.filter(owner_id=uid)),
        "analyticsEvents": [
            e.to_json() for e in Event.objects.filter(user_id=uid).order_by("created_at")
        ],
    }
    # Гео (PostGIS, raw SQL): суммарная площадь территорий + вечный след.
    with connection.cursor() as cur:
        cur.execute(
            "SELECT COALESCE(SUM(ST_Area(geom::geography)),0) FROM territories WHERE owner_id=%s",
            [uid],
        )
        terr = cur.fetchone()[0] or 0
        cur.execute(
            "SELECT COALESCE(ST_Area(geom::geography),0) FROM footprints WHERE owner_id=%s",
            [uid],
        )
        fp_row = cur.fetchone()
        cur.execute("SELECT now()")
        now = cur.fetchone()[0]
    data["territoriesAreaM2"] = round(terr)
    data["footprintAreaM2"] = round((fp_row[0] if fp_row else 0) or 0)
    data["exportedAt"] = now.isoformat()

    resp = Response(data)
    resp["Content-Disposition"] = 'attachment; filename="mata_data_export.json"'
    return resp


@api_view(["POST"])
def delete_account(request):
    """Удаление аккаунта и всех персональных данных пользователя (152-ФЗ, LR §13).
    Требует Bearer + тело {"confirm": true}. Необратимо."""
    uid = user_id_from_request(request)
    if not uid:
        return Response({"detail": "Нет токена"}, status=401)
    acc = Account.objects.filter(id=uid).first()
    if not acc:
        return Response({"detail": "User not found"}, status=404)
    if request.data.get("confirm") is not True:
        return Response({"detail": "Требуется подтверждение: {confirm: true}"}, status=400)

    from django.db import connection
    from clubs.models import Club, ClubJoinRequest, ClubMember
    from legal.models import UserConsent
    from loyalty.models import LoyaltyTransaction
    from notifications.models import Notification
    from orders.models import Order
    from runs.models import Run
    from shoes.models import ShoeAsset

    # Клуб во владении с другими участниками — нельзя удалить «молча».
    owned = Club.objects.filter(owner_id=uid)
    for club in owned:
        others = ClubMember.objects.filter(club_id=club.id).exclude(user_id=uid).exists()
        if others:
            return Response(
                {"detail": "Вы владелец клуба с участниками — передайте или распустите клуб"},
                status=409,
            )

    deleted = {}
    # Клубы во владении (без чужих участников) — распускаем целиком.
    owned_ids = list(owned.values_list("id", flat=True))
    if owned_ids:
        ClubMember.objects.filter(club_id__in=owned_ids).delete()
        ClubJoinRequest.objects.filter(club_id__in=owned_ids).delete()
        deleted["clubs"] = owned.delete()[0]
    # Членство/заявки пользователя в чужих клубах.
    deleted["clubMemberships"] = ClubMember.objects.filter(user_id=uid).delete()[0]
    deleted["clubRequests"] = ClubJoinRequest.objects.filter(user_id=uid).delete()[0]
    # Личные данные по сервисам.
    deleted["loyalty"] = LoyaltyTransaction.objects.filter(user_id=uid).delete()[0]
    deleted["orders"] = Order.objects.filter(user_id=uid).delete()[0]
    deleted["runs"] = Run.objects.filter(user_id=uid).delete()[0]  # история забегов = ПДн (GPS)
    deleted["shoes"] = ShoeAsset.objects.filter(user_id=uid).delete()[0]
    deleted["notifications"] = Notification.objects.filter(user_id=uid).delete()[0]
    deleted["consents"] = UserConsent.objects.filter(user_id=uid).delete()[0]
    # Гео (PostGIS, raw SQL): территории + вечный след.
    with connection.cursor() as cur:
        cur.execute("DELETE FROM territories WHERE owner_id=%s", [uid])
        deleted["territories"] = cur.rowcount
        cur.execute("DELETE FROM footprints WHERE owner_id=%s", [uid])
        deleted["footprints"] = cur.rowcount
    # Сам аккаунт.
    acc.delete()
    return Response({"ok": True, "deleted": deleted})
