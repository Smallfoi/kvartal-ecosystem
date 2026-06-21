from django.db import models


class Account(models.Model):
    """Пользователь экосистемы — те же поля, что в FastAPI users (контракт сохраняем)."""
    id = models.CharField(primary_key=True, max_length=40)
    name = models.CharField(max_length=200, blank=True, default="")
    email = models.CharField(max_length=200, unique=True)
    phone = models.CharField(max_length=40, null=True, blank=True)
    provider = models.CharField(max_length=20, default="email")
    avatar_path = models.CharField(max_length=500, null=True, blank=True)
    city = models.CharField(max_length=120, null=True, blank=True)
    password_hash = models.CharField(max_length=200, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    # Приватность (privacy by design, LAUNCH_READINESS §2): по умолчанию закрыто.
    profile_public = models.BooleanField(default=False)   # профиль виден другим
    route_public = models.BooleanField(default=False)     # маршруты/территории видны другим
    realtime_public = models.BooleanField(default=False)  # положение в реальном времени

    class Meta:
        db_table = "accounts"

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
