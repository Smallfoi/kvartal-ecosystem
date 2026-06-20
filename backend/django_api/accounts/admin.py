from django.contrib import admin
from django.contrib.auth.admin import GroupAdmin as DjangoGroupAdmin
from django.contrib.auth.admin import UserAdmin as DjangoUserAdmin
from django.contrib.auth.models import Group, User
from unfold.admin import ModelAdmin

from .models import Account


@admin.register(Account)
class AccountAdmin(ModelAdmin):
    list_display = ("id", "name", "phone", "email", "city", "provider", "created_at")
    list_filter = ("provider", "city")
    search_fields = ("id", "name", "phone", "email")
    readonly_fields = ("id", "created_at", "password_hash")


# Перерегистрируем стандартные User/Group под тему Unfold (иначе рендерятся дефолтно).
admin.site.unregister(User)
admin.site.unregister(Group)


@admin.register(User)
class UserAdmin(DjangoUserAdmin, ModelAdmin):
    pass


@admin.register(Group)
class GroupAdmin(DjangoGroupAdmin, ModelAdmin):
    pass
