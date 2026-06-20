from django.contrib import admin
from unfold.admin import ModelAdmin

from .models import Club, ClubJoinRequest, ClubMember


@admin.register(Club)
class ClubAdmin(ModelAdmin):
    list_display = ("id", "name", "city", "owner_id", "join_policy", "created_at")
    list_filter = ("join_policy", "city")
    search_fields = ("id", "name", "city", "owner_id")


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
