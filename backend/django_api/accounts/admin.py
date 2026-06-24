from django.contrib import admin
from django.contrib.auth.admin import GroupAdmin as DjangoGroupAdmin
from django.contrib.auth.admin import UserAdmin as DjangoUserAdmin
from django.contrib.auth.models import Group, User
from unfold.admin import ModelAdmin

from .models import Account


@admin.register(Account)
class AccountAdmin(ModelAdmin):
    list_display = ("id", "name", "phone", "email", "city", "provider",
                    "is_blocked", "needs_review", "created_at")
    list_display_links = ("id", "name")  # имя кликабельно → открыть/редактировать
    list_filter = ("provider", "city", "is_blocked", "needs_review")
    search_fields = ("id", "name", "phone", "email")
    readonly_fields = ("id", "created_at", "password_hash")
    actions = ("block_accounts", "unblock_accounts", "clear_review")

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
