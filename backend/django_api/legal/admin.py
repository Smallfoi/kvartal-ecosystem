from django.contrib import admin
from django.utils import timezone
from unfold.admin import ModelAdmin

from common.adminutils import UserRefMixin

from .models import LegalDocument, UserConsent


@admin.register(LegalDocument)
class LegalDocumentAdmin(ModelAdmin):
    list_display = (
        "doc_type", "version", "title", "is_required", "published_at", "created_at",
    )
    list_display_links = ("doc_type", "title")  # тип/заголовок кликабельны
    list_filter = ("doc_type", "is_required")
    search_fields = ("title", "body", "version")
    date_hierarchy = "created_at"
    actions = ["publish", "unpublish"]

    @admin.action(description="Опубликовать выбранные")
    def publish(self, request, queryset):
        queryset.filter(published_at__isnull=True).update(published_at=timezone.now())

    @admin.action(description="Снять с публикации (в черновик)")
    def unpublish(self, request, queryset):
        queryset.update(published_at=None)


@admin.register(UserConsent)
class UserConsentAdmin(UserRefMixin, ModelAdmin):
    list_display = ("id", "user_ref", "document", "source", "accepted_at", "revoked_at")
    list_filter = ("source", "document__doc_type")
    search_fields = ("user_id",)
    date_hierarchy = "accepted_at"
    # Аудит согласий (152-ФЗ) не правим вручную — иначе теряет доказательную силу.
    # Просмотр деталей (read-only) и удаление записи — доступны.
    def has_change_permission(self, request, obj=None):
        return False
