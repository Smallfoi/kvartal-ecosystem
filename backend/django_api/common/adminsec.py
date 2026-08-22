"""Анти-брутфорс для входа в админку (D-39).

Лимиты DRF (`common/throttling.py`) защищают только API: они живут в DRF-вью. Django-админка
— обычные вью Django, и её форма входа `/admin/login/` не была прикрыта ничем. При этом за
админкой стоят деньги (возвраты), персональные данные и публикация контента, а имя
пользователя у первого админа предсказуемое. Перебор пароля был возможен без ограничений.

Считаем НЕУДАЧНЫЕ попытки по IP (сигнал `user_login_failed`), удачный вход счётчик обнуляет.
Превышение — 429 до конца окна. Счётчик в кэше: в проде это общий Redis, поэтому лимит
работает на всех воркерах gunicorn сразу (как и остальные лимиты, D-07).

IP берём из `X-Real-IP` — его проставляет наш nginx (см. `nginx/mata.conf.example`).
`REMOTE_ADDR` за прокси равен адресу самого прокси: по нему блокировка одного пользователя
заблокировала бы всех.
"""
import ipaddress
import os

from django.contrib.auth.signals import user_logged_in, user_login_failed
from django.core.cache import cache
from django.dispatch import receiver
from django.http import Http404, HttpResponse

MAX_FAILS = 10          # попыток
WINDOW_SECONDS = 900    # 15 минут
_PREFIX = "adminlogin"

_login_path = None


def _client_ip(request) -> str:
    return (
        request.META.get("HTTP_X_REAL_IP")
        or request.META.get("REMOTE_ADDR")
        or "unknown"
    )


def _key(ip: str) -> str:
    return f"{_PREFIX}:{ip}"


def admin_login_path() -> str:
    """Путь формы входа в админку (кэшируем — reverse на каждый запрос не нужен)."""
    global _login_path
    if _login_path is None:
        try:
            from django.urls import reverse

            _login_path = reverse("admin:login")
        except Exception:
            _login_path = "/admin/login/"
    return _login_path


@receiver(user_login_failed)
def _count_failure(sender, credentials=None, request=None, **kwargs):
    if request is None:
        return
    ip = _client_ip(request)
    try:
        # add() создаёт ключ с TTL только если его ещё нет — окно отсчитывается
        # от ПЕРВОЙ неудачи, а не продлевается каждой следующей.
        cache.add(_key(ip), 0, WINDOW_SECONDS)
        cache.incr(_key(ip))
    except Exception:
        pass  # сбой кэша не должен ломать вход


@receiver(user_logged_in)
def _reset_on_success(sender, request=None, **kwargs):
    if request is None:
        return
    try:
        cache.delete(_key(_client_ip(request)))
    except Exception:
        pass


class AdminLoginRateLimitMiddleware:
    """Блокирует отправку формы входа в админку после MAX_FAILS неудач с одного IP."""

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        if request.method == "POST" and request.path == admin_login_path():
            try:
                fails = cache.get(_key(_client_ip(request))) or 0
            except Exception:
                fails = 0
            if fails >= MAX_FAILS:
                return HttpResponse(
                    "Слишком много попыток входа. Попробуйте через 15 минут.",
                    status=429,
                    content_type="text/plain; charset=utf-8",
                )
        return self.get_response(request)


# ── Белый список IP для админки (D-48) ───────────────────────────────────────
# За админкой возвраты денег, персональные данные и публикация контента. Даже с
# сильным паролем и лимитом попыток форма входа доступна всему интернету —
# а значит, её можно перебирать и на ней сработает любая будущая уязвимость
# Django-админки. Дешевле не показывать её вовсе никому, кроме владельца.
#
# Список задаётся `ADMIN_IP_ALLOWLIST` (через запятую, адреса и/или подсети):
#     ADMIN_IP_ALLOWLIST=203.0.113.7,198.51.100.0/24
# Пусто — ограничение выключено (dev). Проверять и включать в проде:
# `python manage.py check_launch_readiness`.


def _parse_allowlist(raw: str):
    """Строка из env → список сетей. Мусорные записи игнорируем, не падаем."""
    nets = []
    for chunk in (raw or "").split(","):
        chunk = chunk.strip()
        if not chunk:
            continue
        try:
            nets.append(ipaddress.ip_network(chunk, strict=False))
        except ValueError:
            continue
    return nets


def admin_ip_allowlist():
    return _parse_allowlist(os.environ.get("ADMIN_IP_ALLOWLIST", ""))


def ip_allowed(ip: str, nets) -> bool:
    """Пустой список = ограничение выключено, пускаем всех."""
    if not nets:
        return True
    try:
        addr = ipaddress.ip_address(ip)
    except ValueError:
        return False
    return any(addr in net for net in nets)


class AdminIpAllowlistMiddleware:
    """Пускает в `/admin/` только с разрешённых адресов.

    Отдаём 404, а не 403: чужому не нужно знать, что админка вообще существует
    по этому адресу. Для владельца поведение не меняется.
    """

    def __init__(self, get_response):
        self.get_response = get_response
        self._nets = admin_ip_allowlist()

    def __call__(self, request):
        if self._nets and request.path.startswith("/admin"):
            if not ip_allowed(_client_ip(request), self._nets):
                raise Http404
        return self.get_response(request)
