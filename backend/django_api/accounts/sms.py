"""Вход по одноразовому коду — провайдер подключается переменными окружения (D-24, D-50).

Без `SMS_PROVIDER` — dev-режим: код входа всегда «1234», ничего никуда не уходит.
С провайдером генерируем код, отправляем и сверяем сами. Код лежит в кэше Django
(в проде — общий Redis, D-07; LocMem на нескольких воркерах не годится).

**Длина кода — 4 цифры.** Не «на всякий случай»: поля ввода в приложениях и на
сайте рассчитаны ровно на 4 символа, а flashcall физически не может дать больше —
кодом там служат последние 4 цифры звонящего номера. Пока код был шестизначным,
пользователь просто не смог бы его ввести.

Провайдеры:

- **SIGMA messaging** (`SMS_PROVIDER=sigma`, D-50) — основной. Канал по умолчанию
  `flashcall`: клиенту звонят, он вводит последние 4 цифры номера. Дешевле SMS и
  не требует зарегистрированного имени отправителя. Канал `sms` — резерв, ему имя
  отправителя нужно.
- **smsc.ru** (`SMS_PROVIDER=smsc`) — прежний вариант, оставлен запасным.
"""
import json
import os
import secrets
import urllib.request

from django.core.cache import cache

_DEV_CODE = "1234"
_OTP_TTL = 300        # срок жизни кода — 5 минут
_MAX_ATTEMPTS = 5     # сверок на один код
_TIMEOUT = 10         # сек на запрос к провайдеру

_SIGMA_API = "https://online.sigmasms.ru/api/sendings"


def sms_enabled() -> bool:
    """Включён ли реальный провайдер (иначе dev-режим с кодом 1234)."""
    return bool(os.environ.get("SMS_PROVIDER"))


def code_length() -> int:
    """Сколько цифр в коде. Меньше 4 небезопасно, больше — не введут в поле."""
    try:
        return max(4, min(6, int(os.environ.get("OTP_CODE_LENGTH") or 4)))
    except ValueError:
        return 4


class _DevSmsProvider:
    def send(self, phone, code) -> bool:
        print(f"[OTP dev] {phone}: {code}")  # реально не отправляем
        return True


class _SmscProvider:
    """smsc.ru — активен при SMS_PROVIDER=smsc + SMS_LOGIN/SMS_PASSWORD."""

    def send(self, phone, code) -> bool:
        import urllib.parse

        login = os.environ.get("SMS_LOGIN", "")
        password = os.environ.get("SMS_PASSWORD", "")
        if not login or not password:
            return False
        params = urllib.parse.urlencode({
            "login": login, "psw": password, "phones": phone,
            "mes": f"Код входа в МАТА: {code}", "fmt": 3, "charset": "utf-8",
        })
        try:
            url = f"https://smsc.ru/sys/send.php?{params}"
            with urllib.request.urlopen(url, timeout=_TIMEOUT) as resp:
                return resp.status == 200
        except Exception:
            return False


class _SigmaProvider:
    """SIGMA messaging: flashcall (основной) и SMS (резерв).

    Про flashcall важно понимать одно: код придумываем МЫ и передаём его в
    `payload.text` — провайдер лишь звонит с номера, оканчивающегося на эти цифры.
    Значит проверка кода остаётся на нашей стороне, ровно как с SMS, и смена
    канала ничего не меняет в логике входа.

    `SIGMA_FALLBACK` — канал на случай, когда основной не отправился (например,
    оператор не пропускает звонок). Пусто — не пробовать: честная ошибка лучше,
    чем неожиданный расход на второй канал.
    """

    def send(self, phone, code) -> bool:
        channel = (os.environ.get("SIGMA_CHANNEL") or "flashcall").strip().lower()
        if self._send_via(channel, phone, code):
            return True
        fallback = (os.environ.get("SIGMA_FALLBACK") or "").strip().lower()
        if fallback and fallback != channel:
            return self._send_via(fallback, phone, code)
        return False

    def _send_via(self, channel, phone, code) -> bool:
        token = (os.environ.get("SIGMA_TOKEN") or "").strip()
        if not token:
            return False
        sender = (os.environ.get("SIGMA_SENDER") or "MATA").strip()
        # У flashcall текст — это и есть код (последние цифры звонящего номера),
        # у SMS — сообщение целиком.
        text = code if channel == "flashcall" else f"Код входа в МАТА: {code}"
        body = json.dumps({
            "recipient": phone,
            "type": channel,
            "payload": {"sender": sender, "text": text},
        }).encode("utf-8")
        req = urllib.request.Request(
            _SIGMA_API,
            data=body,
            headers={"Authorization": token, "Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=_TIMEOUT) as resp:
                return 200 <= resp.status < 300
        except Exception:
            return False


def _provider():
    name = (os.environ.get("SMS_PROVIDER") or "").strip().lower()
    if name == "sigma":
        return _SigmaProvider()
    if name == "smsc":
        return _SmscProvider()
    return _DevSmsProvider()


def request_code(phone) -> bool:
    """Сгенерировать и отправить одноразовый код. False — отправить не удалось.

    Код кладём в кэш ДО отправки: если провайдер ответил ошибкой, но звонок всё
    же прошёл, пользователь сможет войти. Обратный порядок оставил бы человека
    с кодом, которого сервер не знает.
    """
    length = code_length()
    code = f"{secrets.randbelow(10 ** length):0{length}d}"
    cache.set(f"otp:{phone}", {"code": code, "attempts": 0}, _OTP_TTL)
    return _provider().send(phone, code)


def check_code(phone, code) -> bool:
    """Верна ли пара телефон+код.

    Dev (без провайдера) — принимаем 1234. С провайдером — сверяем с отправленным.
    """
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
