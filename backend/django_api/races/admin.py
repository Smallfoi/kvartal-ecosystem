from django.contrib import admin
from unfold.admin import ModelAdmin

from .models import Race


@admin.register(Race)
class RaceAdmin(ModelAdmin):
    list_display = (
        "title",
        "date",
        "city",
        "region",
        "scope",
        "type",
        "reg_status",
        "is_published",
        "source",
    )
    list_filter = ("scope", "type", "reg_status", "is_published", "source", "region")
    list_editable = ("is_published",)
    search_fields = ("title", "city", "region", "place")
    date_hierarchy = "date"
    ordering = ("date",)
    fieldsets = (
        ("Основное", {"fields": ("title", "date", "date_end", "city", "region", "place", "scope", "type")}),
        ("Дистанции и регистрация", {"fields": ("distances", "reg_status", "reg_url", "points")}),
        ("Медиа и гео", {"fields": ("cover", "lat", "lng", "description")}),
        ("Публикация / источник", {"fields": ("is_published", "source", "source_url", "external_id")}),
    )
