"""Клиент GlitchTip API (D-32) — чтобы «вкладка Ошибки» жила ВНУТРИ нашей админки,
а не на отдельном сайте. Тянет issues (ошибки, сгруппированные по корню) из GlitchTip
и отдаёт их нашему admin-view. Без дополнительных зависимостей (urllib).

Настройка через env (в проде — прод-.env; локально — docker-compose.override.yml):
  GLITCHTIP_API_URL   — базовый URL для запросов С БЭКА (лок.: http://host.docker.internal:8080)
  GLITCHTIP_WEB_URL   — URL для ссылок в БРАУЗЕР владельца (лок.: http://localhost:8080)
  GLITCHTIP_API_TOKEN — API-токен (Bearer)
  GLITCHTIP_ORG       — slug организации (по умолчанию 'staw')
Не настроено/недоступно → пустой список + понятное сообщение (страница не падает).
"""
import json
import os
import urllib.parse
import urllib.request


def _cfg():
    api = (os.environ.get("GLITCHTIP_API_URL") or "").rstrip("/")
    return {
        "api": api,
        "web": (os.environ.get("GLITCHTIP_WEB_URL") or api).rstrip("/"),
        "token": os.environ.get("GLITCHTIP_API_TOKEN") or "",
        "org": os.environ.get("GLITCHTIP_ORG") or "staw",
    }


def is_configured():
    c = _cfg()
    return bool(c["api"] and c["token"])


def web_url():
    return _cfg()["web"]


def org_slug():
    return _cfg()["org"]


def fetch_issues(query="", limit=100):
    """Список issues из GlitchTip. Возвращает (issues, error_or_None)."""
    c = _cfg()
    if not (c["api"] and c["token"]):
        return [], "Трекер ошибок не настроен (нет GLITCHTIP_API_URL / GLITCHTIP_API_TOKEN)."
    params = {"limit": str(limit)}
    if query:
        params["query"] = query
    url = (
        f"{c['api']}/api/0/organizations/{c['org']}/issues/?"
        + urllib.parse.urlencode(params)
    )
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {c['token']}"})
    try:
        with urllib.request.urlopen(req, timeout=8) as r:
            return json.load(r), None
    except Exception as e:  # недоступен/таймаут/401 — не роняем страницу
        return [], f"Трекер недоступен ({type(e).__name__}). GlitchTip запущен? Токен верный?"


def summarize(issues):
    """Сводка для шапки страницы."""
    return {
        "total": len(issues),
        "unresolved": sum(1 for i in issues if i.get("status") == "unresolved"),
        "errors": sum(1 for i in issues if (i.get("level") in ("error", "fatal"))),
        "events": sum(int(i.get("count") or 0) for i in issues),
    }


def issue_link(issue):
    """Ссылка на карточку ошибки в GlitchTip (для полного стек-трейса)."""
    iid = issue.get("id")
    return f"{web_url()}/{org_slug()}/issues/{iid}" if iid else web_url()
