"""
Django-настройки бэкенда экосистемы STAW (этап перехода с FastAPI).
Конфиг через переменные окружения (см. docker-compose.yml / .env.example).
БД — PostgreSQL (+ PostGIS включим для модуля территорий, D-09).
"""
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = os.environ.get("DJANGO_SECRET_KEY", "dev-secret-change-in-prod")
DEBUG = os.environ.get("DJANGO_DEBUG", "1") == "1"

# Прод: DJANGO_ALLOWED_HOSTS="api.staw.ru,staw.ru". Dev (по умолчанию) — "*".
ALLOWED_HOSTS = [
    h.strip() for h in os.environ.get("DJANGO_ALLOWED_HOSTS", "*").split(",") if h.strip()
]

INSTALLED_APPS = [
    # Unfold — современная тема админки. ДОЛЖНО идти ДО django.contrib.admin.
    "unfold",
    "unfold.contrib.filters",
    "unfold.contrib.forms",
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "rest_framework",
    "corsheaders",
    "core",
    "accounts",
    "loyalty",
    "clubs",
    "leaderboard",
    "territories",
    "catalog",
    "orders",
    "shoes",
]

MIDDLEWARE = [
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [BASE_DIR / "templates"],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": os.environ.get("POSTGRES_DB", "kvartal"),
        "USER": os.environ.get("POSTGRES_USER", "kvartal"),
        "PASSWORD": os.environ.get("POSTGRES_PASSWORD", "kvartal"),
        "HOST": os.environ.get("POSTGRES_HOST", "localhost"),
        "PORT": os.environ.get("POSTGRES_PORT", "5432"),
    }
}

# CORS. Прод: DJANGO_CORS_ORIGINS="https://staw.ru,https://www.staw.ru" — тогда
# разрешаем только их. Dev (переменная пуста) — разрешаем всё (приложения и сайт
# ходят с устройства/localhost).
_cors_origins = [
    o.strip() for o in os.environ.get("DJANGO_CORS_ORIGINS", "").split(",") if o.strip()
]
if _cors_origins:
    CORS_ALLOW_ALL_ORIGINS = False
    CORS_ALLOWED_ORIGINS = _cors_origins
    # CSRF для Django-admin за HTTPS (нужны со схемой).
    CSRF_TRUSTED_ORIGINS = _cors_origins
else:
    CORS_ALLOW_ALL_ORIGINS = True

# За HTTPS-прокси (nginx/traefik): доверяем заголовку схемы. Безопасно и в dev.
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")

REST_FRAMEWORK = {
    "DEFAULT_RENDERER_CLASSES": ["rest_framework.renderers.JSONRenderer"],
    # Аутентификация — свой JWT (common.security), session-auth/CSRF DRF не используем.
    "DEFAULT_AUTHENTICATION_CLASSES": [],
}

LANGUAGE_CODE = "ru-ru"
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True

STATIC_URL = "static/"

# Медиа: фото товаров для экосистемы (Квартал тянет мини-фото кроссовок по сети).
# В dev файлы примонтированы из sport_store/assets (см. docker-compose: web → /srv/media).
# Прод — отдаёт реальный веб-сервер/CDN.
MEDIA_URL = "/media/"
MEDIA_ROOT = os.environ.get("DJANGO_MEDIA_ROOT", "/srv/media")

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# ── Unfold (тема + структура админки) ───────────────────────────────────────
from django.urls import reverse_lazy  # noqa: E402

UNFOLD = {
    "SITE_TITLE": "STAW Admin",
    "SITE_HEADER": "STAW — администрирование",
    "SITE_SUBHEADER": "Экосистема: Квартал · Store · Сайт",
    "SHOW_HISTORY": True,
    "SHOW_VIEW_ON_SITE": False,
    "DASHBOARD_CALLBACK": "config.dashboard.dashboard_callback",
    "COLORS": {
        # Брендовый electric blue (#0A84FF) как акцент — оттенки tailwind.
        "primary": {
            "50": "239 246 255",
            "100": "219 234 254",
            "200": "191 219 254",
            "300": "147 197 253",
            "400": "96 165 250",
            "500": "10 132 255",
            "600": "37 99 235",
            "700": "29 78 216",
            "800": "30 64 175",
            "900": "30 58 138",
            "950": "23 37 84",
        },
    },
    "SIDEBAR": {
        "show_search": True,
        "show_all_applications": False,
        "navigation": [
            {
                "title": "Каталог",
                "separator": True,
                "items": [
                    {"title": "Товары", "icon": "inventory_2",
                     "link": reverse_lazy("admin:catalog_product_changelist")},
                    {"title": "Категории", "icon": "category",
                     "link": reverse_lazy("admin:catalog_category_changelist")},
                    {"title": "Баннеры", "icon": "image",
                     "link": reverse_lazy("admin:catalog_banner_changelist")},
                ],
            },
            {
                "title": "Магазин",
                "separator": True,
                "items": [
                    {"title": "Заказы", "icon": "shopping_cart",
                     "link": reverse_lazy("admin:orders_order_changelist")},
                    {"title": "Баллы", "icon": "loyalty",
                     "link": reverse_lazy("admin:loyalty_loyaltytransaction_changelist")},
                    {"title": "Кроссовки", "icon": "directions_run",
                     "link": reverse_lazy("admin:shoes_shoeasset_changelist")},
                ],
            },
            {
                "title": "Сообщество",
                "separator": True,
                "items": [
                    {"title": "Клубы", "icon": "groups",
                     "link": reverse_lazy("admin:clubs_club_changelist")},
                    {"title": "Заявки в клуб", "icon": "how_to_reg",
                     "link": reverse_lazy("admin:clubs_clubjoinrequest_changelist")},
                    {"title": "Участники клубов", "icon": "badge",
                     "link": reverse_lazy("admin:clubs_clubmember_changelist")},
                    {"title": "Пользователи", "icon": "person",
                     "link": reverse_lazy("admin:accounts_account_changelist")},
                ],
            },
        ],
    },
}
