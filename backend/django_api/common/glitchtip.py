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

from django.utils import timezone as _tz
from django.utils.dateparse import parse_datetime

# Русские подписи (весь функционал на русском — по замечанию владельца).
RU_STATUS = {"unresolved": "Не решена", "resolved": "Решена",
             "ignored": "Игнор", "muted": "Заглушена"}
RU_LEVEL = {"fatal": "Критическая", "error": "Ошибка", "warning": "Предупреждение",
            "info": "Инфо", "debug": "Отладка", "sample": "Образец"}


def ru_status(s):
    return RU_STATUS.get(s, s or "—")


def ru_level(lvl):
    return RU_LEVEL.get(lvl, lvl or "—")


def fmt_local(value):
    """ISO-время → строка по якутскому времени (settings.TIME_ZONE=Asia/Yakutsk)."""
    if not value:
        return ""
    if isinstance(value, (int, float)):  # breadcrumb-время бывает epoch-float
        try:
            from datetime import datetime, timezone as _dt
            value = datetime.fromtimestamp(value, _dt.utc).isoformat()
        except Exception:
            return ""
    dt = parse_datetime(value)
    if not dt:
        return str(value)[:16].replace("T", " ")
    try:
        return _tz.localtime(dt).strftime("%d.%m.%Y %H:%M")
    except Exception:
        return str(value)[:16].replace("T", " ")


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
    """Ссылка на карточку ошибки в GlitchTip (запасной вариант — глубокий разбор)."""
    iid = issue.get("id")
    return f"{web_url()}/{org_slug()}/issues/{iid}" if iid else web_url()


def _get(path):
    """GET к GlitchTip API. Возвращает (data, error_or_None)."""
    c = _cfg()
    if not (c["api"] and c["token"]):
        return None, "Трекер не настроен."
    req = urllib.request.Request(
        f"{c['api']}/api/0/{path}", headers={"Authorization": f"Bearer {c['token']}"}
    )
    try:
        with urllib.request.urlopen(req, timeout=8) as r:
            return json.load(r), None
    except Exception as e:
        return None, f"Трекер недоступен ({type(e).__name__})."


def fetch_issue(issue_id):
    """Детали одной ошибки (issue)."""
    return _get(f"organizations/{org_slug()}/issues/{issue_id}/")


def fetch_latest_event(issue_id):
    """Последнее событие ошибки — со стек-трейсом, крошками, тегами."""
    return _get(f"issues/{issue_id}/events/latest/")


def parse_event(event):
    """Раскладываем событие в удобный для шаблона вид: исключения+стек, крошки, теги."""
    if not event:
        return None
    out = {"exceptions": [], "breadcrumbs": [], "tags": {},
           "when": fmt_local(event.get("dateCreated"))}
    for t in event.get("tags") or []:
        if t.get("key"):
            out["tags"][t["key"]] = t.get("value")
    for entry in event.get("entries") or []:
        etype = entry.get("type")
        data = entry.get("data") or {}
        if etype == "exception":
            for v in data.get("values") or []:
                frames = []
                for f in (v.get("stacktrace") or {}).get("frames") or []:
                    frames.append({
                        "file": f.get("filename") or f.get("module") or "",
                        "func": f.get("function") or "",
                        "line": f.get("lineNo"),
                        "code": (f.get("context_line") or "").strip(),
                        "in_app": bool(f.get("inApp")),
                    })
                frames.reverse()  # виновная строка — сверху
                out["exceptions"].append(
                    {"type": v.get("type"), "value": v.get("value"), "frames": frames}
                )
        elif etype == "breadcrumbs":
            for b in data.get("values") or []:
                out["breadcrumbs"].append({
                    "time": fmt_local(b.get("timestamp")),
                    "category": b.get("category") or "",
                    "message": b.get("message") or "",
                    "level": b.get("level") or "",
                })
    out["breadcrumbs"] = out["breadcrumbs"][-15:]  # последние 15
    return out
