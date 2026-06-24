from django.contrib import admin
from unfold.admin import ModelAdmin

from .models import Run


@admin.register(Run)
class RunAdmin(ModelAdmin):
    list_display = (
        "id", "user_id", "distance_m", "duration_s", "points_awarded",
        "flagged", "flag_reason", "captured_territory", "finished_at",
    )
    list_filter = ("flagged", "captured_territory")
    search_fields = ("id", "user_id", "flag_reason")
    date_hierarchy = "finished_at"

    def has_change_permission(self, request, obj=None):
        # Цифры забега не правим (целостность анти-чита S-04). Просмотр деталей
        # (read-only форма) и удаление забега модератору доступны.
        return False
