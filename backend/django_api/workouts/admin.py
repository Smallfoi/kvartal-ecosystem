"""Импортированные тренировки в админке — только смотреть.

Полезно, когда разбираешь жалобу «мои километры не засчитались»: сразу видно,
пришла ли тренировка, связалась ли с забегом и не помечена ли античитом.
"""
from django.contrib import admin

from workouts.models import ExternalWorkout


@admin.register(ExternalWorkout)
class ExternalWorkoutAdmin(admin.ModelAdmin):
    list_display = ("started_at", "user_id", "source", "distance_m", "duration_s",
                    "points_awarded", "run_id", "flagged")
    list_filter = ("source", "flagged", "sport")
    search_fields = ("user_id", "source_id", "run_id")

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False
