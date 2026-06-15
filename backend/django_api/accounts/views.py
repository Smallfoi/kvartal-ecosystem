from django.db import IntegrityError
from rest_framework.decorators import api_view
from rest_framework.response import Response

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


@api_view(["POST"])
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
    return Response({"token": make_token(acc.id), "user": acc.to_json()})


@api_view(["POST"])
def login(request):
    d = request.data
    email = (d.get("email") or "").strip().lower()
    acc = Account.objects.filter(email=email).first()
    if not acc or not verify_password(d.get("password") or "", acc.password_hash or ""):
        return Response({"detail": "Неверный email или пароль"}, status=401)
    return Response({"token": make_token(acc.id), "user": acc.to_json()})


@api_view(["POST"])
def phone_verify(request):
    d = request.data
    if (d.get("code") or "") != "1234":
        return Response({"detail": "Invalid verification code"}, status=401)
    phone = normalize_phone(d.get("phone") or "")
    email = synthetic_email_for_phone(phone)
    acc = Account.objects.filter(phone=phone).first()
    if not acc:
        acc = Account.objects.filter(email=email).first()
        if acc:
            acc.phone = phone
            acc.save(update_fields=["phone"])
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
    try:
        acc.save()
    except IntegrityError:
        return Response({"detail": "Email already belongs to another account"}, status=409)
    return Response(acc.to_json())
