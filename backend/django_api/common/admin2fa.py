"""Двухфакторный вход в админку: пароль, затем код из приложения (D-49, D-68).

Почему не привязка по IP. Она надёжнее, но у владельца динамический домашний
адрес: впишешь сегодняшний — завтра не войдёшь сам, впишешь подсеть провайдера
— это уже полгорода. Код из приложения работает откуда угодно и защищает даже
если пароль утёк.

Как устроено. Страницу входа не трогаем — она остаётся прежней («Console
Login»). После верного пароля пользователь попадает на второй шаг: ввод
шестизначного кода. До подтверждения админка не открывается.

**Второй фактор обязателен для ВСЕХ, у кого есть доступ в админку — включая
владельца** (директива 2026-09-04). Раньше действовало послабление: код
спрашивали только у того, кто УЖЕ привязал устройство, — то есть тот, кто его
не привязал, входил по одному паролю. Владелец как раз и оказался таким:
на проде второй фактор был у сотрудника и не был у него самого. Послабление
снято, и теперь оно не нужно: у кого устройства нет, тот идёт не в админку,
а на страницу привязки.

Запереться снаружи нельзя. Страница привязки (`/admin/2fa/setup/`) открыта без
кода — иначе новый администратор не смог бы подключиться. Потерян телефон —
запасные коды; потеряны и они — `manage.py admin_2fa <логин> --reset` с сервера.
"""
from django.contrib import messages
from django.http import HttpResponseRedirect
from django.shortcuts import render
from django.urls import reverse
from django.utils.http import url_has_allowed_host_and_scheme

VERIFY_PATH = "/admin/2fa/"
SETUP_PATH = "/admin/2fa/setup/"

# Пути, доступные без подтверждения кодом: сам второй шаг, привязка устройства
# (оба под /admin/2fa/) и выход. Без выхода нельзя было бы даже сменить аккаунт.
_ALLOWED = ("/admin/2fa/", "/admin/logout/")

# Жёсткий предел на попытки кода — сверх пер-девайсной паузы django-otp.
# Своя пауза у каждого устройства означает, что с двумя устройствами (приложение
# + запасные коды) у подбирающего два бюджета попыток. Считаем ещё и по человеку.
OTP_MAX_FAILS = 5
OTP_LOCK_SECONDS = 900


def user_has_device(user) -> bool:
    """Есть ли у пользователя подтверждённое устройство (TOTP или запасные коды)."""
    from django_otp import devices_for_user

    return any(True for _ in devices_for_user(user, confirmed=True))


def safe_next(candidate, fallback="/admin/") -> str:
    """Внутренний адрес или запасной.

    Без этой проверки `?next=` был открытым редиректом: ссылка вида
    `https://api.mata-club.ru/admin/2fa/?next=https://чужой-сайт` выглядит как
    наша, а после ввода кода уводит на чужую страницу — идеальная приманка для
    фишинга. Пускаем только относительные адреса своего же сайта.
    """
    if candidate and url_has_allowed_host_and_scheme(candidate, allowed_hosts=None):
        return candidate
    return fallback


class AdminOtpRequiredMiddleware:
    """Не пускает в админку без подтверждения кодом. Исключений нет."""

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        path = request.path
        if path.startswith("/admin") and not path.startswith(_ALLOWED):
            user = getattr(request, "user", None)
            if (
                user is not None
                and user.is_authenticated
                and user.is_staff
                # is_verified() добавляет OTPMiddleware; без него не рискуем.
                and hasattr(user, "is_verified")
                and not user.is_verified()
            ):
                if user_has_device(user):
                    return HttpResponseRedirect(f"{VERIFY_PATH}?next={path}")
                # Устройства нет — не «проходи так», а «сначала привяжи».
                return HttpResponseRedirect(SETUP_PATH)
        return self.get_response(request)


def _fail_key(user) -> str:
    return f"otp_fail:{user.pk}"


def _lock_key(user) -> str:
    return f"otp_lock:{user.pk}"


