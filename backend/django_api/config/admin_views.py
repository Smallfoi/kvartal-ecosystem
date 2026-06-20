"""Кастомные страницы админки (вне ModelAdmin). Пока — live-превью сайта."""
from django.conf import settings
from django.contrib.admin.views.decorators import staff_member_required
from django.shortcuts import render


@staff_member_required
def preview_site(request):
    """Страница «Превью сайта»: iframe витрины в режиме ?preview=1 (с черновиками).
    Правишь товары/публикацию в админке → «Обновить» → видишь на сайте до прода."""
    base = getattr(settings, "SITE_PREVIEW_URL", "http://localhost:5577").rstrip("/")
    return render(request, "admin/preview_site.html", {
        "preview_url": base + "/?preview=1",
        "site_base": base,
    })


@staff_member_required
def preview_app(request):
    """Пиксель-точное превью приложения (SportStore собран под web с PREVIEW=1):
    реальные виджеты карточек/баннеров с данными из API (включая черновики)."""
    base = getattr(settings, "APP_PREVIEW_URL", "http://localhost:5578").rstrip("/")
    return render(request, "admin/preview_app.html", {
        "preview_url": base + "/",
        "app_base": base,
    })
