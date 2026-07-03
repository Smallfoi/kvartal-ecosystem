"""Утилиты для админки: читаемая колонка пользователя вместо сырого user_id.

user_id в моделях — обычный CharField (не ForeignKey, контракт с FastAPI), поэтому
Django не покажет имя автоматически. Миксин подтягивает Account и выводит
«Имя · телефон». Запрос на строку — для админ-списка (≤100 строк) это норма."""
import csv

from django.contrib import admin
from django.http import HttpResponse


class ExportCsvMixin:
    """Действие «Экспорт в CSV» для выбранных строк. Поля — из `export_fields`
    (если не задано — все поля модели). Файл с BOM, чтобы кириллица открывалась
    в Excel корректно."""
    export_fields = None
    csv_filename = "export"

    @admin.action(description="Экспорт выбранных в CSV")
    def export_as_csv(self, request, queryset):
        fields = self.export_fields or [f.name for f in self.model._meta.fields]
        resp = HttpResponse(content_type="text/csv; charset=utf-8")
        resp["Content-Disposition"] = f'attachment; filename="{self.csv_filename}.csv"'
        resp.write(chr(0xFEFF))  # BOM, чтобы кириллица открывалась в Excel
        writer = csv.writer(resp)
        writer.writerow(fields)
        for obj in queryset:
            writer.writerow([getattr(obj, f, "") for f in fields])
        return resp


class UserRefMixin:
    """Добавляет метод user_ref (колонка «Пользователь»). Поле с id берётся из
    user_id_field (по умолчанию 'user_id'; для клуба — 'owner_id')."""
    user_id_field = "user_id"

    @admin.display(description="Пользователь")
    def user_ref(self, obj):
        from accounts.models import Account

        uid = getattr(obj, self.user_id_field, "") or ""
        if not uid:
            return "—"
        acc = Account.objects.filter(id=uid).only("name", "phone", "email").first()
        if not acc:
            return f"{uid} (удалён)"
        name = acc.name or acc.phone or acc.email or uid
        extra = acc.phone or acc.email or ""
        return f"{name} · {extra}" if extra and extra != name else name