def _locked_for(user) -> int:
    """Сколько секунд осталось до конца общей блокировки второго шага.

    Храним момент разблокировки отдельным ключом, а не спрашиваем у кэша TTL:
    `ttl()` есть у django-redis, но не у штатного бэкенда Django, и на нём
    блокировка молча превратилась бы в фиксированные 15 минут.
    """
    import time

    from django.core.cache import cache

    try:
        until = cache.get(_lock_key(user))
    except Exception:
        return 0
    if not until:
        return 0
    left = int(until - time.time())
    return left if left > 0 else 0


def _note_failure(request, user):
    import time

    from django.core.cache import cache

    try:
        # add() ставит TTL только при создании: окно считается от ПЕРВОЙ ошибки,
        # иначе подбирающий продлевал бы себе окно каждой новой попыткой.
        cache.add(_fail_key(user), 0, OTP_LOCK_SECONDS)
        fails = cache.incr(_fail_key(user))
        if fails >= OTP_MAX_FAILS:
            cache.set(_lock_key(user), time.time() + OTP_LOCK_SECONDS, OTP_LOCK_SECONDS)
    except Exception:
        pass
    # Промах по второму фактору — это либо сбой времени на телефоне, либо чужой
    # с украденным паролем. Владелец должен видеть такое в журнале.
    try:
        from staff.models import StaffAudit

        StaffAudit.write(request, "неверный код второго фактора", target=user)
    except Exception:
        pass


def _clear_failures(user):
    from django.core.cache import cache

    try:
        cache.delete(_fail_key(user))
        cache.delete(_lock_key(user))
    except Exception:
        pass


def _throttle_seconds(devices) -> int:
    """Сколько секунд осталось до конца паузы django-otp после неудачных попыток."""
    from django.utils import timezone

    left = 0
    now = timezone.now()
    for d in devices:
        allowed, data = d.verify_is_allowed()
        until = (data or {}).get("locked_until") if not allowed else None
        if until:
            left = max(left, int((until - now).total_seconds()) + 1)
    return left


def verify_view(request):
    """Второй шаг входа: шестизначный код из приложения или запасной код."""
    from django_otp import devices_for_user, login as otp_login

    user = request.user
    if not user.is_authenticated or not user.is_staff:
        return HttpResponseRedirect(reverse("admin:login"))

    if user.is_verified():
        return HttpResponseRedirect(safe_next(request.GET.get("next")))
    if not user_has_device(user):
        # Устройства нет — пускать нельзя, надо привязать.
        return HttpResponseRedirect(SETUP_PATH)

    error = None
    locked = _locked_for(user)
    if request.method == "POST" and not locked:
        token = (request.POST.get("token") or "").strip().replace(" ", "")
        devices = list(devices_for_user(user, confirmed=True))
        device = next((d for d in devices if d.verify_token(token)), None)
        if device is not None:
            otp_login(request, device)
            # Новый идентификатор сессии после второго фактора: если кто-то знал
            # старый (перехват, общий компьютер), подтверждённой сессией он не
            # станет — она уже под другим ключом. cycle_key() переносит данные
            # сессии, поэтому отметка об устройстве переживает смену ключа.
            request.session.cycle_key()
            _clear_failures(user)
            messages.success(request, "Вход подтверждён.")
            return HttpResponseRedirect(safe_next(request.POST.get("next")))
        _note_failure(request, user)
        locked = _locked_for(user)
        # После неудачных попыток django-otp сам вводит паузу и отклоняет даже
        # верный код. Без отдельного текста это выглядело бы как «код неверный».
        wait = locked or _throttle_seconds(devices)
        if wait:
            error = f"Слишком много попыток. Подождите {wait} с и введите код заново."
        else:
            # Не уточняем, что именно неверно: подсказка помогает только чужому.
            error = "Код не подошёл. Проверьте время на телефоне и попробуйте ещё раз."
    elif locked:
        error = f"Слишком много попыток. Подождите {locked} с и введите код заново."

    return render(
        request,
        "admin/two_factor.html",
        {
            "error": error,
            "next": safe_next(request.GET.get("next") or request.POST.get("next")),
            "username": user.get_username(),
        },
    )
