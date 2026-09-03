"""Вкладка «Сотрудники» и приём приглашений (S-12).

Разделение обязанностей: страницы 1–5 доступны только владельцу
(`superuser_required`), страница приглашения — публична, но пускает лишь по
живому одноразовому токену, страница второго фактора работает только со СВОИМ
аккаунтом и никогда не принимает чужой идентификатор.

Три правила, которые здесь соблюдаются буквально:
1. Кого меняем — берём из адреса, но право менять проверяем по сессии. Подставить
   чужой id бесполезно: страница сначала требует владельца, и только потом читает id.
2. Суперпользователя и себя через эту вкладку менять нельзя — иначе владелец
   мог бы случайно отобрать права у самого себя или создать второго хозяина.
3. Любое изменение прав пишется в журнал: кто, кому, что и с какого адреса.
"""
import re

from django.contrib import messages
from django.contrib.admin.views.decorators import staff_member_required
from django.contrib.auth import get_user_model, logout as auth_logout
from django.contrib.auth.password_validation import validate_password
from django.core.cache import cache
from django.core.exceptions import PermissionDenied, ValidationError
from django.contrib import admin as django_admin
from django.db import IntegrityError, transaction
from django.shortcuts import get_object_or_404, redirect, render
from django.template.response import TemplateResponse
from django.urls import reverse
from django.views.decorators.http import require_http_methods

from .access import superuser_required
from .models import (LEVEL_NONE, LEVELS, StaffAudit, StaffProfile, TabPermission,
                     _client_ip)
from .tabs import TABS, groups

User = get_user_model()

EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s.]+\.[^@\s]{2,}$")

# Подбор токена приглашения — единственный публичный вход, поэтому считаем попытки.
INVITE_TRIES = 20
INVITE_WINDOW = 15 * 60


def _password_rules():
    """Требования к паролю сотрудника.

    Заданы здесь, а не глобально в настройках: вход в админку и смена пароля
    владельцем работают как раньше (директива «вход не трогать»), а новый пароль
    сотрудника проверяется строго. Без этого списка `validate_password` пропускает
    что угодно — в проекте общих валидаторов нет.
    """
    from django.contrib.auth import password_validation as pv

    return [
        pv.MinimumLengthValidator(min_length=10),
        pv.CommonPasswordValidator(),
        pv.NumericPasswordValidator(),
        pv.UserAttributeSimilarityValidator(),
    ]


def _managed(profile_pk):
    """Сотрудник, которым владельцу вообще позволено управлять."""
    profile = get_object_or_404(
        StaffProfile.objects.select_related("user"), pk=profile_pk)
    if profile.user.is_superuser:
        # Второй владелец не управляется из интерфейса — только из консоли сервера.
        raise PermissionDenied("Суперпользователь не управляется через эту вкладку")
    return profile


def _ctx(request, **extra):
    return {**django_admin.site.each_context(request), **extra}


# ─────────────────────────── Список сотрудников ───────────────────────────

@staff_member_required
@superuser_required
def staff_list(request):
    profiles = (StaffProfile.objects
                .select_related("user")
                .filter(user__is_superuser=False)
                .order_by("full_name"))
    rows = []
    for p in profiles:
        opened = TabPermission.objects.filter(user=p.user).exclude(level=LEVEL_NONE).count()
        rows.append({
            "profile": p,
            "email": p.user.email or p.user.get_username(),
            "opened": opened,
            "last_login": p.user.last_login,
            "has_2fa": _has_device(p.user),
        })
    return TemplateResponse(request, "admin/staff/list.html", _ctx(
        request,
        title="Сотрудники",
        rows=rows,
        audit=StaffAudit.objects.select_related()[:12],
        invite_link=request.session.pop("staff_invite_link", None),
        invite_for=request.session.pop("staff_invite_for", None),
    ))


def _has_device(user) -> bool:
    from common.admin2fa import user_has_device
    return user_has_device(user)


