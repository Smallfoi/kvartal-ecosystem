from django.contrib import admin
from unfold.admin import ModelAdmin

from common.adminutils import UserRefMixin

from .models import Run
from .views import approve_run


@admin.action(description="Одобрить забег (снять флаг + начислить очки)")
def approve_runs(modeladmin, request, queryset):
    approved = awarded = 0
    for run in list(queryset.filter(flagged=True)):
        pts = approve_run(run)
        approved += 1
        if pts > 0:
            awarded += 1
    modeladmin.message_user(
        request, f"Одобрено забегов: {approved} (с начислением очков: {awarded})"
    )


@admin.action(description="Подтвердить нарушение (оставить без очков)")
def reject_runs(modeladmin, request, queryset):
    n = 0
    for run in list(queryset.filter(flagged=True)):
        if "[проверено]" not in run.flag_reason:
            run.flag_reason = (run.flag_reason + " [проверено]").strip()[:200]
            run.save(update_fields=["flag_reason"])
        n += 1
    modeladmin.message_user(request, f"Подтверждено нарушений: {n}")


@admin.register(Run)
class RunAdmin(UserRefMixin, ModelAdmin):
    list_display = (
        "id", "user_ref", "distance_m", "duration_s", "points_awarded",
        "flagged", "flag_reason", "captured_territory", "finished_at",
    )
    list_filter = ("flagged", "captured_territory")
    search_fields = ("id", "user_id", "flag_reason")
    date_hierarchy = "finished_at"
    actions = [approve_runs, reject_runs]

    def get_readonly_fields(self, request, obj=None):
        # Цифры забега не правим вручную (целостность анти-чита S-04): форма
        # read-only. Модерация флага — только через действия approve/reject.
        return [f.name for f in self.model._meta.fields]

    def has_add_permission(self, request):
        return False  # забеги создаёт только приложение
