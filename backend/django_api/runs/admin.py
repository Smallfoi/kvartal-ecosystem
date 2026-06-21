from django.contrib import admin
from unfold.admin import ModelAdmin

from .models import Run


@admin.register(Run)
class RunAdmin(ModelAdmin):
    list_display = (
        "id", "user_id", "distance_m", "duration_s",
        "captured_territory", "captured_zones", "finished_at",
    )
    list_filter = ("captured_territory",)
    search_fields = ("id", "user_id")
    date_hierarchy = "finished_at"

    def has_change_permission(self, request, obj=None):
        return False  # история — только просмотр
