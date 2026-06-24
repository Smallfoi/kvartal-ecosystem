from django.contrib import admin
from unfold.admin import ModelAdmin

from .models import Club, ClubJoinRequest, ClubMember


@admin.register(Club)
class ClubAdmin(ModelAdmin):
    list_display = ("id", "name", "city", "owner_id", "join_policy",
                    "is_hidden", "created_at")
    list_display_links = ("id", "name")  # название кликабельно → открыть/редактировать
    list_filter = ("join_policy", "city", "is_hidden")
    search_fields = ("id", "name", "city", "owner_id")
    actions = ("hide_clubs", "show_clubs")

    @admin.action(description="Скрыть (модерация)")
    def hide_clubs(self, request, queryset):
        n = queryset.update(is_hidden=True)
        self.message_user(request, f"Скрыто клубов: {n}")

    @admin.action(description="Показать")
    def show_clubs(self, request, queryset):
        n = queryset.update(is_hidden=False)
        self.message_user(request, f"Показано клубов: {n}")


@admin.register(ClubMember)
class ClubMemberAdmin(ModelAdmin):
    list_display = ("club_id", "user_id", "role", "joined_at")
    list_filter = ("role",)
    search_fields = ("club_id", "user_id")


@admin.register(ClubJoinRequest)
class ClubJoinRequestAdmin(ModelAdmin):
    list_display = ("id", "club_id", "user_id", "status", "created_at")
    list_filter = ("status",)
    search_fields = ("club_id", "user_id")
