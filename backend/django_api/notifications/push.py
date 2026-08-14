"""Пуш-уведомления вне приложения — RuStore Push / VK PNS (D-25).

Без `PUSH_PROVIDER` — no-op (лента уведомлений внутри приложения работает и так).
С `PUSH_PROVIDER=rustore` + `RUSTORE_PROJECT_ID`/`RUSTORE_PUSH_KEY` шлём пуш на все
устройства пользователя.

API: `POST https://vkpns.rustore.ru/v1/projects/{project_id}/messages:send`,
заголовок `Authorization: Bearer <сервисный токен>`, тело `{"message": {...}}`.
Успех — 200 с пустым объектом; ошибка — `{"error": {"code", "message", "status"}}`.

**Протухшие токены удаляем.** Приложение снесли или переустановили → RuStore отвечает
`NOT_FOUND`. Такой токен мёртв навсегда: если его не удалить, он будет копиться в базе
и на каждое уведомление тратить впустую HTTP-запрос.

Сбой пуша НЕ должен ронять создание уведомления — лента важнее доставки на телефон.
"""
import json
import os
import urllib.error
import urllib.request

_API = "https://vkpns.rustore.ru/v1"
_TIMEOUT = 10  # сек: пуш не стоит того, чтобы держать воркер дольше


class PushError(Exception):
    """Провайдер недоступен или отказал."""


class DeadToken(PushError):
    """Токен устройства больше не существует — подлежит удалению."""


def push_enabled() -> bool:
    return bool(os.environ.get("PUSH_PROVIDER"))


def _creds():
    """(project_id, service_token) или None, если ключи не заданы."""
    project = (os.environ.get("RUSTORE_PROJECT_ID") or "").strip()
    token = (os.environ.get("RUSTORE_PUSH_KEY") or "").strip()
    return (project, token) if project and token else None


def _http(url, payload, headers):
    """Единственная точка сетевого ввода-вывода — её и подменяют тесты."""
    req = urllib.request.Request(
        url, data=json.dumps(payload).encode("utf-8"), method="POST"
    )
    for k, v in headers.items():
        req.add_header(k, v)
    try:
        with urllib.request.urlopen(req, timeout=_TIMEOUT) as resp:
            return json.loads(resp.read().decode("utf-8") or "{}")
    except urllib.error.HTTPError as e:
        try:
            err = json.loads(e.read().decode("utf-8") or "{}").get("error") or {}
        except Exception:
            err = {}
        status = err.get("status") or ""
        message = err.get("message") or e.reason
        if e.code == 404 or status == "NOT_FOUND":
            raise DeadToken(f"Токен устройства не найден: {message}") from e
        raise PushError(f"RuStore {e.code} {status}: {message}") from e
    except Exception as e:
        raise PushError(f"RuStore недоступен: {e}") from e


def send_push(user_id, title, body="") -> int:
    """Отправить пуш на все устройства пользователя. Без провайдера — no-op (0).
    Возвращает число устройств, которым доставлено."""
    if not push_enabled() or not user_id:
        return 0
    from .models import DeviceToken as DeviceTokenModel

    provider = _provider()
    sent = 0
    for dt in list(DeviceTokenModel.objects.filter(user_id=user_id)):
        try:
            if provider.send(dt.token, title, body):
                sent += 1
        except DeadToken:
            dt.delete()  # устройство отвалилось — чистим, чтобы не копилось
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
    """RuStore Push (D-25). Активен при PUSH_PROVIDER=rustore + ключах проекта."""

    def send(self, token, title, body) -> bool:
        creds = _creds()
        if not creds:
            return False  # ключей нет — молча ничего не шлём (как и без провайдера)
        project, service_token = creds
        payload = {
            "message": {
                "token": token,
                # Без title RuStore SDK не покажет уведомление — поле обязательное.
                "notification": {"title": title, "body": body or ""},
            }
        }
        _http(
            f"{_API}/projects/{project}/messages:send",
            payload,
            {
                "Content-Type": "application/json",
                "Authorization": f"Bearer {service_token}",
            },
        )
        return True
