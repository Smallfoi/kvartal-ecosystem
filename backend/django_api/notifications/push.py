"""Пуш-уведомления вне приложения — каркас под RuStore (D-25). Активируется env.

Без PUSH_PROVIDER — no-op (лента уведомлений в приложении работает и так). С
PUSH_PROVIDER=rustore + ключами RuStore — отправляем пуш на все устройства
пользователя. Реальный вызов RuStore Push API подключается при наличии аккаунта.
"""
import os


def push_enabled() -> bool:
    return bool(os.environ.get("PUSH_PROVIDER"))


def send_push(user_id, title, body="") -> int:
    """Отправить пуш на все устройства пользователя. Без провайдера — no-op (0).
    Возвращает число устройств, которым доставлено."""
    if not push_enabled() or not user_id:
        return 0
    from .models import DeviceToken

    provider = _provider()
    sent = 0
    for dt in DeviceToken.objects.filter(user_id=user_id):
        try:
            if provider.send(dt.token, title, body):
                sent += 1
        except Exception:
            pass  # сбой пуша не должен ронять создание уведомления
    return sent


def _provider():
    if os.environ.get("PUSH_PROVIDER", "").lower() == "rustore":
        return _RuStoreProvider()
    return _NoopProvider()


class _NoopProvider:
    def send(self, token, title, body) -> bool:
        return False


class _RuStoreProvider:
    """RuStore Push (D-25). Каркас: активируется PUSH_PROVIDER=rustore + RUSTORE_PUSH_KEY.
    Реальный HTTP-вызов RuStore Push API добавить, когда у владельца будет аккаунт."""

    def send(self, token, title, body) -> bool:
        if not os.environ.get("RUSTORE_PUSH_KEY"):
            return False
        # TODO(owner-gated): вызов RuStore Push API с RUSTORE_PUSH_KEY и token.
        return False
