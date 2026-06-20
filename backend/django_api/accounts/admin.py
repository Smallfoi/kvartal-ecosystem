from django.contrib import admin

from .models import Account


@admin.register(Account)
class AccountAdmin(admin.ModelAdmin):
    list_display = ("id", "name", "phone", "email", "city", "provider", "created_at")
    list_filter = ("provider", "city")
    search_fields = ("id", "name", "phone", "email")
    readonly_fields = ("id", "created_at", "password_hash")
