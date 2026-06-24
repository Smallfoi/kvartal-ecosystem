from django.db import models


class Account(models.Model):
    """Пользователь экосистемы — те же поля, что в FastAPI users (контракт сохраняем)."""
    id = models.CharField(primary_key=True, max_length=40, verbose_name="ID")
    name = models.CharField(max_length=200, blank=True, default="", verbose_name="Имя")
    email = models.CharField(max_length=200, unique=True, verbose_name="Email")
    phone = models.CharField(max_length=40, null=True, blank=True, verbose_name="Телефон")
    provider = models.CharField(max_length=20, default="email", verbose_name="Способ входа")
    avatar_path = models.CharField(max_length=500, null=True, blank=True, verbose_name="Аватар")
    city = models.CharField(max_length=120, null=True, blank=True, verbose_name="Город")
    password_hash = models.CharField(max_length=200, null=True, blank=True, verbose_name="Хэш пароля")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Дата регистрации")

    # Приватность (privacy by design, LAUNCH_READINESS §2): по умолчанию закрыто.
    profile_public = models.BooleanField(default=False, verbose_name="Профиль публичный")
    route_public = models.BooleanField(default=False, verbose_name="Маршруты публичны")
    realtime_public = models.BooleanField(default=False, verbose_name="Геопозиция в реальном времени")

    # Модерация (S-10): бан абьюзеров. Блокирует вход (новые токены).
    is_blocked = models.BooleanField(default=False, db_index=True, verbose_name="Заблокирован")
    block_reason = models.CharField(max_length=300, blank=True, default="", verbose_name="Причина блокировки")

    # Анти-чит (S-04): авто-отметка «на ревью» при накоплении флагнутых забегов —
    # модератору сигнал присмотреться (бан не автоматический, решает человек).
    needs_review = models.BooleanField(default=False, db_index=True, verbose_name="На проверке")

    class Meta:
        db_table = "accounts"
        verbose_name = "Пользователь"
        verbose_name_plural = "Пользователи"

    def __str__(self) -> str:
        return self.name or self.phone or self.email or self.id

    def privacy_json(self) -> dict:
        return {
            "profilePublic": self.profile_public,
            "routePublic": self.route_public,
            "realtimePublic": self.realtime_public,
        }

    def to_json(self) -> dict:
        return {
            "id": self.id,
            "name": self.name,
            "email": self.email,
            "phone": self.phone,
            "city": self.city,
            "provider": self.provider or "email",
            "avatarPath": self.avatar_path,
            "addresses": [],
            "privacy": self.privacy_json(),
        }
