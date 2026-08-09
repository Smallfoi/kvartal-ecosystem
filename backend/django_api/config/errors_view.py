"""Страница «Ошибки» ВНУТРИ нашей админки (D-32). Тянет ошибки из GlitchTip по API и
показывает их в admin-шаблоне — владельцу не нужно переключаться на отдельный сайт.
Полный стек-трейс открывается по ссылке в GlitchTip; сводка и список — здесь."""
from django.contrib import admin
from django.contrib.admin.views.decorators import staff_member_required
from django.template.response import TemplateResponse

from common import glitchtip


@staff_member_required
def errors_console(request):
    q = (request.GET.get("q") or "").strip()
    status = request.GET.get("status") or "unresolved"
    parts = []
    if status in ("unresolved", "resolved", "ignored"):
        parts.append(f"is:{status}")
    if q:
        parts.append(q)
    issues, error = glitchtip.fetch_issues(query=" ".join(parts))
    for it in issues:
        it["gtlink"] = glitchtip.issue_link(it)
    ctx = {
        **admin.site.each_context(request),
        "title": "Ошибки",
        "issues": issues,
        "error": error,
        "summary": glitchtip.summarize(issues),
        "configured": glitchtip.is_configured(),
        "web_url": glitchtip.web_url(),
        "q": q,
        "status": status,
    }
    return TemplateResponse(request, "admin/errors_console.html", ctx)
