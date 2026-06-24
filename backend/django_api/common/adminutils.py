"""Утилиты для админки: читаемая колонка пользователя вместо сырого user_id.

user_id в моделях — обычный CharField (не ForeignKey, контракт с FastAPI), поэтому
Django не покажет имя автоматически. Миксин подтягивает Account и выводит
«Имя · телефон». Запрос на строку — для админ-списка (≤100 строк) это норма."""
from django.contrib import admin


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
