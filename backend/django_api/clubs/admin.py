from django.contrib import admin
from django.utils.html import format_html_join
from unfold.admin import ModelAdmin

from common.adminutils import UserRefMixin

from .models import Club, ClubJoinRequest, ClubMember


def _user_label(uid):
    from accounts.models import Account
    a = Account.objects.filter(id=uid).only("name", "phone").first()
    return (a.name or a.phone or uid) if a else uid


@admin.register(Club)
class ClubAdmin(UserRefMixin, ModelAdmin):
    user_id_field = "owner_id"  # колонка «Пользователь» берёт владельца клуба
    list_display = ("id", "name", "city", "user_ref", "join_policy",
                    "is_hidden", "created_at")
    list_display_links = ("id", "name")  # название кликабельно → открыть/редактировать
    list_filter = ("join_policy", "city", "is_hidden")
    search_fields = ("id", "name", "city", "owner_id")
    actions = ("hide_clubs", "show_clubs")
    # club_id — обычный CharField (не FK), поэтому стандартные инлайны недоступны;
    # показываем участников и заявки read-only блоками прямо в карточке клуба.
    readonly_fields = ("members_block", "requests_block")

    @admin.display(description="Участники клуба")
    def members_block(self, obj):
        if not obj or not obj.pk:
            return "—"
        rows = [
            (_user_label(m.user_id), dict(ClubMember.ROLE_CHOICES).get(m.role, m.role))
            for m in ClubMember.objects.filter(club_id=obj.id)
        ]
        if not rows:
            return "Нет участников"
        return format_html_join("", "<div>• {} — {}</div>", rows)

    @admin.display(description="Заявки на вступление")
    def requests_block(self, obj):
        if not obj or not obj.pk:
            return "—"
        rows = [
            (_user_label(r.user_id),
             dict(ClubJoinRequest.STATUS_CHOICES).get(r.status, r.status))
            for r in ClubJoinRequest.objects.filter(club_id=obj.id).order_by("-created_at")
        ]
        if not rows:
            return "Нет заявок"
        return format_html_join("", "<div>• {} — {}</div>", rows)

    @admin.action(description="Скрыть (модерация)")
    def hide_clubs(self, request, queryset):
        n = queryset.update(is_hidden=True)
        self.message_user(request, f"Скрыто клубов: {n}")

    @admin.action(description="Показать")
    def show_clubs(self, request, queryset):
        n = queryset.update(is_hidden=False)
        self.message_user(request, f"Показано клубов: {n}")


@admin.register(ClubMember)
class ClubMemberAdmin(UserRefMixin, ModelAdmin):
    list_display = ("club_id", "user_ref", "role", "joined_at")
    list_filter = ("role",)
    search_fields = ("club_id", "user_id")


@admin.register(ClubJoinRequest)
class ClubJoinRequestAdmin(UserRefMixin, ModelAdmin):
    list_display = ("id", "club_id", "user_ref", "status", "created_at")
    list_filter = ("status",)
    search_fields = ("club_id", "user_id")
