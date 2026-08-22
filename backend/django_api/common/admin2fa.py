"""Двухфакторный вход в админку: пароль, затем код из приложения (D-49).

Почему не привязка по IP. Она надёжнее, но у нас один администратор с
динамическим домашним адресом: впишешь сегодняшний — завтра не войдёшь сам,
впишешь подсеть провайдера — это уже полгорода. Код из приложения работает
откуда угодно и защищает даже если пароль утёк.

Как устроено. Страницу входа не трогаем — она остаётся прежней («Console
Login»). После верного пароля пользователь попадает на второй шаг: ввод
шестизначного кода. До подтверждения админка не открывается.

Важное решение о блокировке. Второй шаг требуется, только если у пользователя
УЖЕ подключено устройство. Иначе первый же администратор на свежем сервере
оказался бы заперт снаружи навсегда. Кто подключил — тот защищён; кто нет —
виден в отчёте `check_launch_readiness` как незащищённый.

Подключение — командой `python manage.py admin_2fa <логин>`: она покажет QR-код
и запасные коды на случай потери телефона.
"""
from django.contrib import messages
from django.http import HttpResponseRedirect
from django.shortcuts import render
from django.urls import reverse

VERIFY_PATH = "/admin/2fa/"

# Пути, доступные без подтверждения: сама страница кода и выход.
# Без выхода пользователь не смог бы даже сменить аккаунт.
_ALLOWED = ("/admin/2fa/", "/admin/logout/")


def user_has_device(user) -> bool:
    """Есть ли у пользователя подтверждённое устройство (TOTP или запасные коды)."""
    from django_otp import devices_for_user

    return any(True for _ in devices_for_user(user, confirmed=True))


class AdminOtpRequiredMiddleware:
    """Не пускает в админку до подтверждения кодом — если устройство подключено."""

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
                and user_has_device(user)
            ):
                return HttpResponseRedirect(f"{VERIFY_PATH}?next={path}")
        return self.get_response(request)


def _throttle_seconds(devices) -> int:
    """Сколько секунд осталось до конца паузы после неудачных попыток."""
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

    # Уже подтверждён или устройств нет — второй шаг не нужен.
    if user.is_verified() or not user_has_device(user):
        return HttpResponseRedirect(request.GET.get("next") or "/admin/")

    error = None
    if request.method == "POST":
        token = (request.POST.get("token") or "").strip().replace(" ", "")
        devices = list(devices_for_user(user, confirmed=True))
        device = next((d for d in devices if d.verify_token(token)), None)
        if device is not None:
            otp_login(request, device)
            messages.success(request, "Вход подтверждён.")
            return HttpResponseRedirect(request.POST.get("next") or "/admin/")
        # После неудачных попыток django-otp сам вводит паузу и отклоняет даже
        # верный код. Без отдельного текста это выглядело бы как «код неверный».
        wait = _throttle_seconds(devices)
        if wait:
            error = f"Слишком много попыток. Подождите {wait} с и введите код заново."
        else:
            # Не уточняем, что именно неверно: подсказка помогает только чужому.
            error = "Код не подошёл. Проверьте время на телефоне и попробуйте ещё раз."

    return render(
        request,
        "admin/two_factor.html",
        {
            "error": error,
            "next": request.GET.get("next") or request.POST.get("next") or "/admin/",
            "username": user.get_username(),
        },
    )
