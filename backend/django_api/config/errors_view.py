"""Страница «Ошибки» ВНУТРИ нашей админки (D-32). Тянет ошибки из GlitchTip по API.
Список и КАРТОЧКА ошибки (стек-трейс, крошки, теги) открываются в нашей админке —
переключаться на отдельный сайт не нужно. Всё на русском, время — якутское."""
from django.contrib import admin
from django.contrib.admin.views.decorators import staff_member_required
from django.template.response import TemplateResponse

from common import glitchtip
from staff.access import tab_required


# Уровни-«проблемы» (ошибки) vs информационные — разделяем в разные вкладки.
_ERR_LEVELS = {"error", "fatal", "warning"}


def _is_err(issue):
    return (issue.get("level") or "error") in _ERR_LEVELS


@staff_member_required
@tab_required("errors")
def errors_console(request):
    q = (request.GET.get("q") or "").strip()
    status = request.GET.get("status") or "unresolved"
    level = request.GET.get("level") or "err"  # err | info | all
    parts = []
    if status in ("unresolved", "resolved", "ignored"):
        parts.append(f"is:{status}")
    if q:
        parts.append(q)
    all_issues, error = glitchtip.fetch_issues(query=" ".join(parts))
    n_err = sum(1 for i in all_issues if _is_err(i))
    n_info = len(all_issues) - n_err
    if level == "err":
        issues = [i for i in all_issues if _is_err(i)]
    elif level == "info":
        issues = [i for i in all_issues if not _is_err(i)]
    else:
        issues = all_issues
    for it in issues:
        it["status_ru"] = glitchtip.ru_status(it.get("status"))
        it["level_ru"] = glitchtip.ru_level(it.get("level"))
        it["is_err"] = _is_err(it)
        it["last_local"] = glitchtip.fmt_local(it.get("lastSeen"))
    ctx = {
        **admin.site.each_context(request),
        "title": "Ошибки",
        "issues": issues,
        "error": error,
        "summary": glitchtip.summarize(issues),
        "configured": glitchtip.is_configured(),
        "q": q,
        "status": status,
        "level": level,
        "n_err": n_err,
        "n_info": n_info,
    }
    return TemplateResponse(request, "admin/errors_console.html", ctx)


@staff_member_required
@tab_required("errors")
def error_detail(request, issue_id):
    """Карточка ошибки прямо в админке: стек-трейс, крошки, теги, контекст."""
    issue, err1 = glitchtip.fetch_issue(issue_id)
    event, err2 = glitchtip.fetch_latest_event(issue_id)
    parsed = glitchtip.parse_event(event)
    issue = issue or {}
    ctx = {
        **admin.site.each_context(request),
        "title": issue.get("title") or "Ошибка",
        "issue": issue,
        "parsed": parsed,
        "status_ru": glitchtip.ru_status(issue.get("status")),
        "level_ru": glitchtip.ru_level(issue.get("level")),
        "first_local": glitchtip.fmt_local(issue.get("firstSeen")),
        "last_local": glitchtip.fmt_local(issue.get("lastSeen")),
        "error": err1 or err2,
        "gt_url": glitchtip.issue_link({"id": issue_id}),
    }
    return TemplateResponse(request, "admin/error_detail.html", ctx)
