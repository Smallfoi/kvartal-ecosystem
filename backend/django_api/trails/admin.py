"""Тропы в админке: смотреть можно, править — только владельцу тропы в приложении."""
from django.contrib import admin

from trails.models import PendingTrack, Trail, TrailAttempt


@admin.register(Trail)
class TrailAdmin(admin.ModelAdmin):
    list_display = ("name", "city", "length_m", "created_by", "is_public", "created_at")
    list_filter = ("is_public", "city")
    search_fields = ("name", "city", "created_by")


@admin.register(TrailAttempt)
class TrailAttemptAdmin(admin.ModelAdmin):
    list_display = ("trail_id", "user_id", "duration_s", "started_at")
    search_fields = ("trail_id", "user_id", "run_id")

    def has_add_permission(self, request):
        return False


@admin.register(PendingTrack)
class PendingTrackAdmin(admin.ModelAdmin):
    """Здесь видно, сколько треков ждёт удаления. Содержимое не показываем —
    это маршруты людей, а не материал для просмотра."""
    list_display = ("run_id", "user_id", "received_at")
    search_fields = ("run_id", "user_id")

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False
