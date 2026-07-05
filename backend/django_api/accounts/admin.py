from django.contrib import admin, messages
from django.contrib.admin.helpers import ACTION_CHECKBOX_NAME
from django.contrib.auth.admin import GroupAdmin as DjangoGroupAdmin
from django.contrib.auth.admin import UserAdmin as DjangoUserAdmin
from django.contrib.auth.models import Group, User
from django.template.response import TemplateResponse
from unfold.admin import ModelAdmin

from common.adminutils import ExportCsvMixin

from .models import Account


@admin.register(Account)
class AccountAdmin(ExportCsvMixin, ModelAdmin):
    list_display = ("id", "name", "phone", "email", "city", "provider",
                    "is_blocked", "needs_review", "created_at")
    list_display_links = ("id", "name")  # имя кликабельно → открыть/редактировать
    list_filter = ("provider", "city", "is_blocked", "needs_review")
    search_fields = ("id", "name", "phone", "email")
    ordering = ("-created_at",)
    date_hierarchy = "created_at"
    readonly_fields = ("id", "created_at")
    actions = ("send_notification", "block_accounts", "unblock_accounts",
               "clear_review", "export_as_csv")
    csv_filename = "accounts"
    export_fields = ("id", "name", "phone", "email", "city", "provider",
                     "is_blocked", "needs_review", "created_at")
    # Карточка пользователя по разделам (хэш пароля не показываем).
    fieldsets = (
        ("Профиль", {
            "fields": ("id", "name", "phone", "email", "city", "provider",
                       "avatar_path", "addresses", "created_at"),
        }),
        ("Приватность", {
            "fields": ("profile_public", "route_public", "realtime_public"),
        }),
        ("Модерация и анти-чит", {
            "fields": ("is_blocked", "block_reason", "needs_review"),
            "description": "Блокировка отрезает вход (≤60с). «На проверке» — авто-метка "
            "при накоплении флагнутых забегов (S-04); снимается действием в списке.",
        }),
    )

    @admin.action(description="✉ Отправить уведомление выбранным")
    def send_notification(self, request, queryset):
        """Массовая рассылка: промежуточная форма (заголовок/текст) → уведомление каждому
        выбранному пользователю. Идёт в общую ленту уведомлений (+ пуш, если настроен)."""
        if "apply" in request.POST:
            title = (request.POST.get("title") or "").strip()
            body = (request.POST.get("body") or "").strip()
            if not title:
                self.message_user(request, "Заголовок обязателен — рассылка отменена.",
                                  level=messages.ERROR)
                return None
            from notifications.models import create_notification

            sent = 0
            for uid in queryset.values_list("id", flat=True):
                if create_notification(uid, title, body, type="system"):
                    sent += 1
            self.message_user(request, f"Отправлено уведомлений: {sent}",
                              level=messages.SUCCESS)
            return None
        # Первый вызов — показать форму (с сохранением выбранных получателей).
        return TemplateResponse(request, "admin/send_notification.html", {
            **self.admin_site.each_context(request),
            "title": "Массовая рассылка уведомления",
            "opts": self.model._meta,
            "count": queryset.count(),
            "selected": list(queryset.values_list("id", flat=True)),
            "action_checkbox_name": ACTION_CHECKBOX_NAME,
        })

    @admin.action(description="Заблокировать (бан входа)")
    def block_accounts(self, request, queryset):
        n = queryset.update(is_blocked=True)
        self.message_user(request, f"Заблокировано аккаунтов: {n}")

    @admin.action(description="Разблокировать")
    def unblock_accounts(self, request, queryset):
        n = queryset.update(is_blocked=False, block_reason="")
        self.message_user(request, f"Разблокировано аккаунтов: {n}")

    @admin.action(description="Снять отметку «на ревью» (S-04)")
    def clear_review(self, request, queryset):
        n = queryset.update(needs_review=False)
        self.message_user(request, f"Снята отметка ревью: {n}")


# Перерегистрируем стандартные User/Group под тему Unfold (иначе рендерятся дефолтно).
admin.site.unregister(User)
admin.site.unregister(Group)


@admin.register(User)
class UserAdmin(DjangoUserAdmin, ModelAdmin):
    pass


@admin.register(Group)
class GroupAdmin(DjangoGroupAdmin, ModelAdmin):
    pass
