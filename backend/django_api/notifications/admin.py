from django.contrib import admin
from unfold.admin import ModelAdmin

from common.adminutils import UserRefMixin

from .models import DeviceToken, Notification


@admin.register(Notification)
class NotificationAdmin(UserRefMixin, ModelAdmin):
    list_display = ("id", "user_ref", "title", "type", "read", "order_id", "created_at")
    list_filter = ("type", "read")
    search_fields = ("user_id", "title", "body", "order_id")
    date_hierarchy = "created_at"


@admin.register(DeviceToken)
class DeviceTokenAdmin(UserRefMixin, ModelAdmin):
    list_display = ("id", "user_ref", "platform", "created_at")
    list_filter = ("platform",)
    search_fields = ("user_id", "token")
    date_hierarchy = "created_at"
