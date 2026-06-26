"""SMS-OTP вход — каркас под провайдера (D-24). Активируется env-ключами.

Без SMS_PROVIDER — dev-режим: код входа всегда «1234» (как было), реальные SMS
не шлются. С SMS_PROVIDER=smsc — генерируем одноразовый код, шлём через smsc.ru,
сверяем с отправленным (срок 5 мин, лимит попыток). Код хранится в кэше Django
(в проде — общий Redis, D-07; LocMem на нескольких воркерах не годится).
"""
import os
import secrets

from django.core.cache import cache

_DEV_CODE = "1234"
_OTP_TTL = 300        # срок жизни кода — 5 минут
_MAX_ATTEMPTS = 5     # сверок на один код


def sms_enabled() -> bool:
    """Включён ли реальный SMS-провайдер (иначе dev-режим с кодом 1234)."""
    return bool(os.environ.get("SMS_PROVIDER"))


class _DevSmsProvider:
    def send(self, phone, text) -> bool:
        print(f"[SMS dev] {phone}: {text}")  # реально не отправляем
        return True


class _SmscProvider:
    """smsc.ru — активен при SMS_PROVIDER=smsc + SMS_LOGIN/SMS_PASSWORD."""

    def send(self, phone, text) -> bool:
        import urllib.parse
        import urllib.request

        login = os.environ.get("SMS_LOGIN", "")
        password = os.environ.get("SMS_PASSWORD", "")
        if not login or not password:
            return False
        params = urllib.parse.urlencode({
            "login": login, "psw": password, "phones": phone,
            "mes": text, "fmt": 3, "charset": "utf-8",
        })
        try:
            url = f"https://smsc.ru/sys/send.php?{params}"
            with urllib.request.urlopen(url, timeout=10) as resp:
                return resp.status == 200
        except Exception:
            return False


def _provider():
    if os.environ.get("SMS_PROVIDER", "").lower() == "smsc":
        return _SmscProvider()
    return _DevSmsProvider()


def request_code(phone) -> None:
    """Сгенерировать и отправить одноразовый код на телефон."""
    code = f"{secrets.randbelow(1_000_000):06d}"
    cache.set(f"otp:{phone}", {"code": code, "attempts": 0}, _OTP_TTL)
    _provider().send(phone, f"Код входа в STAW: {code}")


def check_code(phone, code) -> bool:
    """Верна ли введённая комбинация телефон+код.
    Dev (без провайдера) — принимаем 1234. С провайдером — сверяем с отправленным."""
    code = (code or "").strip()
    if not sms_enabled():
        return code == _DEV_CODE
    rec = cache.get(f"otp:{phone}")
    if not rec or rec["attempts"] >= _MAX_ATTEMPTS:
        return False
    rec["attempts"] += 1
    cache.set(f"otp:{phone}", rec, _OTP_TTL)
    if code and code == rec["code"]:
        cache.delete(f"otp:{phone}")  # одноразовый
        return True
    return False
