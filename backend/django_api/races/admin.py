from django.contrib import admin
from django.shortcuts import redirect
from django.urls import path
from unfold.admin import ModelAdmin
from unfold.decorators import action

from .models import Race
from .services import run_import


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
    # Кнопка на странице списка (unfold): запустить авто-импорт из источников.
    actions_list = ["run_import_action"]

    def get_urls(self):
        return [
            path("import-now/", self.admin_site.admin_view(self.import_now),
                 name="races_race_import_now"),
        ] + super().get_urls()

    @action(description="Импортировать забеги из источников")
    def run_import_action(self, request):
        return redirect("admin:races_race_import_now")

    def import_now(self, request):
        stats = run_import()
        self.message_user(
            request,
            f"Импорт завершён: создано {stats['created']}, обновлено {stats['updated']}, "
            f"пропущено {stats['skipped']}, ошибок {stats['errors']}.",
        )
        return redirect("admin:races_race_changelist")