@staff_member_required
@superuser_required
@require_http_methods(["POST"])
def staff_create(request):
    name = (request.POST.get("full_name") or "").strip()
    email = (request.POST.get("email") or "").strip().lower()
    position = (request.POST.get("position") or "").strip()

    if not name:
        messages.error(request, "Укажите имя сотрудника.")
        return redirect("staff_list")
    if not EMAIL_RE.match(email) or len(email) > 150:
        messages.error(request, "Почта выглядит неверно.")
        return redirect("staff_list")
    if User.objects.filter(username__iexact=email).exists() or \
       User.objects.filter(email__iexact=email).exists():
        messages.error(request, "Такая почта уже заведена.")
        return redirect("staff_list")

    try:
        with transaction.atomic():
            user = User.objects.create(
                username=email, email=email, is_staff=True, is_superuser=False,
                first_name=name[:150],
            )
            # Пароля нет до принятия приглашения: войти по пустому нельзя.
            user.set_unusable_password()
            user.save(update_fields=["password"])
            profile = StaffProfile.objects.create(
                user=user, full_name=name, position=position, created_by=request.user)
            token = profile.issue_invite()
    except IntegrityError:
        messages.error(request, "Не удалось создать сотрудника: почта занята.")
        return redirect("staff_list")

    StaffAudit.write(request, f"Заведён сотрудник {name} ({email})", target=user)
    _remember_invite(request, profile, token)
    messages.success(request, f"Сотрудник {name} заведён. Передайте ссылку-приглашение.")
    return redirect("staff_member", profile.pk)


def _remember_invite(request, profile, token: str) -> None:
    """Ссылку показываем один раз — держим её в сессии владельца до показа."""
    request.session["staff_invite_link"] = request.build_absolute_uri(
        reverse("staff_invite", args=[token]))
    request.session["staff_invite_for"] = profile.full_name


# ─────────────────────────── Карточка сотрудника ───────────────────────────

@staff_member_required
@superuser_required
def staff_member(request, pk: int):
    profile = _managed(pk)
    current = {p.tab: p.level for p in TabPermission.objects.filter(user=profile.user)}
    blocks = []
    for group_title, tabs in groups():
        blocks.append({
            "title": group_title,
            "tabs": [{"tab": t, "level": current.get(t.key, LEVEL_NONE)} for t in tabs],
        })
    # Сводка «что ему видно» — чтобы проверить доступ, не входя под сотрудником.
    names = dict(LEVELS)
    granted = [{"title": t.title, "level": names[current[t.key]]}
               for t in TABS if current.get(t.key, LEVEL_NONE) != LEVEL_NONE]
    return TemplateResponse(request, "admin/staff/member.html", _ctx(
        request,
        title=profile.full_name,
        profile=profile,
        blocks=blocks,
        granted=granted,
        levels=LEVELS,
        has_2fa=_has_device(profile.user),
        audit=StaffAudit.objects.filter(target=profile.user)[:15],
        invite_link=request.session.pop("staff_invite_link", None),
        invite_for=request.session.pop("staff_invite_for", None),
    ))


@staff_member_required
@superuser_required
@require_http_methods(["POST"])
def staff_rights(request, pk: int):
    profile = _managed(pk)
    valid = {code for code, _ in LEVELS}
    changed = []
    for tab in TABS:
        level = (request.POST.get(f"tab__{tab.key}") or LEVEL_NONE).strip()
        if level not in valid:
            level = LEVEL_NONE
        existing = TabPermission.objects.filter(user=profile.user, tab=tab.key).first()
        was = existing.level if existing else LEVEL_NONE
        if was == level:
            continue
        if level == LEVEL_NONE:
            if existing:
                existing.delete()
        elif existing:
            existing.level = level
            existing.save(update_fields=["level"])
        else:
            TabPermission.objects.create(user=profile.user, tab=tab.key, level=level)
        changed.append(f"{tab.title}: {dict(LEVELS)[was]} → {dict(LEVELS)[level]}")

    if changed:
        StaffAudit.write(request, "Права: " + "; ".join(changed)[:150], target=profile.user)
        messages.success(request, f"Права сохранены ({len(changed)} изм.).")
    else:
        messages.info(request, "Права не изменились.")
    return redirect("staff_member", profile.pk)


@staff_member_required
@superuser_required
@require_http_methods(["POST"])
def staff_action(request, pk: int):
    profile = _managed(pk)
    action = (request.POST.get("action") or "").strip()

    if action == "toggle":
        profile.user.is_active = not profile.user.is_active
        profile.user.save(update_fields=["is_active"])
        word = "включён" if profile.user.is_active else "отключён"
        StaffAudit.write(request, f"Сотрудник {word}", target=profile.user)
        messages.success(request, f"Сотрудник {word}.")
        return redirect("staff_member", profile.pk)

    if action == "invite":
        token = profile.issue_invite()
        StaffAudit.write(request, "Выдана новая ссылка-приглашение", target=profile.user)
        _remember_invite(request, profile, token)
        messages.success(request, "Новая ссылка готова — прежняя больше не работает.")
        return redirect("staff_member", profile.pk)

    if action == "delete":
        name, email = profile.full_name, profile.user.email
        user = profile.user
        StaffAudit.write(request, f"Сотрудник удалён: {name} ({email})", target=None)
        user.delete()      # профиль и права уходят следом
        messages.success(request, f"Сотрудник {name} удалён.")
        return redirect("staff_list")

    messages.error(request, "Неизвестное действие.")
    return redirect("staff_member", profile.pk)


