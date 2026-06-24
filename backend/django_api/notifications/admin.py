from django.contrib import admin
from unfold.admin import ModelAdmin

from common.adminutils import UserRefMixin

from .models import Notification


@admin.register(Notification)
class NotificationAdmin(UserRefMixin, ModelAdmin):
    list_display = ("id", "user_ref", "title", "type", "read", "order_id", "created_at")
    list_filter = ("type", "read")
    search_fields = ("user_id", "title", "body", "order_id")
    date_hierarchy = "created_at"
