"""Профили бегунов в админке — только чтение.

Владельцу полезно видеть, сколько людей заполнили профиль (от этого зависит,
работает ли «своя лига»). Править чужой возраст и пол из админки не нужно:
это данные человека, он меняет их сам в приложении.
"""
from django.contrib import admin

from league.models import RunnerProfile


@admin.register(RunnerProfile)
class RunnerProfileAdmin(admin.ModelAdmin):
    list_display = ("user_id", "birth_year", "gender", "level", "weekly_goal_km", "updated_at")
    list_filter = ("gender", "level")
    search_fields = ("user_id",)
    ordering = ("-updated_at",)

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False