# ─────────────────────────── Приглашение (публичная) ───────────────────────

@require_http_methods(["GET", "POST"])
def staff_invite(request, token: str):
    """Сотрудник задаёт себе пароль. Ссылка одноразовая и живёт 48 часов."""
    bucket = f"invite_try_{_client_ip(request) or 'unknown'}"
    if cache.get(bucket, 0) >= INVITE_TRIES:
        return render(request, "admin/staff/invite.html",
                      {"error": "Слишком много попыток. Повторите через четверть часа."},
                      status=429)

    profile = StaffProfile.by_token(token)
    if profile is None or not profile.user.is_active:
        cache.set(bucket, cache.get(bucket, 0) + 1, INVITE_WINDOW)
        return render(request, "admin/staff/invite.html", {
            "error": "Ссылка недействительна или уже использована. "
                     "Попросите владельца выдать новую.",
        }, status=404)

    # Кто сейчас открыт в этом браузере. Если владелец принимает приглашение из
    # своего окна, он останется в СВОЕЙ сессии и увидит админку своими глазами —
    # именно так и рождается вывод «права не работают». Предупреждаем заранее.
    current = request.user.get_username() if request.user.is_authenticated else ""

    if request.method == "GET":
        return render(request, "admin/staff/invite.html",
                      {"profile": profile, "current": current})

    p1 = request.POST.get("password1") or ""
    p2 = request.POST.get("password2") or ""
    if p1 != p2:
        return render(request, "admin/staff/invite.html",
                      {"profile": profile, "error": "Пароли не совпадают."})
    try:
        validate_password(p1, user=profile.user, password_validators=_password_rules())
    except ValidationError as e:
        return render(request, "admin/staff/invite.html",
                      {"profile": profile, "current": current, "error": " ".join(e.messages)})

    with transaction.atomic():
        profile.user.set_password(p1)
        profile.user.save(update_fields=["password"])
        profile.accept_invite()
    StaffAudit.write(request, "Приглашение принято, пароль задан", target=profile.user)

    # Закрываем чужую сессию в этом браузере. Иначе следующая же страница входа
    # молча пустит того, кто был открыт раньше (Django пропускает уже вошедшего
    # мимо формы), и человек будет уверен, что вошёл сотрудником.
    if current:
        auth_logout(request)
    return render(request, "admin/staff/invite.html",
                  {"done": True, "was": current, "login": profile.user.get_username()})


# ─────────────────────────── Второй фактор (свой) ──────────────────────────

@staff_member_required
@require_http_methods(["GET", "POST"])
def otp_setup(request):
    """Подключение второго фактора СВОЕМУ аккаунту.

    Идентификатор пользователя страница не принимает ни в адресе, ни в форме:
    устройство всегда создаётся для request.user. Иначе подстановка чужого id
    позволила бы привязать свой телефон к чужой учётной записи.
    """
    from django_otp.plugins.otp_static.models import StaticDevice, StaticToken
    from django_otp.plugins.otp_totp.models import TOTPDevice

    user = request.user
    # Запасные коды показываем ДО проверки «уже подключён»: сразу после привязки
    # устройство уже подтверждено, и иначе человек ушёл бы со страницы,
    # не увидев коды — а второй раз они не покажутся.
    codes = request.session.pop("staff_backup_codes", None)
    if codes:
        return render(request, "admin/staff/otp_setup.html", {"backup_codes": codes})
    if TOTPDevice.objects.filter(user=user, confirmed=True).exists():
        return render(request, "admin/staff/otp_setup.html", {"already": True})

    device = TOTPDevice.objects.filter(user=user, confirmed=False).first()
    if device is None:
        TOTPDevice.objects.filter(user=user).delete()
        device = TOTPDevice.objects.create(user=user, name="МАТА админка", confirmed=False)

    error = None
    if request.method == "POST":
        code = re.sub(r"\D", "", request.POST.get("code") or "")[:6]
        if device.verify_token(code):
            device.confirmed = True
            device.save(update_fields=["confirmed"])
            StaticDevice.objects.filter(user=user).delete()
            static = StaticDevice.objects.create(user=user, name="Запасные коды", confirmed=True)
            codes = [StaticToken.random_token() for _ in range(10)]
            for c in codes:
                StaticToken.objects.create(device=static, token=c)
            StaffAudit.write(request, "Подключён второй фактор", target=user)
            request.session["staff_backup_codes"] = codes
            return redirect("staff_otp_setup")
        error = "Код не подошёл. Проверьте время на телефоне и попробуйте ещё раз."

    return render(request, "admin/staff/otp_setup.html", {
        "config_url": device.config_url,
        "secret": device.key,
        "qr_svg": _qr_svg(device.config_url),
        "error": error,
    })


