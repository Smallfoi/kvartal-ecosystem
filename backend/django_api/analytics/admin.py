from django.contrib import admin
from unfold.admin import ModelAdmin

from .models import Event


@admin.register(Event)
class EventAdmin(ModelAdmin):
    """Лента событий аналитики — только чтение (данные пишет система, не человек)."""

    list_display = ("created_at", "name", "user_id", "source")
    list_filter = ("name", "source")
    search_fields = ("user_id", "name")
    ordering = ("-created_at",)

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False