def _qr_svg(url: str) -> str:
    """QR как встроенный SVG: без картинок с диска и без внешних скриптов."""
    try:
        import qrcode
        import qrcode.image.svg
    except Exception:
        return ""
    try:
        img = qrcode.make(url, image_factory=qrcode.image.svg.SvgPathImage, box_size=10, border=2)
        import io
        buf = io.BytesIO()
        img.save(buf)
        return buf.getvalue().decode("utf-8")
    except Exception:
        return ""


@staff_member_required
def staff_no_access(request):
    """Сотрудник заведён, но вкладок ему пока не выдали.

    Показываем понятную страницу, а не сводку по экосистеме: «права ещё не
    настроили» не должно значить «видно всё».
    """
    return render(request, "admin/staff/no_access.html", {
        "name": getattr(getattr(request.user, "staff_profile", None), "full_name", "")
                or request.user.get_username(),
    })


# ─────────────────── Второй фактор: управление своим (D-69) ───────────────────

def _issue_backup_codes(user):
    """Выдать новый комплект запасных кодов, старые погасить."""
    from django_otp.plugins.otp_static.models import StaticDevice, StaticToken

    StaticDevice.objects.filter(user=user).delete()
    device = StaticDevice.objects.create(user=user, name="Запасные коды", confirmed=True)
    codes = [StaticToken.random_token() for _ in range(10)]
    for code in codes:
        StaticToken.objects.create(device=device, token=code)
    return codes


def _check_current_code(user, raw):
    """Проверить код текущего второго фактора: из приложения или запасной.

    Зачем это нужно, если страница и так открыта только после ввода кода при
    входе: сессию могли перехватить уже ПОСЛЕ входа. Смена устройства без
    повторного подтверждения означала бы, что укравший сессию перепривязывает
    второй фактор на свой телефон и запирает владельца снаружи навсегда.
    Так же поступает GitHub и все, кто относится к этому серьёзно.
    """
    from django_otp import devices_for_user

    token = re.sub(r"\s", "", raw or "")
    if not token:
        return False
    return any(d.verify_token(token) for d in devices_for_user(user, confirmed=True))


@staff_member_required
def account_security(request):
    """Свой второй фактор: посмотреть, сменить устройство, перевыпустить коды.

    Страница НАМЕРЕННО лежит вне префикса `/admin/2fa/`: тот префикс пропускает
    мимо проверки кода (иначе нельзя было бы привязать первое устройство), а
    управлять вторым фактором вправе только тот, кто этот фактор уже прошёл.
    """
    from django_otp.plugins.otp_static.models import StaticDevice
    from django_otp.plugins.otp_totp.models import TOTPDevice

    from common.admin2fa import SETUP_PATH, user_has_device

    user = request.user
    if not user_has_device(user):
        return redirect(SETUP_PATH)
    # Подстраховка на случай, если список открытых путей когда-нибудь расширят.
    if hasattr(user, "is_verified") and not user.is_verified():
        return redirect(f"/admin/2fa/?next={request.path}")

    codes = request.session.pop("staff_new_backup_codes", None)
    error = None

    if request.method == "POST" and not codes:
        action = (request.POST.get("action") or "").strip()
        if not _check_current_code(user, request.POST.get("code")):
            error = ("Код не подошёл. Введите текущий код из приложения "
                     "или один из запасных кодов.")
        elif action == "rotate_device":
            # Старое устройство убираем — дальше middleware сам отправит на привязку.
            TOTPDevice.objects.filter(user=user).delete()
            StaffAudit.write(request, "смена устройства второго фактора", target=user)
            return redirect(SETUP_PATH)
        elif action == "new_codes":
            request.session["staff_new_backup_codes"] = _issue_backup_codes(user)
            StaffAudit.write(request, "перевыпуск запасных кодов", target=user)
            return redirect("account_security")

    totp = TOTPDevice.objects.filter(user=user, confirmed=True).first()
    static = StaticDevice.objects.filter(user=user, confirmed=True).first()
    return render(request, "admin/staff/security.html", {
        **django_admin.site.each_context(request),
        "title": "Второй фактор",
        "new_codes": codes,
        "error": error,
        "device_name": totp.name if totp else "",
        "codes_left": static.token_set.count() if static else 0,
        "username": user.get_username(),
    })
